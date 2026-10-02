import SwiftUI

/// 事件氛围
enum EventMood: String {
    case boom       // 利好
    case crash      // 利空
    case chaos      // 混沌（方向不明）
    case neutral

    var title: String {
        switch self {
        case .boom: return "利好"
        case .crash: return "利空"
        case .chaos: return "混沌"
        case .neutral: return "中性"
        }
    }

    var color: Color {
        switch self {
        case .boom: return .upRed
        case .crash: return .downGreen
        case .chaos: return Color(red: 0.98, green: 0.62, blue: 0.16)
        case .neutral: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .boom: return "arrow.up.right.circle.fill"
        case .crash: return "arrow.down.right.circle.fill"
        case .chaos: return "exclamationmark.triangle.fill"
        case .neutral: return "info.circle.fill"
        }
    }
}

/// 玩家在事件里的可选动作
enum EventAction: Equatable {
    case none
    /// 用可用资金的比例市价买入（0.25 = 25% 仓位）
    case buyRatio(Double)
    /// 卖出持仓的比例
    case sellRatio(Double)
    /// 加杠杆买入
    case buyLeveraged(ratio: Double, leverage: Double)
}

/// 事件选项
struct MarketEventOption: Identifiable {
    let id: String
    let label: String
    let detail: String
    /// 对目标价格的冲击（%）。正数拉升，负数砸盘
    let shock: Double
    let action: EventAction
    /// 是否算一次「决策正确」，用于「见风使舵」成就
    let countsAsGood: Bool
}

/// 平行宇宙事件
struct MarketEvent: Identifiable {
    let id: String
    let headline: String
    let body: String
    let icon: String
    let mood: EventMood
    /// 影响标的。nil 表示全市场
    let code: String?
    let options: [MarketEventOption]

    var isMarketWide: Bool { code == nil }
}

/// 事件池。
///
/// 全部是「平行宇宙」版本 —— 借现实世界的梗，但结果由本地引擎决定，
/// 跟真实市场没有任何关系。这样才敢放开手脚做戏剧性。
enum EventPool {

    static func event(for code: String, name: String) -> MarketEvent {
        // 按标的挑一组贴合它身份的事件
        let upper = code.uppercased()
        if upper.contains("TSLA") { return tesla(code: code, name: name) }
        if upper.contains("DOGE") { return doge(code: code, name: name) }
        if upper.contains("BTC") { return btc(code: code, name: name) }
        if code.lowercased().hasPrefix("cb") { return genericCrypto(code: code, name: name) }
        return genericStock(code: code, name: name)
    }

    // MARK: - 个股事件

    private static func tesla(code: String, name: String) -> MarketEvent {
        MarketEvent(
            id: "evt_tesla",
            headline: "马斯克发了一条推文",
            body: "「考虑把 \(name) 私有化，资金已到位。」—— 发完 3 分钟又删了，但市场已经疯了。",
            icon: "car.side.fill",
            mood: .chaos,
            code: code,
            options: [
                MarketEventOption(id: "buy", label: "追进去", detail: "市价买入 30% 仓位，赌他真的私有化",
                                   shock: 6.5, action: .buyRatio(0.30), countsAsGood: true),
                MarketEventOption(id: "lev", label: "上杠杆梭哈", detail: "20 倍杠杆买入 50% 仓位，赢了会所嫩模",
                                   shock: 6.5, action: .buyLeveraged(ratio: 0.50, leverage: 20), countsAsGood: true),
                MarketEventOption(id: "wait", label: "先看看", detail: "按兵不动，观察后续",
                                   shock: 1.2, action: .none, countsAsGood: false),
            ])
    }

    private static func doge(code: String, name: String) -> MarketEvent {
        MarketEvent(
            id: "evt_doge",
            headline: "狗狗币上了电视",
            body: "某位亿万富翁在直播里说「\(name) 是人民的货币」，弹幕刷屏。",
            icon: "hare.fill",
            mood: .boom,
            code: code,
            options: [
                MarketEventOption(id: "buy", label: "冲", detail: "市价买入 40% 仓位",
                                   shock: 18.0, action: .buyRatio(0.40), countsAsGood: true),
                MarketEventOption(id: "lev", label: "100 倍杠杆", detail: "这不是投资，这是买彩票",
                                   shock: 18.0, action: .buyLeveraged(ratio: 0.20, leverage: 100), countsAsGood: false),
                MarketEventOption(id: "skip", label: "不碰", detail: "这种钱不好赚",
                                   shock: 0, action: .none, countsAsGood: false),
            ])
    }

    private static func btc(code: String, name: String) -> MarketEvent {
        MarketEvent(
            id: "evt_btc",
            headline: "某国宣布把比特币列为储备资产",
            body: "消息一出，\(name) 现货被扫货，交易所挂单簿被吃穿。",
            icon: "bitcoinsign.circle.fill",
            mood: .boom,
            code: code,
            options: [
                MarketEventOption(id: "buy", label: "买入", detail: "市价买入 35% 仓位",
                                   shock: 9.5, action: .buyRatio(0.35), countsAsGood: true),
                MarketEventOption(id: "sell", label: "趁高出货", detail: "卖掉一半持仓落袋",
                                   shock: 9.5, action: .sellRatio(0.5), countsAsGood: false),
                MarketEventOption(id: "hold", label: "拿着不动", detail: "长期主义者",
                                   shock: 4.0, action: .none, countsAsGood: false),
            ])
    }

