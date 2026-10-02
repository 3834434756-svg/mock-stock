import Foundation

/// 订单状态
enum OrderStatus: String, Codable {
    case pending    // 挂单中
    case filled     // 已成交
    case cancelled  // 已撤销
    case failed     // 撮合失败（资金不足等）

    var label: String {
        switch self {
        case .pending: return "挂单中"
        case .filled: return "已成交"
        case .cancelled: return "已撤销"
        case .failed: return "已失败"
        }
    }
}

/// 预埋单 / 限价单。
///
/// 两种触发方式：
/// - `limitPrice == nil` → 市价单，现实模式里等开市后立刻执行（这就是「预埋单」）
/// - `limitPrice != nil` → 限价单，价格触达才成交（游戏模式里最好玩）
struct PendingOrder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var code: String
    var name: String
    var side: TradeSide
    var shares: Double
    /// 限价。nil = 市价（开市即成交）
    var limitPrice: Double?
    var leverage: Double = 1
    var createdAt: Date = Date()
    var status: OrderStatus = .pending
    var filledAt: Date?
    var filledPrice: Double?
    /// 失败原因 / 补充说明
    var note: String = ""

    var isLimit: Bool { limitPrice != nil }

    /// 触发条件是否满足
    func shouldFire(price: Double, marketOpen: Bool) -> Bool {
        guard status == .pending else { return false }
        guard let limit = limitPrice else {
            // 市价单：只要市场开着就执行
            return marketOpen
        }
        switch side {
        case .buy:  return price <= limit      // 跌到限价，买入
        case .sell: return price >= limit      // 涨到限价，卖出
        }
    }

    /// 挂单说明，列表里展示
    var conditionText: String {
        if let limit = limitPrice {
            let p = Fmt.marketPrice(limit, code: code)
            return side == .buy ? "价格跌到 \(p) 买入" : "价格涨到 \(p) 卖出"
        }
        return "开市后以市价\(side.label)"
    }
}
