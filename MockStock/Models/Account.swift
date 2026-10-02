import Foundation

/// 账户
struct Account: Codable {
    var mode: GameMode
    var cash: Double
    var positions: [Position]
    var records: [TradeRecord]

    /// 按模式创建新账户
    static func fresh(_ mode: GameMode) -> Account {
        Account(mode: mode, cash: mode.initialCapital, positions: [], records: [])
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

    /// 总资产 = 可用资金 + 持仓市值
    func totalAssets(quotes: [String: Quote]) -> Double {
        cash + positionsValue(quotes: quotes)
    }

    /// 总收益率 %
    func totalReturnPercent(quotes: [String: Quote]) -> Double {
        let base = mode.initialCapital
        guard base > 0 else { return 0 }
        return (totalAssets(quotes: quotes) - base) / base * 100
    }
}
