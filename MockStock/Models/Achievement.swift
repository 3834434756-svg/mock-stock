import SwiftUI

/// 成就稀有度
enum AchievementTier: String, Codable, CaseIterable {
    case bronze, silver, gold, legendary

    var title: String {
        switch self {
        case .bronze: return "铜"
        case .silver: return "银"
        case .gold: return "金"
        case .legendary: return "传说"
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.72, green: 0.48, blue: 0.30)
        case .silver: return Color(red: 0.72, green: 0.76, blue: 0.82)
        case .gold: return Color(red: 0.98, green: 0.78, blue: 0.24)
        case .legendary: return Color(red: 0.72, green: 0.38, blue: 0.98)
        }
    }

    /// 排序权重，稀有度高的排后面
    var weight: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .legendary: return 3
        }
    }
}

/// 成就定义（静态目录，不持久化）
struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tier: AchievementTier
    /// 隐藏成就：解锁前只显示问号
    let secret: Bool
    /// 适用于哪些世界
    let worlds: Set<TradingWorld>
}

/// 成就目录
enum AchievementCatalog {

    // MARK: - 通用（两个世界都有）

    static let firstBuy = Achievement(
        id: "first_buy", title: "第一桶金", detail: "完成第一笔买入",
        icon: "cart.fill", tier: .bronze, secret: false, worlds: [.real, .game])

    static let firstProfit = Achievement(
        id: "first_profit", title: "开门红", detail: "第一笔卖出是赚钱的",
        icon: "flag.checkered", tier: .bronze, secret: false, worlds: [.real, .game])

    static let hundredTrades = Achievement(
        id: "hundred_trades", title: "交易百次", detail: "累计成交 100 笔",
        icon: "arrow.left.arrow.right", tier: .silver, secret: false, worlds: [.real, .game])

    static let allMarkets = Achievement(
        id: "all_markets", title: "全球玩家", detail: "A股、港股、美股、加密货币都交易过",
        icon: "globe.asia.australia.fill", tier: .gold, secret: false, worlds: [.real, .game])

    static let diversifier = Achievement(
        id: "diversifier", title: "别把鸡蛋放一个篮子", detail: "同时持有 5 只以上标的",
        icon: "square.grid.2x2.fill", tier: .bronze, secret: false, worlds: [.real, .game])

    static let tenBagger = Achievement(
        id: "ten_bagger", title: "十倍股", detail: "单只持仓浮盈超过 1000%",
        icon: "chart.line.flame", tier: .legendary, secret: false, worlds: [.real, .game])

    static let stockGod = Achievement(
        id: "stock_god", title: "股神", detail: "总收益率达到 +100%",
        icon: "crown.fill", tier: .legendary, secret: false, worlds: [.real, .game])

    static let richMan = Achievement(
        id: "rich_man", title: "小目标", detail: "总资产突破 1 亿",
        icon: "banknote.fill", tier: .gold, secret: false, worlds: [.real, .game])

    static let leek = Achievement(
        id: "leek", title: "被割的韭菜", detail: "总资产跌破初始资金的 50%",
        icon: "leaf.fill", tier: .bronze, secret: false, worlds: [.real, .game])

    static let broke = Achievement(
        id: "broke", title: "回到解放前", detail: "总资产跌破初始资金的 10%",
        icon: "arrow.down.to.line", tier: .silver, secret: false, worlds: [.real, .game])

    static let bottomFishing = Achievement(
        id: "bottom_fishing", title: "抄底", detail: "在当日最低点买入",
        icon: "arrow.down.circle.fill", tier: .gold, secret: false, worlds: [.real, .game])

    static let topSell = Achievement(
        id: "top_sell", title: "逃顶", detail: "在当日最高点卖出",
        icon: "arrow.up.circle.fill", tier: .gold, secret: false, worlds: [.real, .game])

    static let cutLoss = Achievement(
        id: "cut_loss", title: "割肉", detail: "亏损超过 20% 时果断卖出",
        icon: "scissors", tier: .bronze, secret: false, worlds: [.real, .game])

    static let diamondHands = Achievement(
        id: "diamond_hands", title: "钻石手", detail: "同一只标的持有超过 30 天",
        icon: "hand.raised.fill", tier: .gold, secret: false, worlds: [.real, .game])

    static let allIn = Achievement(
        id: "all_in", title: "满仓出击", detail: "单一持仓占总资产 95% 以上",
        icon: "flame.fill", tier: .silver, secret: false, worlds: [.real, .game])

    static let cryptoDay = Achievement(
        id: "crypto_day", title: "币圈一日", detail: "交易过加密货币",
        icon: "bitcoinsign.circle.fill", tier: .bronze, secret: false, worlds: [.real, .game])

    // MARK: - 游戏模式专属

    static let leverageNewbie = Achievement(
        id: "leverage_newbie", title: "第一次上杠杆", detail: "用 5 倍以上杠杆开仓",
        icon: "bolt.fill", tier: .bronze, secret: false, worlds: [.game])

    static let savedTheDay = Achievement(
        id: "saved_the_day", title: "力挽狂澜", detail: "在一只腰斩的标的上大举买入，把它拉回 +10%",
        icon: "hands.and.sparkles.fill", tier: .legendary, secret: false, worlds: [.game])

    static let teslaPrivate = Achievement(
        id: "tesla_private", title: "特斯拉私有化", detail: "买下特斯拉 20% 的流通股",
        icon: "car.side.fill", tier: .legendary, secret: false, worlds: [.game])

    static let backToZero = Achievement(
        id: "back_to_zero", title: "一夜回到解放前", detail: "用高倍杠杆把自己爆仓归零",
        icon: "burst.fill", tier: .legendary, secret: false, worlds: [.game])

    static let eventSurfer = Achievement(
        id: "event_surfer", title: "见风使舵", detail: "连续 5 次在突发事件里做出正确决策",
        icon: "wind", tier: .gold, secret: false, worlds: [.game])

    static let whale = Achievement(
        id: "whale", title: "庄家本庄", detail: "单笔买入金额超过 10 亿",
        icon: "fish.fill", tier: .gold, secret: false, worlds: [.game])

    static let limitOrderWin = Achievement(
        id: "limit_order_win", title: "埋伏成功", detail: "限价单自动成交并盈利",
        icon: "target", tier: .silver, secret: false, worlds: [.game])

    static let moonShot = Achievement(
        id: "moon_shot", title: "起飞", detail: "单日总资产增长超过 50%",
        icon: "paperplane.fill", tier: .gold, secret: false, worlds: [.game])

    static let everything = Achievement(
        id: "everything", title: "我全都要", detail: "解锁 20 个成就",
        icon: "trophy.fill", tier: .legendary, secret: true, worlds: [.real, .game])

    /// 全部成就
    static let all: [Achievement] = [
        firstBuy, firstProfit, hundredTrades, allMarkets, diversifier,
        tenBagger, stockGod, richMan, leek, broke,
        bottomFishing, topSell, cutLoss, diamondHands, allIn, cryptoDay,
        leverageNewbie, savedTheDay, teslaPrivate, backToZero,
        eventSurfer, whale, limitOrderWin, moonShot, everything,
    ]

    static func find(_ id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    /// 某世界可解锁的成就
    static func forWorld(_ world: TradingWorld) -> [Achievement] {
        all.filter { $0.worlds.contains(world) }
    }
}
