import Foundation

/// 所属市场
enum Market {
    case aShare, hk, us, crypto, unknown

    init(code: String) {
        let c = code.lowercased()
        // 加密货币代码形如 cbBTCUSDT（cb = crypto/binance），前缀不与股票冲突
        if c.hasPrefix("cb") {
            self = .crypto
        } else if c.hasPrefix("sh") || c.hasPrefix("sz") {
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
        case .crypto: return "加密货币"
        case .unknown: return "其他"
        }
    }

    var currencySymbol: String {
        switch self {
        case .aShare: return "¥"
        case .hk: return "HK$"
        case .us: return "$"
        case .crypto: return "$"
        case .unknown: return ""
        }
    }

    /// A股按「手」交易（1 手 = 100 股），港股/美股按股，加密货币按份额
    var lotSize: Double {
        switch self {
        case .aShare: return 100
        default: return 1
        }
    }

    /// 是否支持小数份额（加密货币可以买 0.001 个）
    var allowsFraction: Bool { self == .crypto }

    /// 是否 24 小时交易（加密货币从不停市）
    var is24x7: Bool { self == .crypto }
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
