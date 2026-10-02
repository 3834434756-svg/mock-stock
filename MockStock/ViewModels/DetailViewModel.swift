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

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let list = try await api.quotes(codes: [code])
            if let first = list.first {
                quote = first
                errorText = nil
            }
        } catch {
            if quote == nil { errorText = "行情加载失败" }
        }

        if let ks = try? await api.klines(code: code, count: 60) {
            klines = ks
        }
    }

    /// 只刷新报价。K线一天才变一次，轮询时没必要重拉。
    func refreshQuote() async {
        guard let list = try? await api.quotes(codes: [code]),
              let first = list.first else { return }
        quote = first
        errorText = nil
    }
}
