import Foundation
import Combine

/// 行情页：自选列表 + 轮询
@MainActor
final class MarketViewModel: ObservableObject {
    @Published var watchlist: [String] = []
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading = false
    @Published var lastError: String?

    /// 热门股行情（按 PopularStocks 顺序）
    @Published var popularQuotes: [Quote] = []
    /// 榜单原始数据（100 只），排序在客户端做
    @Published var rankItems: [RankItem] = []
    @Published var isLoadingRank = false
    /// 加密货币行情（按 CryptoCoin.all 顺序）
    @Published var cryptoQuotes: [Quote] = []

    enum RankMode: String, CaseIterable, Identifiable {
        case gainers, losers

        var id: String { rawValue }
        var title: String { self == .gainers ? "涨幅榜" : "跌幅榜" }
    }

    /// 按当前榜单模式排好序的列表
    func ranked(_ mode: RankMode) -> [RankItem] {
        switch mode {
        case .gainers: return rankItems.sorted { $0.changePercent > $1.changePercent }
        case .losers: return rankItems.sorted { $0.changePercent < $1.changePercent }
        }
    }

    private let api = MarketAPI.shared
    private let watchKey = "mockstock.watchlist.v1"
    private var timer: Timer?

    static let defaultWatchlist = ["sh600519", "sz000001", "hk00700", "usAAPL", "usTSLA"]

    init() {
        if let saved = UserDefaults.standard.array(forKey: watchKey) as? [String], !saved.isEmpty {
            watchlist = saved
        } else {
            watchlist = Self.defaultWatchlist
        }
    }

    /// 按自选顺序排列的行情
    var sortedQuotes: [Quote] {
        watchlist.compactMap { quotes[$0] }
    }

    /// 自选里最新的一条行情时间，形如 `09-30 16:14`
    var latestWatchTime: String? {
        quotes.values.compactMap { QuoteClock.display($0.time) }.max()
    }

    /// 自选行情是否都是今天的数据（休市时会为 false）
    var watchQuotesToday: Bool {
        !quotes.isEmpty && quotes.values.allSatisfy { QuoteClock.isToday($0.time) }
    }

    /// 拉自选行情。
    ///
    /// 自选里可能同时有股票和加密货币，两者走不同接口，必须分流后合并 ——
    /// 把 `cbBTCUSDT` 丢给腾讯接口只会拿到空结果。
    func load() async {
        guard !watchlist.isEmpty else {
            quotes = [:]
            return
        }
        isLoading = true
        defer { isLoading = false }

        let stockCodes = watchlist.filter { Market(code: $0) != .crypto }
        let cryptoCodes = watchlist.filter { Market(code: $0) == .crypto }

        var dict: [String: Quote] = [:]

        if !stockCodes.isEmpty, let list = try? await api.quotes(codes: stockCodes) {
            for q in list { dict[q.code] = q }
        }
        if !cryptoCodes.isEmpty {
            let symbols = cryptoCodes.map { String($0.dropFirst(2)) }
            if let list = try? await CryptoAPI.shared.quotes(symbols: symbols) {
                for q in list { dict[q.code] = q }
            }
        }

        // 合并而非整体替换：某一路接口临时失败时，另一路的好数据不该被清掉
        quotes.merge(dict) { _, new in new }
        lastError = quotes.isEmpty ? "行情获取失败，请检查网络" : nil
    }

    /// 拉加密货币行情（币安接口，24 小时交易）
    func loadCrypto() async {
        guard let list = try? await CryptoAPI.shared.quotes(symbols: CryptoCoin.allSymbols) else { return }
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }
        cryptoQuotes = CryptoCoin.allCodes.compactMap { dict[$0] }
    }

    /// 拉热门股行情。只在首次进入时拉一次，之后跟随轮询刷新
    func loadPopular() async {
        let codes = PopularStocks.allCodes
        guard let list = try? await api.quotes(codes: codes) else { return }
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }
        popularQuotes = codes.compactMap { dict[$0] }
    }

    /// 拉榜单（一次 100 只，客户端再排序）
    func loadRank() async {
        isLoadingRank = true
        defer { isLoadingRank = false }
        if let list = try? await api.rankList() {
            rankItems = list
        }
    }

    func add(_ code: String) {
        guard !watchlist.contains(code) else { return }
        watchlist.append(code)
        persist()
        Task { await load() }
    }

    func remove(_ code: String) {
        watchlist.removeAll { $0 == code }
        quotes[code] = nil
        persist()
    }

    func remove(at offsets: IndexSet) {
        let codes = offsets.map { watchlist[$0] }
        watchlist.remove(atOffsets: offsets)
        for c in codes { quotes[c] = nil }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func isWatched(_ code: String) -> Bool {
        watchlist.contains(code)
    }

    private func persist() {
        UserDefaults.standard.set(watchlist, forKey: watchKey)
    }

    // MARK: - 轮询

    func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.load()
                await self?.loadPopular()
                await self?.loadCrypto()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
