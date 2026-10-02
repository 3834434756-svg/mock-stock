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

            result.append(Quote(
                code: code,
                name: f[1],
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
        return Self.parseSearch(GBK.decode(data))
    }

    /// 解析形如：v_hint="sh~600000~浦发银行~pfyh~GP-A^sz~000001~平安银行~..."
    static func parseSearch(_ text: String) -> [SearchResult] {
        guard let eq = text.firstIndex(of: "=") else { return [] }
        var payload = String(text[text.index(after: eq)...])
        payload = payload.trimmingCharacters(in: CharacterSet(charactersIn: "\";\r\n "))

        var seen = Set<String>()
        var result: [SearchResult] = []
        for item in payload.components(separatedBy: "^") {
            let f = item.components(separatedBy: "~")
            guard f.count >= 3 else { continue }
            let prefix = f[0].lowercased()
            guard ["sh", "sz", "hk", "us"].contains(prefix) else { continue }
            let name = f[2]
            guard !name.isEmpty else { continue }
            let code = prefix + f[1]
            guard !seen.contains(code) else { continue }
            seen.insert(code)
            result.append(SearchResult(code: code, name: name))
        }
        return result
    }
}
