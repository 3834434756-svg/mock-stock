import Foundation
import Combine

/// 成就判定中心。
///
/// 判定分散在三个时机：下单成交后、行情刷新后、事件决策后。
/// 所有统计都落盘，重启 App 不清零（除非重置账户）。
@MainActor
final class AchievementCenter: ObservableObject {
    static let shared = AchievementCenter()

    /// 已解锁成就 id → 解锁时间
    @Published private(set) var unlocked: [String: Date] = [:]
    /// 待展示的解锁弹窗
    @Published var toast: Achievement?
    /// 突发事件连续正确次数（「见风使舵」）
    @Published private(set) var goodEventStreak = 0

    struct Stats: Codable {
        var marketsTraded: [String] = []
        var tradesCount = 0
        var maxBuyAmount: Double = 0
        var liquidationCount = 0
        var limitOrderWins = 0
        /// 本次开局的资产基准，用于「起飞」判定
        var sessionBaseline: Double = 0
    }

    @Published private(set) var stats = Stats()

    private let unlockedKey = "mockstock.achv.unlocked.v1"
    private let statsKey = "mockstock.achv.stats.v1"

    private init() {
        if let d = UserDefaults.standard.data(forKey: unlockedKey),
           let m = try? JSONDecoder().decode([String: Date].self, from: d) {
            unlocked = m
        }
        if let d = UserDefaults.standard.data(forKey: statsKey),
           let s = try? JSONDecoder().decode(Stats.self, from: d) {
            stats = s
        }
    }

    // MARK: - 生命周期

    func reset(baseline: Double) {
        unlocked = [:]
        stats = Stats()
        stats.sessionBaseline = baseline
        goodEventStreak = 0
        save()
    }

    func clearToast() { toast = nil }

    // MARK: - 解锁

    func unlock(_ id: String) {
        guard unlocked[id] == nil, let a = AchievementCatalog.find(id) else { return }
        unlocked[id] = Date()
        toast = a
        Juice.achievement()
        save()

        // 3 秒后自动收起弹窗
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast?.id == a.id { toast = nil }
        }

        if id != "everything", unlocked.count >= 20 {
            unlock("everything")
        }
    }

    func isUnlocked(_ id: String) -> Bool { unlocked[id] != nil }

    var unlockedCount: Int { unlocked.count }

    /// 某世界可见的成就，已解锁的排前面、稀有度高的排后面
    func list(for world: TradingWorld) -> [Achievement] {
        AchievementCatalog.forWorld(world).sorted { a, b in
            let ua = isUnlocked(a.id), ub = isUnlocked(b.id)
            if ua != ub { return ua }
            if a.tier.weight != b.tier.weight { return a.tier.weight < b.tier.weight }
            return a.title < b.title
        }
    }

    // MARK: - 记录

    func recordBuy(code: String, amount: Double, leverage: Double) {
        stats.tradesCount += 1
        stats.maxBuyAmount = max(stats.maxBuyAmount, amount)
        note(market: Market(code: code))
        save()

        unlock("first_buy")
        if leverage >= 5 { unlock("leverage_newbie") }
        if stats.maxBuyAmount >= 1_000_000_000 { unlock("whale") }
        if stats.tradesCount >= 100 { unlock("hundred_trades") }
    }

    func recordSell(profit: Double, profitPercent: Double) {
        stats.tradesCount += 1
        save()
        if profit > 0 { unlock("first_profit") }
        if profitPercent >= 1000 { unlock("ten_bagger") }
        if profit < 0 && profitPercent <= -20 { unlock("cut_loss") }
        if stats.tradesCount >= 100 { unlock("hundred_trades") }
    }

    func recordLiquidation() {
        stats.liquidationCount += 1
        save()
        unlock("back_to_zero")
    }

    func recordLimitOrderWin() {
        stats.limitOrderWins += 1
        save()
        unlock("limit_order_win")
    }

    /// 事件决策结果
    func recordEventDecision(good: Bool) {
        goodEventStreak = good ? goodEventStreak + 1 : 0
        if goodEventStreak >= 5 { unlock("event_surfer") }
    }

    // MARK: - 快照判定

    func evaluateSnapshot(account: Account, totalAssets: Double, prices: [String: Double]) {
        let base = account.mode.initialCapital
        guard base > 0 else { return }

        if totalAssets <= base * 0.5 { unlock("leek") }
        if totalAssets <= base * 0.1 { unlock("broke") }
        if totalAssets >= base * 2 { unlock("stockGod") }
        if totalAssets >= 100_000_000 { unlock("richMan") }
        if account.positions.count >= 5 { unlock("diversifier") }
        if stats.sessionBaseline > 0, totalAssets >= stats.sessionBaseline * 1.5 {
            unlock("moon_shot")
        }

        for pos in account.positions {
            let price = prices[pos.code] ?? pos.costPrice
            // 判定「重仓」要用净值口径。杠杆仓位的名义市值可能是自有资金的 10 倍，
            // 用 marketValue 去比 totalAssets 会把「全仓」成就白送出去
            let net = pos.netValue(price: price)
            let mv = pos.marketValue(price: price)
            let pct = pos.profitPercent(price: price)
            if pct >= 1000 { unlock("ten_bagger") }
            if totalAssets > 0, net >= totalAssets * 0.95 { unlock("all_in") }
            if pos.code.uppercased().contains("TSLA"), mv >= 10_000_000_000 {
                unlock("tesla_private")
            }
            // 力挽狂澜：这只标的曾经腰斩，现在被拉回 +10%，且你重仓握着
            if let low = GameEngine.shared.lowestChange[pos.code],
               low <= -50,
               let sim = GameEngine.shared.sims[pos.code],
               sim.changePercent >= 10,
               totalAssets > 0, net >= totalAssets * 0.5 {
                unlock("saved_the_day")
            }
        }

        // 钻石手：从最早一笔成交算起，持有超过 30 天
        for pos in account.positions {
            if let oldest = account.records.last(where: { $0.code == pos.code })?.date,
               Date().timeIntervalSince(oldest) > 30 * 86400 {
                unlock("diamond_hands")
            }
        }
    }

    // MARK: - 工具

    private func note(market: Market) {
        let name = market.displayName
        if !stats.marketsTraded.contains(name) {
            stats.marketsTraded.append(name)
            save()
        }
        if stats.marketsTraded.count >= 4 { unlock("all_markets") }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(unlocked) {
            UserDefaults.standard.set(d, forKey: unlockedKey)
        }
        if let d = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(d, forKey: statsKey)
        }
    }
}
