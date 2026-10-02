import Foundation

enum MarketError: Error {
    case badURL
    case decode
}

/// 搜索结果
struct SearchResult: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
    var market: Market { Market(code: code) }
}

/// 腾讯财经公开行情接口封装
final class MarketAPI {
    static let shared = MarketAPI()

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 20
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - 实时行情

    /// 批量拉取行情，codes 形如 ["sh600000", "hk00700", "usAAPL"]
    func quotes(codes: [String]) async throws -> [Quote] {
        guard !codes.isEmpty else { return [] }
        let joined = codes.joined(separator: ",")
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(joined)") else {
            throw MarketError.badURL
        }
        var req = URLRequest(url: url)
        req.setValue("https://gu.qq.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await session.data(for: req)
        return Self.parseQuotes(GBK.decode(data))
    }

    /// 解析形如：v_sh600000="1~浦发银行~600000~9.48~9.18~9.22~...";
    static func parseQuotes(_ text: String) -> [Quote] {
        var result: [Quote] = []
        for chunk in text.components(separatedBy: ";") {
            let line = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            guard key.hasPrefix("v_") else { continue }

            let code = String(key.dropFirst(2))
            var payload = String(line[line.index(after: eq)...])
            payload = payload.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r"))
            let f = payload.components(separatedBy: "~")
            guard f.count > 34 else { continue }

            let price = Double(f[3]) ?? 0
            guard price > 0 || (Double(f[4]) ?? 0) > 0 else { continue }

            // A股名称里腾讯会用空格对齐（「五 粮 液」），去掉
            let name = code.lowercased().hasPrefix("sh") || code.lowercased().hasPrefix("sz")
                ? f[1].replacingOccurrences(of: " ", with: "")
                : f[1]

            result.append(Quote(
                code: code,
                name: name,
                price: price,
                prevClose: Double(f[4]) ?? 0,
                open: Double(f[5]) ?? 0,
                high: Double(f[33]) ?? 0,
                low: Double(f[34]) ?? 0,
                change: Double(f[31]) ?? 0,
                changePercent: Double(f[32]) ?? 0,
                time: f[30]
            ))
        }
        return result
    }

    // MARK: - K线

    /// 前复权日K线
    func klines(code: String, count: Int = 60) async throws -> [KLine] {
        let urlStr = "https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?param=\(code),day,,,\(count),qfq"
        guard let url = URL(string: urlStr) else { throw MarketError.badURL }
        let (data, _) = try await session.data(from: url)
        return try Self.parseKlines(data: data, code: code)
    }

    static func parseKlines(data: Data, code: String) throws -> [KLine] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = root["data"] as? [String: Any],
              let node = dataDict[code] as? [String: Any] else {
            throw MarketError.decode
        }
        let arr = (node["qfqday"] as? [[Any]]) ?? (node["day"] as? [[Any]]) ?? []

