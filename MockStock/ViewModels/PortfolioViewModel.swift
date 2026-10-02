import Foundation
import Combine

/// 持仓页：拉取持仓股票的现价，算浮动盈亏
@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading = false

    private let api = MarketAPI.shared

    func refresh(positions: [Position]) async {
        guard !positions.isEmpty else {
            quotes = [:]
            return
        }
        isLoading = true
        defer { isLoading = false }

        let codes = positions.map(\.code)
        if let list = try? await api.quotes(codes: codes) {
            var dict: [String: Quote] = [:]
            for q in list { dict[q.code] = q }
            quotes = dict
        }
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
