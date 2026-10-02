import Foundation

/// 持仓
struct Position: Identifiable, Codable, Equatable {
    var code: String
    var name: String
    /// 持股数。股票是整数，加密货币是小数（如 0.0153 BTC）
    var shares: Double
    var costPrice: Double   // 摊薄成本价
    /// 杠杆倍数。1 = 无杠杆。仅游戏模式可用
    var leverage: Double

    init(code: String, name: String, shares: Double, costPrice: Double, leverage: Double = 1) {
        self.code = code
        self.name = name
        self.shares = shares
        self.costPrice = costPrice
        self.leverage = leverage
    }

    var id: String { code }
    var market: Market { Market(code: code) }

    /// 手写解码：`leverage` 是后加的字段，老存档里没有，
    /// 用 decodeIfPresent 兜底成 1，避免升级后持仓直接解不出来
    enum CodingKeys: String, CodingKey {
        case code, name, shares, costPrice, leverage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        name = try c.decode(String.self, forKey: .name)
        shares = try c.decode(Double.self, forKey: .shares)
        costPrice = try c.decode(Double.self, forKey: .costPrice)
        leverage = (try? c.decode(Double.self, forKey: .leverage)) ?? 1
    }

    // MARK: - 金额

    /// 持仓成本总额（不含杠杆，即名义本金）
    var cost: Double { costPrice * shares }

    /// 实际占用资金。杠杆 1 倍时等于 `cost`
    var capitalUsed: Double { cost / max(1, leverage) }

    var isLeveraged: Bool { leverage > 1.001 }

    /// 按给定现价计算市值
    func marketValue(price: Double) -> Double { price * shares }

    /// 按给定现价计算浮动盈亏（按名义本金算，杠杆放大）
    func profit(price: Double) -> Double { marketValue(price: price) - cost }

    /// 盈亏比例（%），分母是实际占用资金 —— 杠杆会放大这个数字
    func profitPercent(price: Double) -> Double {
        guard capitalUsed > 0 else { return 0 }
        return profit(price: price) / capitalUsed * 100
    }

    /// 当前净值（占用资金 + 浮盈）
    func equity(price: Double) -> Double { capitalUsed + profit(price: price) }

    /// 强平价。价格跌到这里，本金亏光，强制平仓
    var liquidationPrice: Double {
        guard isLeveraged else { return 0 }
        return costPrice * (1 - 1 / leverage)
    }

    /// 是否触及强平
    func isLiquidated(price: Double) -> Bool {
        isLeveraged && price > 0 && price <= liquidationPrice
    }

    /// 距强平还有多少（%）。正数表示安全垫
    func distanceToLiquidationPercent(price: Double) -> Double? {
        guard isLeveraged, price > 0 else { return nil }
        return (price - liquidationPrice) / price * 100
    }
}