        var result: [KLine] = []
        for row in arr {
            guard row.count >= 6,
                  let date = row[0] as? String,
                  let open = Double("\(row[1])"),
                  let close = Double("\(row[2])"),
                  let high = Double("\(row[3])"),
                  let low = Double("\(row[4])"),
                  let vol = Double("\(row[5])") else { continue }
            result.append(KLine(date: date, open: open, close: close, high: high, low: low, volume: vol))
        }
        return result
    }

    // MARK: - 搜索

    func search(keyword: String) async throws -> [SearchResult] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://smartbox.gtimg.cn/s3/?q=\(encoded)&t=all") else {
            throw MarketError.badURL
        }
        let (data, _) = try await session.data(from: url)
        return Self.parseSearch(GBK.decode(data), keyword: trimmed)
    }

    /// 解析形如：v_hint="sh~600519~\u8d35\u5dde\u8305\u53f0~gzmt~GP-A^..."
    ///
    /// 这里踩过三个坑，都是实测出来的：
    /// 1. 名字是 `\uXXXX` 字面转义，不是 GBK —— 必须还原，否则界面全是乱码
    /// 2. A股类型是 `GP-A`，港美股是 `GP`，只匹配 `GP` 会把 A股全滤掉
    /// 3. 美股代码必须去掉交易所后缀并大写：`aapl.oq` → `usAAPL`
    ///    （`usAAPL.OQ` 和 `usaapl` 都查不到行情）
    ///
    /// 另外杠杆/做空 ETF 混在股票里，删掉太可惜（用户可能真想找 ETF），
    /// 所以只降权、不剔除。
    static func parseSearch(_ text: String, keyword: String) -> [SearchResult] {
        guard let eq = text.firstIndex(of: "=") else { return [] }
        var payload = String(text[text.index(after: eq)...])
        payload = payload.trimmingCharacters(in: CharacterSet(charactersIn: "\";\r\n "))

        let kw = keyword.lowercased()
        var items: [(result: SearchResult, score: Int)] = []

        for item in payload.components(separatedBy: "^") {
            let f = item.components(separatedBy: "~")
            guard f.count >= 5 else { continue }

            let prefix = f[0].lowercased()
            guard ["sh", "sz", "hk", "us"].contains(prefix) else { continue }

            // GP / GP-A / GP-A-CYB / GP-B 都是股票；ZS 指数；JJ 基金；QZ 权证
            let type = f[4].uppercased()
            guard type.hasPrefix("GP") || type.hasPrefix("ZS") || type.hasPrefix("JJ") else { continue }

            let name = UnicodeEscape.decode(f[2]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            // ADR 与主标的重复
            guard !name.lowercased().contains("adr") else { continue }

            var num = f[1]
            if prefix == "us" {
                if let dot = num.firstIndex(of: ".") { num = String(num[..<dot]) }
                num = num.uppercased()
            } else if prefix == "hk", num.hasPrefix("8") {
                // 港股 8xxxx 是人民币柜台（80700 = 00700），与主标的重复
                continue
            }
            guard !num.isEmpty else { continue }

            let lower = name.lowercased()
            let leveraged = lower.contains("etf") || lower.contains("做多") || lower.contains("做空")
            let isStock = type.hasPrefix("GP")

            // 排序打分：完全同名 > 股票前缀匹配 > 股票 > 指数基金 > 杠杆ETF
            let score: Int
            if lower == kw {
                score = 0
            } else if leveraged {
                score = 4
            } else if isStock && lower.hasPrefix(kw) {
                score = 1
            } else if isStock {
                score = 2
            } else {
                score = 3
            }

            items.append((SearchResult(code: prefix + num, name: name), score))
        }

        // 按分数排，同分保持接口原有顺序
        let ordered = items.enumerated().sorted { a, b in
            if a.element.score != b.element.score { return a.element.score < b.element.score }
            return a.offset < b.offset
        }

        // 同名去重（如 腾讯控股 的港股与 OTC 两条）
        var seen = Set<String>()
        var out: [SearchResult] = []
        for e in ordered where !seen.contains(e.element.result.name) {
            seen.insert(e.element.result.name)
            out.append(e.element.result)
        }
        return out
    }

    // MARK: - 排行榜

    /// A 股排行榜。
    ///
    /// 接口只认 price / turnover / volume 三种排序，拿不到「按涨跌幅排序」，
    /// 所以按成交额拉 100 只回来，由客户端自己排 —— 效果一样，还少一次请求。
    func rankList(count: Int = 100) async throws -> [RankItem] {
        let urlStr = "https://proxy.finance.qq.com/cgi/cgi-bin/rank/hs/getBoardRankList"
            + "?board_code=aStock&sort_type=turnover&direct=down&offset=0&count=\(count)"
        guard let url = URL(string: urlStr) else { throw MarketError.badURL }
        let (data, _) = try await session.data(from: url)
        return try Self.parseRank(data)
    }

    static func parseRank(_ data: Data) throws -> [RankItem] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = root["data"] as? [String: Any],
              let list = d["rank_list"] as? [[String: Any]] else {
            throw MarketError.decode
        }

        var out: [RankItem] = []
        for row in list {
            guard let code = row["code"] as? String,
                  let rawName = row["name"] as? String else { continue }
            out.append(RankItem(
                code: code,
                name: rawName.replacingOccurrences(of: " ", with: ""),
                price: Double("\(row["zxj"] ?? "")") ?? 0,
                changePercent: Double("\(row["zdf"] ?? "")") ?? 0,
                turnover: Double("\(row["turnover"] ?? "")") ?? 0
            ))
        }
        return out
    }
}
