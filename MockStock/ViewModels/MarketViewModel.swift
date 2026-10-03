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

    /// 上一次的总资产，用于触发盈亏爽感反馈
    private var lastTotal: Double?
    /// 上一次的世界与模式。切换后要重置 `lastTotal`，避免跨局比较
    private var lastWorld: TradingWorld?
    private var lastMode: GameMode?

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

    private let provider = QuoteProvider.shared
    private let watchKey = "mockstock.watchlist.v1"
    private var timer: Timer?

    static let defaultWatchlist = ["sh600519", "sz000001", "hk00700", "usAAPL", "usTSLA"]

    /// 当前是否游戏世界
    var isGame: Bool { AccountStore.shared.isGame }

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
        sortedQuotes.compactMap { QuoteClock.display($0.time) }.max()
    }

    /// 自选行情是否都是今天的数据（休市时会为 false）
    var watchQuotesToday: Bool {
        let list = sortedQuotes
        return !list.isEmpty && list.allSatisfy { QuoteClock.isToday($0.time) }
    }

    /// 当前所有已知价格，供挂单撮合 / 强平 / 成就判定
    var allPrices: [String: Double] {
        var d: [String: Double] = [:]
        for (k, v) in quotes { d[k] = v.price }
        for q in cryptoQuotes { d[q.code] = q.price }
        for q in popularQuotes { d[q.code] = q.price }
        // 只有游戏世界才认本地模拟价。现实盘下若残留 sims，
        // 用模拟价去判定强平会凭空打出爆仓
        if isGame {
            for (k, v) in GameEngine.shared.sims { d[k] = v.price }
        }
        return d
    }

    // MARK: - 拉取

    /// 拉自选行情。自选里可能同时有股票和加密货币，路由层会分流。
    ///
    /// 除了自选，还会顺带拉一次挂单标的的行情 —— 否则挂在自选之外的限价单
    /// 永远等不到价格，撮合不了。
    func load() async {
        var codes = watchlist
        codes.append(contentsOf: OrderCenter.shared.pending.map(\.code))
        let unique = Array(Set(codes))

        guard !unique.isEmpty else {
            quotes = [:]
            return
        }
        isLoading = true
        defer { isLoading = false }

        let list = await provider.quotes(codes: unique)
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }

        // 合并而非整体替换：某一路接口临时失败时，另一路的好数据不该被清掉
        quotes.merge(dict) { _, new in new }
        lastError = watchlist.isEmpty ? nil : (sortedQuotes.isEmpty ? "行情获取失败，请检查网络" : nil)
        afterRefresh()
    }

    /// 拉加密货币行情。
    ///
    /// 币圈 24 小时不打烊，所以**两个世界都要刷** —— 现实虚拟盘里也一样，
    /// 之前只在游戏模式刷，导致现实模式下加密货币列表的价格一直停着不动。
    func loadCrypto() async {
        let list = await provider.cryptoQuotes(symbols: CryptoCoin.allSymbols)
        guard !list.isEmpty else { return }
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }
        // 按币种表顺序排列；接口这次没返回的沿用上一轮的值，
        // 避免偶发丢包让整行价格闪成空白
        let old = Dictionary(cryptoQuotes.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        cryptoQuotes = CryptoCoin.allCodes.compactMap { dict[$0] ?? old[$0] }
        afterRefresh()
    }

    /// 拉热门股行情
    func loadPopular() async {
        let codes = PopularStocks.allCodes
        let list = await provider.quotes(codes: codes)
        var dict: [String: Quote] = [:]
        for q in list { dict[q.code] = q }
        popularQuotes = codes.compactMap { dict[$0] }
    }

    /// 拉榜单（一次 100 只，客户端再排序）
    func loadRank() async {
        isLoadingRank = true
        defer { isLoadingRank = false }
        let list = await provider.rank()
        if !list.isEmpty { rankItems = list }
    }

    // MARK: - 刷新后的连带处理

    /// 每次拿到新价格后要做的事：撮合挂单 → 检查强平 → 判定成就 → 触发爽感
    private func afterRefresh() {
        let prices = allPrices
        guard !prices.isEmpty else { return }

        let fresh = Set(quotes.values.filter { QuoteClock.isToday($0.time) }.map(\.code))
        OrderCenter.shared.process(prices: prices, freshCodes: fresh)

        let store = AccountStore.shared

        // 换世界 / 重开一局后总资产会整体换口径，旧的基准必须丢掉，
        // 否则第一次刷新会被算成"暴涨"或"暴跌"，直接甩一个特效出来
        if lastWorld != store.account.world || lastMode != store.account.mode {
            lastWorld = store.account.world
            lastMode = store.account.mode
            lastTotal = nil
        }

        store.checkLiquidations(prices: prices)

        let total = store.account.totalAssets(prices: prices)
        // 反馈强度按「相对上一次总资产」的变化算。
        // 之前用「相对初始资金」算，杠杆建仓/平仓会让总资产在两种口径间跳一下，
        // 于是卖出一笔就被判成巨亏、直接播爆仓特效。
        // 阈值跟 `Juice` 内部的档位对齐，低于 5% 不打扰用户。
        if let prev = lastTotal, prev > 0 {
            let delta = (total - prev) / prev
            if abs(delta) >= 0.05 {
                if delta > 0 { Juice.profit(ratio: delta) } else { Juice.loss(ratio: delta) }
            }
        }
        lastTotal = total

        AchievementCenter.shared.evaluateSnapshot(account: store.account,
                                                   totalAssets: total, prices: prices)
    }

    // MARK: - 自选管理

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

    /// 游戏模式本地模拟，刷新可以很快；现实模式要顾及接口压力，保持 15 秒
    var pollInterval: TimeInterval { isGame ? 2 : 15 }

    func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.load()
                await self.loadPopular()
                // 加密货币 24 小时交易，两种世界都必须跟着刷
                await self.loadCrypto()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
