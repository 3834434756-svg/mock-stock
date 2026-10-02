import Foundation

/// 持仓
struct Position: Identifiable, Codable, Equatable {
    var code: String
    var name: String
    /// 持股数。股票是整数，加密货币是小数（如 0.0153 BTC）
    var shares: Double
    var costPrice: Double   // 摊薄成本价

    var id: String { code }
    var market: Market { Market(code: code) }

    /// 持仓成本总额
    var cost: Double { costPrice * shares }

    /// 按给定现价计算市值
    func marketValue(price: Double) -> Double { price * shares }

    /// 按给定现价计算浮动盈亏
    func profit(price: Double) -> Double { marketValue(price: price) - cost }

    /// 按给定现价计算盈亏比例（%）
    func profitPercent(price: Double) -> Double {
        guard cost > 0 else { return 0 }
        return profit(price: price) / cost * 100
    }
}
