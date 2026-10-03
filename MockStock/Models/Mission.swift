import Foundation

/// 任务分组
enum MissionGroup: String, CaseIterable, Identifiable {
    case newbie   = "新手任务"
    case turnover = "流水任务"
    case daily    = "每日任务"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .newbie:   return "一次性奖励，完成即可领取"
        case .turnover: return "累计交易流水达标，阶梯加码"
        case .daily:    return "每天刷新，隔天可再领一次"
        }
    }

    var symbolName: String {
        switch self {
        case .newbie:   return "gift.fill"
        case .turnover: return "chart.line.uptrend.xyaxis"
        case .daily:    return "calendar"
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .newbie:   return 0xF5C542
        case .turnover: return 0x3B82F6
        case .daily:    return 0x22C55E
        }
    }
}

/// 任务完成条件的判定方式
enum MissionKind: Equatable {
    case register           // 注册账户
    case kyc                // 完成实名认证
    case bankCard           // 绑定银行卡
    case deposit            // 首次入金
    case tradeCount(Int)    // 累计成交笔数
    case turnover(Double)   // 累计交易流水（USDT）
    case holdKinds(Int)     // 同时持有的币种数
    case dailySign          // 每日签到
    case dailyTrade         // 每日完成一笔交易

    /// 是否每日重置
    var isDaily: Bool {
        self == .dailySign || self == .dailyTrade
    }
}

/// 任务定义
struct Mission: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let reward: Double        // 奖励（USDT）
    let icon: String
    let group: MissionGroup
    let kind: MissionKind

    /// 目标值（用于进度条）。`nil` 表示一次性开关型任务
    var target: Double? {
        switch kind {
        case .tradeCount(let n): return Double(n)
        case .turnover(let t):   return t
        case .holdKinds(let n):  return Double(n)
        default:                 return nil
        }
    }

    /// 进度文案，如 `3 / 10 笔`
    var progressUnit: String {
        switch kind {
        case .tradeCount: return "笔"
        case .turnover:   return "USDT"
        case .holdKinds:  return "个币种"
        default:          return ""
        }
    }
}

extension Mission {
    /// 任务表。奖励金额参照真实交易所的新手活动量级 —— 送得起，但都要打码。
    static let all: [Mission] = [
        // MARK: 新手任务
        Mission(id: "register", title: "注册账户", detail: "完成注册，领取新手体验金",
                reward: 10, icon: "person.badge.plus", group: .newbie, kind: .register),
        Mission(id: "kyc", title: "完成实名认证", detail: "上传身份信息，通过后即可解锁提现",
                reward: 20, icon: "checkmark.shield.fill", group: .newbie, kind: .kyc),
        Mission(id: "bank", title: "绑定银行卡", detail: "绑定一张本人银行卡，用于提现到账",
                reward: 15, icon: "creditcard.fill", group: .newbie, kind: .bankCard),
        Mission(id: "deposit", title: "首次入金", detail: "从交易账户划转任意金额兑换 USDT",
                reward: 5, icon: "arrow.down.circle.fill", group: .newbie, kind: .deposit),
        Mission(id: "first_trade", title: "完成首笔交易", detail: "任意币种买入一笔，体验现货交易",
                reward: 5, icon: "bolt.fill", group: .newbie, kind: .tradeCount(1)),
        Mission(id: "hold_5", title: "同时持有 5 个币种", detail: "分散持仓，别把鸡蛋放在一个篮子里",
                reward: 20, icon: "square.grid.2x2.fill", group: .newbie, kind: .holdKinds(5)),
        Mission(id: "trade_10", title: "累计成交 10 笔", detail: "多练手，熟悉下单流程",
                reward: 10, icon: "repeat", group: .newbie, kind: .tradeCount(10)),
        Mission(id: "trade_50", title: "累计成交 50 笔", detail: "交易老手的门槛",
                reward: 30, icon: "flame.fill", group: .newbie, kind: .tradeCount(50)),

        // MARK: 流水任务
        Mission(id: "flow_1k", title: "流水满 1,000 USDT", detail: "累计成交额达标",
                reward: 5, icon: "1.circle.fill", group: .turnover, kind: .turnover(1_000)),
        Mission(id: "flow_10k", title: "流水满 10,000 USDT", detail: "累计成交额达标",
                reward: 20, icon: "2.circle.fill", group: .turnover, kind: .turnover(10_000)),
        Mission(id: "flow_50k", title: "流水满 50,000 USDT", detail: "累计成交额达标",
                reward: 100, icon: "3.circle.fill", group: .turnover, kind: .turnover(50_000)),
        Mission(id: "flow_200k", title: "流水满 200,000 USDT", detail: "累计成交额达标",
                reward: 500, icon: "4.circle.fill", group: .turnover, kind: .turnover(200_000)),
        Mission(id: "flow_1m", title: "流水满 1,000,000 USDT", detail: "累计成交额达标",
                reward: 3_000, icon: "5.circle.fill", group: .turnover, kind: .turnover(1_000_000)),

        // MARK: 每日任务
        Mission(id: "daily_sign", title: "每日签到", detail: "每天来看看行情，顺手签个到",
                reward: 2, icon: "hand.tap.fill", group: .daily, kind: .dailySign),
        Mission(id: "daily_trade", title: "每日完成 1 笔交易", detail: "保持手感",
                reward: 3, icon: "chart.bar.fill", group: .daily, kind: .dailyTrade),
    ]

    /// 取某一组的任务。命名避开实例属性 `group`，免得读代码时看混
    static func list(_ g: MissionGroup) -> [Mission] {
        all.filter { $0.group == g }
    }
}
