import Foundation

/// 行情路由层。
///
/// 上层（ViewModel）只跟它打交道，完全不需要知道当前是哪个世界 ——
/// 现实世界转发给腾讯 / 币安接口，游戏世界转发给本地引擎。
/// 这样「加一个模式」不会把现有代码搅成一团条件分支。
@MainActor
final class QuoteProvider {
    static let shared = QuoteProvider()

    private let api = MarketAPI.shared
    private var isGame: Bool { AccountStore.shared.account.world == .game }

    // MARK: - 行情

    func quotes(codes: [String]) async -> [Quote] {
        guard !codes.isEmpty else { return [] }
        if isGame {
            await ensureSeeded(codes)
            return GameEngine.shared.quotes(for: codes)
        }
        return await realQuotes(codes: codes)
    }

    /// 加密货币行情（代码带 cb 前缀）
    func cryptoQuotes(symbols: [String]) async -> [Quote] {
        guard !symbols.isEmpty else { return [] }
        if isGame {
            let codes = symbols.map { "cb" + $0 }
            let missing = codes.filter { GameEngine.shared.sims[$0] == nil }
            if !missing.isEmpty {
                let syms = missing.map { String($0.dropFirst(2)) }
                if let real = try? await CryptoAPI.shared.quotes(symbols: syms) {
                    GameEngine.shared.seed(real)
                }
            }
            return GameEngine.shared.quotes(for: codes)
        }
        return (try? await CryptoAPI.shared.quotes(symbols: symbols)) ?? []
    }

    /// 真实行情：股票与加密货币走不同接口，必须分流
    func realQuotes(codes: [String]) async -> [Quote] {
        let stockCodes = codes.filter { Market(code: $0) != .crypto }
        let cryptoCodes = codes.filter { Market(code: $0) == .crypto }

        var out: [Quote] = []
        if !stockCodes.isEmpty, let list = try? await api.quotes(codes: stockCodes) {
            out.append(contentsOf: list)
        }
        if !cryptoCodes.isEmpty {
            let syms = cryptoCodes.map { String($0.dropFirst(2)) }
            if let list = try? await CryptoAPI.shared.quotes(symbols: syms) {
                out.append(contentsOf: list)
            }
        }
        return out
    }

    /// 保证游戏引擎里有这些标的的模拟状态
    func ensureSeeded(_ codes: [String]) async {
        let missing = codes.filter { GameEngine.shared.sims[$0] == nil }
        guard !missing.isEmpty else { return }
        let real = await realQuotes(codes: missing)
        GameEngine.shared.seed(real)
    }

    // MARK: - K线

    func klines(code: String, count: Int = 60) async -> [KLine] {
        if isGame {
            await ensureSeeded([code])
            if GameEngine.shared.realKlines[code] == nil {
                let ks = await realKlines(code: code, count: max(count, 90))
                GameEngine.shared.cacheKlines(ks, for: code)
            }
            return GameEngine.shared.klines(for: code, count: count)
        }
        return await realKlines(code: code, count: count)
    }

    private func realKlines(code: String, count: Int) async -> [KLine] {
        if Market(code: code) == .crypto {
            let symbol = String(code.dropFirst(2))
            return (try? await CryptoAPI.shared.klines(symbol: symbol, count: count)) ?? []
        }
        return (try? await api.klines(code: code, count: count)) ?? []
    }

    // MARK: - 榜单

    func rank(count: Int = 100) async -> [RankItem] {
        guard let list = try? await api.rankList(count: count) else { return [] }
        guard isGame else { return list }

        // 游戏模式：真实榜单只用来提供「有哪些股票」，价格换成模拟价
        let codes = list.map(\.code)
        await ensureSeeded(codes)
        return list.compactMap { item in
            guard let s = GameEngine.shared.sims[item.code] else { return nil }
            return RankItem(code: item.code, name: s.name, price: s.price,
                            changePercent: s.changePercent, turnover: item.turnover)
        }
    }

    // MARK: - 搜索

    func search(_ keyword: String) async -> [SearchResult] {
        (try? await api.search(keyword: keyword)) ?? []
    }

    // MARK: - 开盘状态

    /// 该标的现在能不能交易。游戏模式永远返回 true
    func isTrading(code: String, quoteTime: String?) -> Bool {
        if isGame { return true }
        let market = Market(code: code)
        if market.is24x7 { return true }
        if let t = quoteTime, QuoteClock.isToday(t) { return true }
        return MarketClock.isOpenNow(market)
    }

    /// 全市场是否至少有一个在交易
    var anyMarketOpen: Bool {
        if isGame { return true }
        return [Market.aShare, .hk, .us, .crypto].contains { MarketClock.isOpenNow($0) }
    }
}
