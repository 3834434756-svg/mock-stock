import Foundation
import Combine

/// 个股详情页
@MainActor
final class DetailViewModel: ObservableObject {
    let code: String
    @Published var quote: Quote?
    @Published var klines: [KLine] = []
    @Published var isLoading = false
    @Published var errorText: String?

    private let api = MarketAPI.shared

    init(code: String, seed: Quote? = nil) {
        self.code = code
        self.quote = seed
    }

    var displayName: String {
        quote?.name ?? code.uppercased()
    }

    private var isCrypto: Bool { Market(code: code) == .crypto }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        if let q = await fetchQuote() {
            quote = q
            errorText = nil
        } else if quote == nil {
            errorText = "行情加载失败"
        }

        if let ks = await fetchKlines() {
            klines = ks
        }
    }

    /// 只刷新报价。K线一天才变一次，轮询时没必要重拉。
    func refreshQuote() async {
        guard let q = await fetchQuote() else { return }
        quote = q
        errorText = nil
    }

    // MARK: - 分流

    /// 股票走腾讯接口，加密货币走币安接口
    private func fetchQuote() async -> Quote? {
        if isCrypto {
            let symbol = String(code.dropFirst(2))
            return (try? await CryptoAPI.shared.quotes(symbols: [symbol]))?.first
        }
        return (try? await api.quotes(codes: [code]))?.first
    }

    private func fetchKlines() async -> [KLine]? {
        if isCrypto {
            let symbol = String(code.dropFirst(2))
            return try? await CryptoAPI.shared.klines(symbol: symbol, count: 60)
        }
        return try? await api.klines(code: code, count: 60)
    }
}
