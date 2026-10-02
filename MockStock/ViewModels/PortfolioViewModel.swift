import Foundation
import Combine

/// 持仓页：拉取持仓标的现价，算浮动盈亏
@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading = false

    private let provider = QuoteProvider.shared

    var isGame: Bool { AccountStore.shared.isGame }

    /// 轮询间隔。游戏模式价格是本地算的，可以刷得快一点
    var pollInterval: TimeInterval { isGame ? 2 : 15 }

    func refresh(positions: [Position]) async {
        guard !positions.isEmpty else {
            quotes = [:]
            return
        }
        isLoading = true
        defer { isLoading = false }

        let codes = positions.map(\.code)
        let list = await provider.quotes(codes: codes)
        guard !list.isEmpty else { return }
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }
        quotes.merge(dict) { _, new in new }

        // 撮合挂单 + 检查杠杆强平，两个页面都要做，避免只在行情页才生效
        var prices: [String: Double] = [:]
        for (k, v) in quotes { prices[k] = v.price }
        let fresh = Set(quotes.values.filter { QuoteClock.isToday($0.time) }.map(\.code))
        OrderCenter.shared.process(prices: prices, freshCodes: fresh)
        AccountStore.shared.checkLiquidations(prices: prices)
    }

    // MARK: - 数据新鲜度

    /// 持仓里最新的一条行情时间，形如 `09-30 16:14`
    var latestQuoteTime: String? {
        quotes.values.compactMap { QuoteClock.display($0.time) }.max()
    }

    /// 是否所有持仓的行情都是今天的数据
    var allQuotesToday: Bool {
        !quotes.isEmpty && quotes.values.allSatisfy { QuoteClock.isToday($0.time) }
    }
}
