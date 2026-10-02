import Foundation

enum TradeSide: String, Codable, Identifiable {
    case buy, sell

    var id: String { rawValue }

    var label: String { self == .buy ? "买入" : "卖出" }
}

/// 成交记录
struct TradeRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var code: String
    var name: String
    var side: TradeSide
    var price: Double
    var shares: Int
    var date: Date

    var amount: Double { price * Double(shares) }
    var market: Market { Market(code: code) }
}