    private static func genericCrypto(code: String, name: String) -> MarketEvent {
        MarketEvent(
            id: "evt_crypto_\(code)",
            headline: "链上出现巨额转账",
            body: "一个沉睡了 8 年的地址突然转出大量 \(name)，市场在猜是巨鲸出货还是交易所补货。",
            icon: "waveform.path.ecg",
            mood: .chaos,
            code: code,
            options: [
                MarketEventOption(id: "buy", label: "抄底", detail: "买入 25% 仓位赌是补货",
                                   shock: 7.0, action: .buyRatio(0.25), countsAsGood: true),
                MarketEventOption(id: "sell", label: "先跑", detail: "卖出一半规避风险",
                                   shock: -6.0, action: .sellRatio(0.5), countsAsGood: true),
                MarketEventOption(id: "hold", label: "装死", detail: "什么都不做",
                                   shock: -2.5, action: .none, countsAsGood: false),
            ])
    }

    private static func genericStock(code: String, name: String) -> MarketEvent {
        MarketEvent(
            id: "evt_stock_\(code)",
            headline: "\(name) 出了个意外公告",
            body: "深夜公告：业绩预告大幅偏离市场预期，同时宣布回购计划。多空双方都找到了理由。",
            icon: "doc.text.fill",
            mood: .chaos,
            code: code,
            options: [
                MarketEventOption(id: "buy", label: "赌利好", detail: "买入 30% 仓位",
                                   shock: 5.5, action: .buyRatio(0.30), countsAsGood: true),
                MarketEventOption(id: "sell", label: "赌利空", detail: "清仓离场",
                                   shock: -5.5, action: .sellRatio(1.0), countsAsGood: false),
                MarketEventOption(id: "hold", label: "看不懂就不动", detail: "保持现状",
                                   shock: 0, action: .none, countsAsGood: false),
            ])
    }

    // MARK: - 全市场事件

    static let marketWide: [MarketEvent] = [
        MarketEvent(
            id: "evt_rate_cut",
            headline: "央行意外降息 50 个基点",
            body: "流动性预期瞬间转向，所有风险资产同时被点燃。",
            icon: "percent",
            mood: .boom,
            code: nil,
            options: [
                MarketEventOption(id: "buy", label: "全面加仓", detail: "买入 40% 仓位",
                                   shock: 3.2, action: .buyRatio(0.40), countsAsGood: true),
                MarketEventOption(id: "hold", label: "按兵不动", detail: "等回调",
                                   shock: 3.2, action: .none, countsAsGood: false),
            ]),

        MarketEvent(
            id: "evt_black_monday",
            headline: "隔夜美股暴跌，恐慌指数飙升",
            body: "亚洲开盘全线低开，程序化卖盘在踩踏。有人在喊「这次不一样」。",
            icon: "bolt.trianglebadge.exclamationmark.fill",
            mood: .crash,
            code: nil,
            options: [
                MarketEventOption(id: "buy", label: "别人恐惧我贪婪", detail: "买入 35% 仓位",
                                   shock: -3.6, action: .buyRatio(0.35), countsAsGood: true),
                MarketEventOption(id: "sell", label: "先保命", detail: "清仓避险",
                                   shock: -3.6, action: .sellRatio(1.0), countsAsGood: true),
                MarketEventOption(id: "hold", label: "关掉软件", detail: "什么都不看",
                                   shock: -3.6, action: .none, countsAsGood: false),
            ]),

        MarketEvent(
            id: "evt_bubble",
            headline: "某大机构发布「泡沫警告」",
            body: "报告长达 200 页，结论只有一句：现在的估值不可持续。市场开始分歧。",
            icon: "exclamationmark.bubble.fill",
            mood: .neutral,
            code: nil,
            options: [
                MarketEventOption(id: "reduce", label: "降一点仓位", detail: "卖出 30%",
                                   shock: -1.4, action: .sellRatio(0.30), countsAsGood: true),
                MarketEventOption(id: "ignore", label: "报告都是马后炮", detail: "继续持有",
                                   shock: 0.8, action: .none, countsAsGood: false),
            ]),

        MarketEvent(
            id: "evt_quant",
            headline: "某个量化基金爆仓了",
            body: "强平盘在短时间内砸出巨量，好几个标的瞬间被打出深坑，随后又被迅速买回。",
            icon: "gearshape.2.fill",
            mood: .chaos,
            code: nil,
            options: [
                MarketEventOption(id: "buy", label: "接飞刀", detail: "买入 25% 仓位",
                                   shock: 2.4, action: .buyRatio(0.25), countsAsGood: true),
                MarketEventOption(id: "wait", label: "等尘埃落定", detail: "观望",
                                   shock: -1.0, action: .none, countsAsGood: false),
            ]),
    ]
}
