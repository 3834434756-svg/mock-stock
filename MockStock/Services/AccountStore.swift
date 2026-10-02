import Foundation

/// 账户与交易引擎（本地模拟撮合 + 持久化）
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published var account: Account {
        didSet { save() }
    }

    /// 是否还没选过模式（首次启动 → 显示模式选择页）
    @Published var needsSetup: Bool {
        didSet { save() }
    }

    private let accountKey = "mockstock.account.v2"
    private let setupKey = "mockstock.needsSetup.v2"

    private init() {
        if let data = UserDefaults.standard.data(forKey: accountKey),
           let acc = try? JSONDecoder().decode(Account.self, from: data) {
            self.account = acc
            self.needsSetup = UserDefaults.standard.bool(forKey: setupKey)
        } else {
            self.account = .fresh(.steady)
            self.needsSetup = true
        }
    }

    // MARK: - 模式

    func chooseMode(_ mode: GameMode) {
        account = .fresh(mode)
        needsSetup = false
    }

    /// 重置账户，回到模式选择
    func resetToSetup() {
        needsSetup = true
    }

    // MARK: - 交易

    /// 浮点容差。加密货币份额是小数，直接比较 `<=` 会因精度误差误判
    private let eps = 1e-9

    /// 买入。返回 nil 表示成功，否则返回错误文案
    func buy(code: String, name: String, price: Double, shares: Double) -> String? {
        guard shares > eps else { return "数量必须大于 0" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }

        let amount = price * shares
        if !account.mode.isUnlimited {
            guard amount <= account.cash + 1e-6 else {
                return "可用资金不足，需要 \(Fmt.money(amount))"
            }
        }
        account.cash -= amount

        if let idx = account.positions.firstIndex(where: { $0.code == code }) {
            let old = account.positions[idx]
            let totalShares = old.shares + shares
            let totalCost = old.costPrice * old.shares + amount
            account.positions[idx].shares = totalShares
            account.positions[idx].costPrice = totalCost / totalShares
        } else {
            account.positions.append(Position(code: code, name: name, shares: shares, costPrice: price))
        }

        pushRecord(code: code, name: name, side: .buy, price: price, shares: shares)
        return nil
    }

    /// 卖出。返回 nil 表示成功，否则返回错误文案
    func sell(code: String, price: Double, shares: Double) -> String? {
        guard shares > eps else { return "数量必须大于 0" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }
        guard let idx = account.positions.firstIndex(where: { $0.code == code }) else {
            return "没有该股票的持仓"
        }

        let pos = account.positions[idx]
        guard shares <= pos.shares + eps else {
            return "持仓不足，最多可卖 \(Fmt.qty(pos.shares, code: code))"
        }

        let amount = price * shares
        account.cash += amount

        let remain = pos.shares - shares
        if remain <= eps {
            account.positions.remove(at: idx)
        } else {
            account.positions[idx].shares = remain
        }

        pushRecord(code: code, name: pos.name, side: .sell, price: price, shares: shares)
        return nil
    }

    private func pushRecord(code: String, name: String, side: TradeSide, price: Double, shares: Double) {
        let record = TradeRecord(code: code, name: name, side: side, price: price, shares: shares, date: Date())
        account.records.insert(record, at: 0)
        // 只保留最近 200 条
        if account.records.count > 200 {
            account.records = Array(account.records.prefix(200))
        }
    }

    // MARK: - 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: accountKey)
        }
        UserDefaults.standard.set(needsSetup, forKey: setupKey)
    }
}
