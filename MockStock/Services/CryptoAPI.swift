import Foundation

/// 加密货币行情。
///
/// 主源币安，失败自动降级到 OKX —— 这两家在部分网络环境下不一定都通，
/// 多备一个源就多一条活路。探测结果会缓存，避免每次轮询都白试一遍。
///
/// 价格处理约定：接口返回 USDT 价，这里统一乘 `FX.usdtToCNY` 折成人民币，
/// 与股票共用同一套记账逻辑；展示时由 `Quote.displayPrice` 还原回 USDT。
final class CryptoAPI {
    static let shared = CryptoAPI()

    enum Source: String {
        case binance = "币安"
        case okx = "OKX"
    }

    /// 已探测到可用的源
    private(set) var activeSource: Source?

    /// 界面标注用的数据源名
    var sourceLabel: String { activeSource?.rawValue ?? "未知" }

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 20
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - 行情

    func quotes(symbols: [String]) async throws -> [Quote] {
        guard !symbols.isEmpty else { return [] }

        if let s = activeSource, let list = await fetchQuotes(s, symbols), !list.isEmpty {
            return list
        }
        for s in [Source.binance, .okx] {
            if let list = await fetchQuotes(s, symbols), !list.isEmpty {
                activeSource = s
                return list
            }
        }
        activeSource = nil
        throw MarketError.decode
    }

    private func fetchQuotes(_ source: Source, _ symbols: [String]) async -> [Quote]? {
        switch source {
        case .binance: return await binanceQuotes(symbols)
        case .okx:     return await okxQuotes(symbols)
        }
    }

    // MARK: - K线

    func klines(symbol: String, count: Int = 60) async throws -> [KLine] {
        if let s = activeSource, let list = await fetchKlines(s, symbol, count), !list.isEmpty {
            return list
        }
        for s in [Source.binance, .okx] {
            if let list = await fetchKlines(s, symbol, count), !list.isEmpty {
                activeSource = s
                return list
            }
        }
        throw MarketError.decode
    }

    private func fetchKlines(_ source: Source, _ symbol: String, _ count: Int) async -> [KLine]? {
        switch source {
        case .binance: return await binanceKlines(symbol, count)
        case .okx:     return await okxKlines(symbol, count)
        }
    }

    // MARK: - 币安

    /// 币安批量行情。
    ///
    /// 坑点：这个接口是「全有或全无」—— 只要 `symbols` 里有一个交易对非法或已下架，
    /// 整批返回 400，一个价格都拿不到。所以先整批试，失败就拆成小片分别请求，
    /// 坏掉的那一片不会拖垮其余的币。
    private func binanceQuotes(_ symbols: [String]) async -> [Quote]? {
        if let list = await binanceBatch(symbols), !list.isEmpty { return list }

        // 分片降级：每片 10 个，逐片请求
        var out: [Quote] = []
        for chunk in symbols.chunked(into: 10) {
            if let list = await binanceBatch(chunk) {
                out.append(contentsOf: list)
            }
        }
        return out.isEmpty ? nil : out
    }

    private func binanceBatch(_ symbols: [String]) async -> [Quote]? {
        guard !symbols.isEmpty else { return nil }
        let json = "[" + symbols.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        guard let encoded = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbols=\(encoded)"),
              let (data, _) = try? await session.data(from: url) else { return nil }
        let list = Self.parseBinanceTickers(data)
        return list.isEmpty ? nil : list
    }

    /// 币安日K：[开盘时间, 开, 高, 低, 收, 量, ...]，时间升序
    private func binanceKlines(_ symbol: String, _ count: Int) async -> [KLine]? {
        let urlStr = "https://api.binance.com/api/v3/klines?symbol=\(symbol)&interval=1d&limit=\(count)"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await session.data(from: url) else { return nil }
        let list = Self.parseBinanceKlines(data)
        return list.isEmpty ? nil : list
    }

