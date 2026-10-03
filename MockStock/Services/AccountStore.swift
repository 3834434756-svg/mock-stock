import Foundation
import Combine

/// 账户与交易引擎（本地模拟撮合 + 持久化）
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published var account: Account {
        didSet {
            save()
            // 持仓一变就同步给行情引擎。引擎靠这份快照在重启后
            // 用成本价给持仓标的定价，避免价格跳变打爆杠杆仓位
            GameEngine.shared.syncHeld(heldCostMap)
        }
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

        // 冷启动时如果是游戏模式，引擎和事件中心要重新跑起来
        // （Timer 不会跨进程存活，重启后必须显式 start）
        if !needsSetup, account.world == .game {
            // init 里的赋值不会触发 didSet，这里手动推一次持仓快照
            GameEngine.shared.syncHeld(heldCostMap)
            GameEngine.shared.start()
            EventCenter.shared.start()
        }
    }

    /// 持仓成本价快照。推给游戏引擎，供重启后给持仓标的定价
    private var heldCostMap: [String: Double] {
        var m: [String: Double] = [:]
        for p in account.positions { m[p.code] = p.costPrice }
        return m
    }

    // MARK: - 世界 / 模式

    var world: TradingWorld { account.world }
    var isGame: Bool { account.world == .game }

    /// 开始新的一局
    func choose(world: TradingWorld, mode: GameMode) {
        account = .fresh(world: world, mode)
        needsSetup = false

        AchievementCenter.shared.reset(baseline: mode.initialCapital)
        OrderCenter.shared.clear()
        EventCenter.shared.reset()
        GameEngine.shared.reset()

        if world == .game {
            GameEngine.shared.start()
            EventCenter.shared.start()
        } else {
            EventCenter.shared.stop()
        }
        save()
    }

    /// 重置账户，回到模式选择。
    /// 币账户虽然独立记账，但同属这个 App 的进度，一并清空
    func resetToSetup() {
        needsSetup = true
        GameEngine.shared.stop()
        EventCenter.shared.stop()
        CryptoStore.shared.reset()
        MissionCenter.shared.reset()
    }

    // MARK: - 交易

    /// 浮点容差。加密货币份额是小数，直接比较 `<=` 会因精度误差误判
    private let eps = 1e-9

    /// 买入。返回 nil 表示成功，否则返回错误文案
    func buy(code: String, name: String, price: Double,
             shares: Double, leverage: Double = 1) -> String? {
        guard shares > eps else { return "数量必须大于 0" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }

        let lev = max(1, leverage)
        let amount = price * shares
        let margin = amount / lev

        if !account.mode.isUnlimited {
            guard margin <= account.cash + 1e-6 else {
                return "可用资金不足，需要 \(Fmt.money(margin))"
            }
        }

        // 同一标的只能有一个杠杆倍数，否则成本与强平价会算不清
        if let idx = account.positions.firstIndex(where: { $0.code == code }) {
            let old = account.positions[idx]
            guard abs(old.leverage - lev) < 0.001 else {
                return "该持仓已是 \(Int(old.leverage))x 杠杆，请先平仓再换杠杆"
            }
        }

        account.cash -= margin

        if let idx = account.positions.firstIndex(where: { $0.code == code }) {
            let old = account.positions[idx]
            let totalShares = old.shares + shares
            let totalCost = old.costPrice * old.shares + amount
            account.positions[idx].shares = totalShares
            account.positions[idx].costPrice = totalCost / totalShares
        } else {
            account.positions.append(
                Position(code: code, name: name, shares: shares, costPrice: price, leverage: lev)
            )
        }

        pushRecord(code: code, name: name, side: .buy, price: price, shares: shares)
        AchievementCenter.shared.recordBuy(code: code, amount: amount, leverage: lev)
        Juice.trade()
        return nil
    }

    /// 卖出。返回 nil 表示成功，否则返回错误文案
    func sell(code: String, price: Double, shares: Double) -> String? {
        guard shares > eps else { return "数量必须大于 0" }
        guard price > 0 else { return "行情未就绪，请稍后重试" }
        guard let idx = account.positions.firstIndex(where: { $0.code == code }) else {
            return "没有该标的的持仓"
        }

        let pos = account.positions[idx]
        guard shares <= pos.shares + eps else {
            return "持仓不足，最多可卖 \(Fmt.qty(pos.shares, code: code))"
        }

        let ratio = shares / pos.shares
        let marginPortion = pos.capitalUsed * ratio
        let pnl = (price - pos.costPrice) * shares
        // 杠杆仓位理论上可能亏穿本金，回收金额不为负
        account.cash += max(0, marginPortion + pnl)

        let remain = pos.shares - shares
        if remain <= eps {
            account.positions.remove(at: idx)
        } else {
            account.positions[idx].shares = remain
        }

        pushRecord(code: code, name: pos.name, side: .sell, price: price, shares: shares)
        AchievementCenter.shared.recordSell(profit: pnl, profitPercent: pos.profitPercent(price: price))
        Juice.trade()
        return nil
    }

    // MARK: - 杠杆强平

    /// 检查所有杠杆仓位，触及强平价的一律平掉。返回被强平的名称
    @discardableResult
    func checkLiquidations(prices: [String: Double]) -> [String] {
        var closed: [String] = []
        for pos in account.positions where pos.isLeveraged {
            guard let p = prices[pos.code], p > 0, pos.isLiquidated(price: p) else { continue }
            let recovered = max(0, pos.equity(price: p))
            let pnl = pos.profit(price: p)
            account.cash += recovered
            pushRecord(code: pos.code, name: pos.name, side: .sell, price: p, shares: pos.shares)
            account.positions.removeAll { $0.code == pos.code }
            closed.append(pos.name)
            AchievementCenter.shared.recordLiquidation()
            AchievementCenter.shared.recordSell(profit: pnl, profitPercent: -100)
        }
        if !closed.isEmpty {
            Juice.liquidation(detail: "\(closed.joined(separator: "、")) 已强制平仓")
        }
        return closed
    }

    // MARK: - 成就与爽感
    //
    // 说明：成就判定与爽感反馈的唯一入口在 `MarketViewModel.afterRefresh()`
    // 与 `PortfolioViewModel.refresh()`（都要触发，否则只在行情页才生效）。
    // 这里不再放第二份实现 —— 两份逻辑曾经因为资产口径不一致而互相打架。

    /// 事件与快捷操作用的可支配金额
    func budget(ratio: Double) -> Double {
        account.mode.isUnlimited
            ? account.mode.notionalPerAllIn * ratio
            : account.cash * ratio
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
