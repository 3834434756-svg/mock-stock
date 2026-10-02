import Foundation
import Combine

/// 预埋单 / 限价单中心。
///
/// 现实模式：休市时挂的市价单，等真开盘了自动帮你射出去 —— 挂机挂单。
/// 游戏模式：限价单，模拟价格一旦触达就成交 —— 埋伏。
@MainActor
final class OrderCenter: ObservableObject {
    static let shared = OrderCenter()

    @Published private(set) var orders: [PendingOrder] = []

    private let key = "mockstock.orders.v1"

    private init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([PendingOrder].self, from: d) {
            orders = list
        }
    }

    var pending: [PendingOrder] { orders.filter { $0.status == .pending } }
    var history: [PendingOrder] { orders.filter { $0.status != .pending } }

    func add(_ order: PendingOrder) {
        orders.insert(order, at: 0)
        if orders.count > 100 { orders = Array(orders.prefix(100)) }
        save()
    }

    func cancel(_ id: UUID) {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[i].status = .cancelled
        orders[i].note = "手动撤销"
        save()
    }

    func clear() {
        orders = []
        save()
    }

    /// 每次行情刷新后调用，撮合所有满足条件的挂单
    func process(prices: [String: Double], freshCodes: Set<String>) {
        guard !pending.isEmpty else { return }
        let isGame = AccountStore.shared.account.world == .game
        let store = AccountStore.shared
        var changed = false

        for i in orders.indices where orders[i].status == .pending {
            let o = orders[i]
            guard let price = prices[o.code], price > 0 else { continue }

            let market = Market(code: o.code)
            let open = isGame || market.is24x7 || freshCodes.contains(o.code)
            guard o.shouldFire(price: price, marketOpen: open) else { continue }

            let err: String?
            if o.side == .buy {
                err = store.buy(code: o.code, name: o.name, price: price,
                                shares: o.shares, leverage: o.leverage)
            } else {
                err = store.sell(code: o.code, price: price, shares: o.shares)
            }

            if let err {
                orders[i].status = .failed
                orders[i].note = err
            } else {
                orders[i].status = .filled
                orders[i].filledAt = Date()
                orders[i].filledPrice = price
                orders[i].note = o.isLimit ? "限价触发成交" : "开盘自动成交"
                if o.isLimit {
                    AchievementCenter.shared.recordLimitOrderWin()
                }
            }
            changed = true
        }

        if changed { save() }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(orders) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}
