import Foundation

/// 账户
struct Account: Codable {
    /// 当前玩法世界
    var world: TradingWorld
    var mode: GameMode
    var cash: Double
    var positions: [Position]
    var records: [TradeRecord]

    init(world: TradingWorld = .real,
         mode: GameMode,
         cash: Double,
         positions: [Position],
         records: [TradeRecord]) {
        self.world = world
        self.mode = mode
        self.cash = cash
        self.positions = positions
        self.records = records
    }

    /// 手写解码：`world` 是后加的字段，老存档里没有，兜底成现实世界
    enum CodingKeys: String, CodingKey {
        case world, mode, cash, positions, records
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        world = (try? c.decode(TradingWorld.self, forKey: .world)) ?? .real
        mode = try c.decode(GameMode.self, forKey: .mode)
        cash = try c.decode(Double.self, forKey: .cash)
        positions = try c.decode([Position].self, forKey: .positions)
        records = try c.decode([TradeRecord].self, forKey: .records)
    }

    /// 按模式创建新账户
    static func fresh(world: TradingWorld = .real, _ mode: GameMode) -> Account {
        Account(world: world, mode: mode, cash: mode.initialCapital, positions: [], records: [])
    }

    func position(for code: String) -> Position? {
        positions.first { $0.code == code }
    }

    /// 持仓市值合计
    func positionsValue(quotes: [String: Quote]) -> Double {
        positions.reduce(0) { sum, pos in
            sum + pos.marketValue(price: quotes[pos.code]?.price ?? pos.costPrice)
        }
    }

    /// 持仓市值合计（按纯价格表算，供游戏模式与成就判定使用）
    func positionsValue(prices: [String: Double]) -> Double {
        positions.reduce(0) { sum, pos in
            sum + pos.marketValue(price: prices[pos.code] ?? pos.costPrice)
        }
    }

    /// 总资产 = 可用资金 + 持仓市值
    func totalAssets(quotes: [String: Quote]) -> Double {
        cash + positionsValue(quotes: quotes)
    }

    func totalAssets(prices: [String: Double]) -> Double {
        cash + positionsValue(prices: prices)
    }

    /// 总收益率 %
    func totalReturnPercent(quotes: [String: Quote]) -> Double {
        let base = mode.initialCapital
        guard base > 0 else { return 0 }
        return (totalAssets(quotes: quotes) - base) / base * 100
    }

    func totalReturnPercent(prices: [String: Double]) -> Double {
        let base = mode.initialCapital
        guard base > 0 else { return 0 }
        return (totalAssets(prices: prices) - base) / base * 100
    }

    /// 持仓总占用资金
    var totalCapitalUsed: Double {
        positions.reduce(0) { $0 + $1.capitalUsed }
    }
}