    static func parseBinanceTickers(_ data: Data) -> [Quote] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        var out: [Quote] = []
        for row in arr {
            guard let sym = row["symbol"] as? String else { continue }
            func num(_ key: String) -> Double { Double("\(row[key] ?? "")") ?? 0 }

            let last = num("lastPrice")
            guard last > 0 else { continue }

            let code = "cb" + sym
            out.append(Quote(
                code: code,
                name: CryptoCoin.displayName(code),
                price: last * FX.usdtToCNY,
                prevClose: num("prevClosePrice") * FX.usdtToCNY,
                open: num("openPrice") * FX.usdtToCNY,
                high: num("highPrice") * FX.usdtToCNY,
                low: num("lowPrice") * FX.usdtToCNY,
                change: num("priceChange") * FX.usdtToCNY,
                changePercent: num("priceChangePercent"),
                time: Self.stamp()
            ))
        }
        return out
    }

    static func parseBinanceKlines(_ data: Data) -> [KLine] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
        var out: [KLine] = []
        for row in arr {
            guard row.count >= 6,
                  let ts = Double("\(row[0])"),
                  let open = Double("\(row[1])"),
                  let high = Double("\(row[2])"),
                  let low = Double("\(row[3])"),
                  let close = Double("\(row[4])"),
                  let vol = Double("\(row[5])") else { continue }
            out.append(KLine(
                date: Self.dayString(ms: ts),
                open: open * FX.usdtToCNY,
                close: close * FX.usdtToCNY,
                high: high * FX.usdtToCNY,
                low: low * FX.usdtToCNY,
                volume: vol
            ))
        }
        return out
    }

    // MARK: - OKX（降级源）

    /// OKX 没有批量报价接口，但有全量 SPOT 接口，一次取回自己筛
    private func okxQuotes(_ symbols: [String]) async -> [Quote]? {
        guard let url = URL(string: "https://www.okx.com/api/v5/market/tickers?instType=SPOT"),
              let (data, _) = try? await session.data(from: url) else { return nil }
        let list = Self.parseOKXTickers(data, symbols: symbols)
        return list.isEmpty ? nil : list
    }

    /// OKX 日K：`[ts, o, h, l, c, vol, ...]`，注意是**倒序**（最新在前）
    private func okxKlines(_ symbol: String, _ count: Int) async -> [KLine]? {
        let inst = Self.okxId(symbol)
        let urlStr = "https://www.okx.com/api/v5/market/candles?instId=\(inst)&bar=1D&limit=\(count)"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await session.data(from: url) else { return nil }
        let list = Self.parseOKXKlines(data)
        return list.isEmpty ? nil : list
    }

    /// BTCUSDT -> BTC-USDT
    static func okxId(_ symbol: String) -> String {
        guard symbol.uppercased().hasSuffix("USDT") else { return symbol }
        return String(symbol.dropLast(4)) + "-USDT"
    }

    static func parseOKXTickers(_ data: Data, symbols: [String]) -> [Quote] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["data"] as? [[String: Any]] else { return [] }

        // okx instId -> 我们的 symbol
        var want: [String: String] = [:]
        for s in symbols { want[okxId(s)] = s }

        var out: [Quote] = []
        for row in arr {
            guard let inst = row["instId"] as? String, let sym = want[inst] else { continue }
            func num(_ k: String) -> Double { Double("\(row[k] ?? "")") ?? 0 }

            let last = num("last")
            guard last > 0 else { continue }
            // OKX 不给昨收，用 24h 开盘价代替
            let open = num("open24h")
            let code = "cb" + sym

            out.append(Quote(
                code: code,
                name: CryptoCoin.displayName(code),
                price: last * FX.usdtToCNY,
                prevClose: open * FX.usdtToCNY,
                open: open * FX.usdtToCNY,
                high: num("high24h") * FX.usdtToCNY,
                low: num("low24h") * FX.usdtToCNY,
                change: (last - open) * FX.usdtToCNY,
                changePercent: open > 0 ? (last - open) / open * 100 : 0,
                time: Self.stamp()
            ))
        }
        return out
    }

    static func parseOKXKlines(_ data: Data) -> [KLine] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["data"] as? [[Any]] else { return [] }

        var out: [KLine] = []
        for row in arr {
            guard row.count >= 5,
                  let ts = Double("\(row[0])"),
                  let open = Double("\(row[1])"),
                  let high = Double("\(row[2])"),
                  let low = Double("\(row[3])"),
                  let close = Double("\(row[4])") else { continue }
            let vol = row.count > 5 ? (Double("\(row[5])") ?? 0) : 0
            out.append(KLine(
                date: Self.dayString(ms: ts),
                open: open * FX.usdtToCNY,
                close: close * FX.usdtToCNY,
                high: high * FX.usdtToCNY,
                low: low * FX.usdtToCNY,
                volume: vol
            ))
        }
        // OKX 返回倒序，反转成时间升序，和币安保持一致
        return out.reversed()
    }

    // MARK: - 工具

    private static func dayString(ms: Double) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    private static func stamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: Date())
    }
}

extension Array {
    /// 按固定长度切片。用于把一长串交易对拆成多批请求
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
