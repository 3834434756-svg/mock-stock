import Foundation
import Combine

/// 币币账户引擎。
///
/// 与 `AccountStore`（人民币股票账户）完全独立：
/// - 记账单位是 USDT，不再折算成人民币
/// - 有自己的持仓、成交记录、手续费、流水
/// - 靠 `deposit` / `withdraw` 与股票账户或银行卡打通
///
/// 行情沿用 `CryptoAPI`（币安 → OKX 双源降级），这里只做 USDT 计价，
/// 不再乘汇率 —— 汇率折算只发生在入金 / 提现两个口子上。
@MainActor
final class CryptoStore: ObservableObject {
    static let shared = CryptoStore()

    @Published var account: CryptoAccount {
        didSet { save() }
    }

    /// 最新行情（USDT 价）。key 是内部代码，如 cbBTCUSDT
    @Published var prices: [String: Double] = [:]
    /// 昨收（USDT 价），用于算涨跌幅
    @Published var prevCloses: [String: Double] = [:]
    /// 行情最近一次更新时间
    @Published var lastUpdate: Date?
    @Published var isLoadingPrices = false

    // MARK: - 费率与限额

    /// 现货手续费率 0.1%（买卖双向都收）
    static let feeRate = 0.001
    /// 提现手续费率 1%
    static let withdrawFeeRate = 0.01
    /// 单笔最低提现（USDT）
    static let minWithdraw = 10.0
    /// 人民币 → USDT 折算汇率
    static var rate: Double { FX.usdtToCNY }

    private let key = "mockstock.crypto.account.v1"
    private let api = CryptoAPI.shared
    /// 浮点容差
    private let eps = 1e-9

