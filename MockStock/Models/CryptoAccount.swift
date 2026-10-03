import Foundation

/// 币币持仓。整个币账户只有一个计价单位：USDT。
struct CryptoPosition: Codable, Identifiable {
    var code: String        // 内部代码，如 cbBTCUSDT
    var name: String        // 中文名
    var short: String       // 简称，如 BTC
    var shares: Double      // 持币数量
    var costPrice: Double   // 成本价（USDT）

    var id: String { code }

    /// 交易对，如 BTC/USDT
    var pair: String { short + "/USDT" }

    /// 成本总额（USDT）
    var cost: Double { costPrice * shares }

    /// 持仓市值（USDT）
    func marketValue(price: Double) -> Double { price * shares }

    /// 浮动盈亏（USDT）
    func profit(price: Double) -> Double { (price - costPrice) * shares }

    /// 盈亏比例 %
    func profitPercent(price: Double) -> Double {
        guard costPrice > 0 else { return 0 }
        return (price - costPrice) / costPrice * 100
    }
}

/// 币币成交记录（USDT 计价）
struct CryptoTradeRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var code: String
    var short: String
    var side: TradeSide
    var price: Double       // 成交价（USDT）
    var shares: Double      // 成交数量
    var fee: Double         // 手续费（USDT）
    var date: Date

    /// 成交额（USDT），不含手续费
    var amount: Double { price * shares }
    var pair: String { short + "/USDT" }
}

/// 币币账户。
///
/// 与人民币股票账户**完全独立**：这里只有一个计价单位 —— USDT，
/// 买卖、盈亏、手续费、任务流水全按 U 计。两个账户之间靠「入金 / 提现」打通。
struct CryptoAccount: Codable {
    /// 可用 USDT
    var usdt: Double = 0
    /// 累计获得的奖励金。奖励到账后可以立刻用于交易，
    /// 但**必须打够流水才能提现** —— 这就是「流水达标才给取钱」的由来
    var rewardTotal: Double = 0
    /// 累计入金（USDT）
    var totalDeposit: Double = 0
    /// 累计提现（USDT）
    var totalWithdraw: Double = 0
    /// 累计交易流水（USDT）。任务进度与奖励解锁都看它
    var turnover: Double = 0
    /// 累计手续费（USDT）
    var totalFee: Double = 0

    /// 实名认证
    var kycDone: Bool = false
    var kycName: String = ""
    var kycIdNo: String = ""

    /// 已绑定的银行卡
    var bankCard: BankCard?

    var positions: [CryptoPosition] = []
    var records: [CryptoTradeRecord] = []
    var withdrawals: [Withdrawal] = []

    /// 打码倍数：每 1 USDT 奖励需要 20 USDT 流水才能解锁提现。
    /// 参照真实交易所的反洗钱规则 —— 白送的体验金不能提了就跑。
    static let rewardMultiple: Double = 20

    /// 已被流水解锁、不再受提现限制的奖励金额
    var rewardUnlocked: Double {
        min(rewardTotal, turnover / Self.rewardMultiple)
    }

    /// 仍被锁定的奖励金
    var lockedReward: Double {
        max(0, rewardTotal - rewardUnlocked)
    }

    /// 可提现金额 = 余额 − 仍被锁定的奖励。
    /// 若奖励已被花掉，余额本来就低于锁定值，这里兜底成 0
    var withdrawable: Double {
        max(0, usdt - lockedReward)
    }

    /// 打码解锁进度 0...1
    var rewardProgress: Double {
        guard rewardTotal > 0 else { return 1 }
        return min(1, rewardUnlocked / rewardTotal)
    }

    /// 还要多少流水才能把奖励全部解锁
    var turnoverToUnlock: Double {
        max(0, rewardTotal * Self.rewardMultiple - turnover)
    }

    func position(for code: String) -> CryptoPosition? {
        positions.first { $0.code == code }
    }

    /// 持仓市值（USDT）
    func positionsValue(prices: [String: Double]) -> Double {
        positions.reduce(0) { $0 + $1.marketValue(price: prices[$1.code] ?? $1.costPrice) }
    }

    /// 持仓浮盈（USDT）
    func positionsProfit(prices: [String: Double]) -> Double {
        positions.reduce(0) { $0 + $1.profit(price: prices[$1.code] ?? $1.costPrice) }
    }

    /// 持仓成本合计（USDT）
    var positionsCost: Double {
        positions.reduce(0) { $0 + $1.cost }
    }

    /// 账户总资产（USDT）= 可用余额 + 持仓市值
    func totalAssets(prices: [String: Double]) -> Double {
        usdt + positionsValue(prices: prices)
    }
}
