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

    private let provider = QuoteProvider.shared

    init(code: String, seed: Quote? = nil) {
        self.code = code
        self.quote = seed
    }

    var displayName: String {
        quote?.name ?? code.uppercased()
    }

    var isGame: Bool { AccountStore.shared.isGame }

    /// 轮询间隔。游戏模式价格本地模拟，刷新可以更快
    var pollInterval: TimeInterval { isGame ? 2 : 15 }

    /// 买卖点标记。数据来自本地成交记录，按日期贴到 K 线上
    var markers: [ChartMarker] {
        let records = AccountStore.shared.account.records.filter { $0.code == code }
        guard !records.isEmpty else { return [] }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return records.map {
            ChartMarker(date: f.string(from: $0.date), price: $0.price, side: $0.side)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        if let q = await fetchQuote() {
            quote = q
            errorText = nil
        } else if quote == nil {
            errorText = "行情加载失败"
        }

        let ks = await provider.klines(code: code, count: 60)
        if !ks.isEmpty { klines = ks }
    }

    /// 只刷新报价。K线一天才变一次，轮询时没必要重拉。
    func refreshQuote() async {
        guard let q = await fetchQuote() else { return }
        quote = q
        errorText = nil
    }

    private func fetchQuote() async -> Quote? {
        await provider.quotes(codes: [code]).first
    }
}
