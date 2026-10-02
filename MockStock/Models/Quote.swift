import Foundation

/// 所属市场
enum Market {
    case aShare, hk, us, unknown

    init(code: String) {
        let c = code.lowercased()
        if c.hasPrefix("sh") || c.hasPrefix("sz") {
            self = .aShare
        } else if c.hasPrefix("hk") {
            self = .hk
        } else if c.hasPrefix("us") {
            self = .us
        } else {
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .aShare: return "A股"
        case .hk: return "港股"
        case .us: return "美股"
        case .unknown: return "其他"
        }
    }

    var currencySymbol: String {
        switch self {
        case .aShare: return "¥"
        case .hk: return "HK$"
        case .us: return "$"
        case .unknown: return ""
        }
    }

    /// A股按「手」交易（1 手 = 100 股），港股/美股按股
    var lotSize: Int {
        switch self {
        case .aShare: return 100
        default: return 1
        }
    }
}

/// 行情快照
struct Quote: Identifiable, Codable, Equatable {
    let code: String        // 带前缀，如 sh600000
    let name: String
    let price: Double       // 当前价
    let prevClose: Double   // 昨收
    let open: Double        // 今开
    let high: Double
    let low: Double
    let change: Double      // 涨跌额
    let changePercent: Double // 涨跌幅 %
    let time: String

    var id: String { code }
    var market: Market { Market(code: code) }
}