    private init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let a = try? JSONDecoder().decode(CryptoAccount.self, from: d) {
            account = a
        } else {
            account = CryptoAccount()
        }
    }

    // MARK: - 行情

    /// 拉全部币种行情
    func refreshPrices() async {
        isLoadingPrices = true
        defer { isLoadingPrices = false }
        guard let list = try? await api.quotes(symbols: CryptoCoin.allSymbols),
              !list.isEmpty else { return }
        var p: [String: Double] = [:]
        var pc: [String: Double] = [:]
        for q in list {
            p[q.code] = q.displayPrice
            pc[q.code] = q.displayPrevClose
        }
        // 合并而非替换：偶发丢包不该让某一行价格闪成 0
        prices.merge(p) { _, new in new }
        prevCloses.merge(pc) { _, new in new }
        lastUpdate = Date()
    }

    /// 单个币种的最新 USDT 价。没有行情时退回成本价，避免界面出现 0
    func price(of code: String) -> Double {
        if let p = prices[code], p > 0 { return p }
        return account.position(for: code)?.costPrice ?? 0
    }

    /// 从外部行情同步（行情页已经在轮询，不必重复请求）
    func sync(quotes: [Quote]) {
        guard !quotes.isEmpty else { return }
        var p: [String: Double] = [:]
        var pc: [String: Double] = [:]
        for q in quotes where q.market == .crypto {
            p[q.code] = q.displayPrice
            pc[q.code] = q.displayPrevClose
        }
        prices.merge(p) { _, new in new }
        prevCloses.merge(pc) { _, new in new }
        lastUpdate = Date()
    }

    /// 全部持仓的价格表
    var positionPrices: [String: Double] {
        var d: [String: Double] = [:]
        for pos in account.positions {
            d[pos.code] = price(of: pos.code)
        }
        return d
    }

    /// 持仓总市值（USDT）
    var positionsValue: Double { account.positionsValue(prices: positionPrices) }

    /// 持仓浮盈（USDT）
    var positionsProfit: Double { account.positionsProfit(prices: positionPrices) }

    /// 账户总资产（USDT）
    var totalAssets: Double { account.totalAssets(prices: positionPrices) }

    /// 今日盈亏（USDT）：持仓按昨收价折算的浮盈
    var todayProfit: Double {
        account.positions.reduce(0) { sum, pos in
            let now = price(of: pos.code)
            let prev = prevCloses[pos.code] ?? pos.costPrice
            return sum + (now - prev) * pos.shares
        }
    }

    // MARK: - 交易

    /// 买入。`usdt` 是打算花掉的 U 币金额，手续费从这笔钱里扣
    func buy(code: String, name: String, short: String, price: Double, usdt amount: Double) -> String? {
        guard amount > eps else { return "请输入买入金额" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }
        guard amount <= account.usdt + 1e-6 else {
            return "可用余额不足，当前 \(Fmt.usdt(account.usdt))"
        }

        let fee = amount * Self.feeRate
        let net = amount - fee          // 真正换成币的部分
        let shares = net / price

        account.usdt -= amount
        account.totalFee += fee
        account.turnover += amount

        if let i = account.positions.firstIndex(where: { $0.code == code }) {
            let old = account.positions[i]
            let totalShares = old.shares + shares
            let totalCost = old.costPrice * old.shares + net
            account.positions[i].shares = totalShares
            account.positions[i].costPrice = totalShares > eps ? totalCost / totalShares : price
        } else {
            account.positions.append(
                CryptoPosition(code: code, name: name, short: short,
                               shares: shares, costPrice: net / shares)
            )
        }

        pushRecord(code: code, short: short, side: .buy, price: price, shares: shares, fee: fee)
        MissionCenter.shared.refresh()
        Juice.trade()
        return nil
    }

    /// 卖出。按份额成交，手续费从回款里扣
    func sell(code: String, price: Double, shares: Double) -> String? {
        guard shares > eps else { return "请输入卖出数量" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }
        guard let i = account.positions.firstIndex(where: { $0.code == code }) else {
            return "没有该币种的持仓"
        }

        let pos = account.positions[i]
        guard shares <= pos.shares + 1e-6 else {
            return "持仓不足，最多可卖 \(Fmt.shares(pos.shares)) \(pos.short)"
        }

        let gross = price * shares
        let fee = gross * Self.feeRate
        let net = gross - fee

        account.usdt += net
        account.totalFee += fee
        account.turnover += gross

        let remain = pos.shares - shares
        if remain <= 1e-8 {
            account.positions.remove(at: i)
        } else {
            account.positions[i].shares = remain
        }

        pushRecord(code: code, short: pos.short, side: .sell, price: price, shares: shares, fee: fee)
        MissionCenter.shared.refresh()
        Juice.trade()
        return nil
    }

    private func pushRecord(code: String, short: String, side: TradeSide,
                            price: Double, shares: Double, fee: Double) {
        let r = CryptoTradeRecord(code: code, short: short, side: side,
                                  price: price, shares: shares, fee: fee, date: Date())
        account.records.insert(r, at: 0)
        if account.records.count > 300 {
            account.records = Array(account.records.prefix(300))
        }
    }

    // MARK: - 入金 / 提现

    /// 入金：从人民币股票账户划转，按固定汇率换成 USDT
    func deposit(cny: Double) -> String? {
        guard cny > 0 else { return "请输入金额" }
        let store = AccountStore.shared

        if !store.account.mode.isUnlimited {
            guard cny <= store.account.cash + 1e-6 else {
                return "交易账户可用资金不足，当前 \(Fmt.money(store.account.cash))"
            }
            store.account.cash -= cny
        }

        let usdt = cny / Self.rate
        account.usdt += usdt
        account.totalDeposit += usdt
        MissionCenter.shared.refresh()
        return nil
    }

    /// 提现：USDT 换成人民币打到银行卡。
    /// 前置条件是实名的 + 绑了卡 + 金额在可提现额度内（奖励金要打够流水）
    func withdraw(usdt amount: Double) -> String? {
        guard account.kycDone else { return "请先完成实名认证" }
        guard let card = account.bankCard else { return "请先绑定银行卡" }
        guard amount > eps else { return "请输入提现金额" }
        guard amount >= Self.minWithdraw else {
            return "单笔最低提现 \(Fmt.u(Self.minWithdraw)) USDT"
        }
        guard amount <= account.withdrawable + 1e-6 else {
            let locked = account.lockedReward
            if locked > 0.01 {
                return "可提现余额不足。奖励金还有 \(Fmt.u(locked)) USDT 未解锁，"
                    + "需再累计 \(Fmt.u(account.turnoverToUnlock)) USDT 流水"
            }
            return "可提现余额不足，当前 \(Fmt.usdt(account.withdrawable))"
        }

        let fee = amount * Self.withdrawFeeRate
        let net = amount - fee
        let cny = net * Self.rate

        account.usdt -= amount
        account.totalWithdraw += amount
        account.withdrawals.insert(
            Withdrawal(amount: amount, fee: fee, received: cny,
                       rate: Self.rate, cardTail: card.shortMasked, date: Date()),
            at: 0
        )
        if account.withdrawals.count > 60 {
            account.withdrawals = Array(account.withdrawals.prefix(60))
        }
        Haptic.success()
        return nil
    }

    /// 预估提现到账（人民币）
    func withdrawEstimate(_ amount: Double) -> (fee: Double, cny: Double) {
        let fee = amount * Self.withdrawFeeRate
        return (fee, (amount - fee) * Self.rate)
    }

    // MARK: - 实名 / 银行卡

    func verifyKYC(name: String, idNo: String) {
        account.kycName = name
        account.kycIdNo = idNo
        account.kycDone = true
        MissionCenter.shared.refresh()
        Haptic.success()
    }

    func bindCard(_ card: BankCard) {
        account.bankCard = card
        MissionCenter.shared.refresh()
        Haptic.success()
    }

    func unbindCard() {
        account.bankCard = nil
    }

    // MARK: - 任务奖励

    /// 任务奖励入账。奖励进余额、可立即用于交易，但计入打码量
    func creditReward(_ amount: Double) {
        guard amount > 0 else { return }
        account.usdt += amount
        account.rewardTotal += amount
    }

    /// 重开一局时清空币账户
    func reset() {
        account = CryptoAccount()
        prices = [:]
        prevCloses = [:]
        lastUpdate = nil
    }

    // MARK: - 持久化

    private func save() {
        if let d = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}
