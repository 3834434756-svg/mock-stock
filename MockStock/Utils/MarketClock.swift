import Foundation

/// 市场作息表。
///
/// 用北京时间（Asia/Shanghai）计算各市场的开闭市，并给出「下一次开关门」的时间，
/// 界面据此做倒计时。节假日无法预知，所以文案统一用「预计」，
/// 实际是否真的在交易，以行情时间戳为准（`QuoteClock.isToday`）。
enum MarketClock {

    struct Status {
        let isOpen: Bool
        /// 交易中 / 午间休市 / 已收盘 / 周末休市 / 全天交易
        let label: String
        /// NPC 台词，休市时展示
        let npcLine: String
        /// 下一次开/关门时间
        let nextChange: Date?
        /// "开门" 或 "关门"
        let nextChangeLabel: String

        /// 倒计时文案，如「3 小时 12 分」
        var countdown: String {
            guard let d = nextChange else { return "" }
            return MarketClock.countdown(to: d)
        }
    }

    // MARK: - 交易日历

    private static func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }

    /// 各市场的交易时段，单位为「当天 0 点起的分钟数」
    private static func sessions(_ market: Market) -> [(Int, Int)] {
        switch market {
        case .aShare: return [(570, 690), (780, 900)]    // 09:30-11:30, 13:00-15:00
        case .hk:     return [(570, 720), (780, 960)]    // 09:30-12:00, 13:00-16:00
        case .us:     return [(1290, 1440), (0, 240)]    // 21:30-24:00, 00:00-04:00
        default:      return []
        }
    }

    /// 美股凌晨那段（00:00-04:00）属于「前一天」的盘
    private static func effectiveWeekday(_ market: Market, _ weekday: Int, _ minutes: Int) -> Int {
        guard market == .us, minutes < 240 else { return weekday }
        return weekday == 1 ? 7 : weekday - 1
    }

    static func isOpenNow(_ market: Market, at date: Date = Date()) -> Bool {
        if market.is24x7 { return true }
        let c = cal().dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = c.weekday ?? 1
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let wd = effectiveWeekday(market, weekday, minutes)
        if wd == 1 || wd == 7 { return false }
        return sessions(market).contains { minutes >= $0.0 && minutes < $0.1 }
    }

    // MARK: - 状态

    static func status(for market: Market, now: Date = Date()) -> Status {
        if market.is24x7 {
            return Status(
                isOpen: true,
                label: "全天交易",
                npcLine: "加密货币市场从不打烊，矿工和交易员都在线。",
                nextChange: nil,
                nextChangeLabel: ""
            )
        }

        let open = isOpenNow(market, at: now)
        let c = cal().dateComponents([.weekday, .hour, .minute], from: now)
        let weekday = c.weekday ?? 1
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let wd = effectiveWeekday(market, weekday, minutes)
        let weekend = (wd == 1 || wd == 7)

        let label: String
        if open {
            label = "交易中"
        } else if weekend {
            label = "周末休市"
        } else if isLunchBreak(market, minutes) {
            label = "午间休市"
        } else {
            label = "已收盘"
        }

        let next = nextTransition(market, from: now, opening: !open)

        return Status(
            isOpen: open,
            label: label,
            npcLine: npcLine(market: market, label: label, next: next),
            nextChange: next,
            nextChangeLabel: open ? "关门" : "开门"
        )
    }

    private static func isLunchBreak(_ market: Market, _ minutes: Int) -> Bool {
        switch market {
        case .aShare: return minutes >= 690 && minutes < 780
        case .hk:     return minutes >= 720 && minutes < 780
        default:      return false
        }
    }

    /// 从 now 起逐分钟往后找，第一次进入目标状态（开/关）的时间点。
    /// 最多扫 8 天，足够跨过周末。
    private static func nextTransition(_ market: Market, from now: Date, opening: Bool) -> Date? {
        let c = cal()
        guard let start = c.date(bySetting: .second, value: 0, of: now) else { return nil }
        for i in 1...(8 * 24 * 60) {
            guard let t = c.date(byAdding: .minute, value: i, to: start) else { break }
            if isOpenNow(market, at: t) == opening { return t }
        }
        return nil
    }

    private static func npcLine(market: Market, label: String, next: Date?) -> String {
        let who: String
        switch market {
        case .aShare: who = "上交所和深交所的交易员们"
        case .hk:     who = "中环的交易员们"
        case .us:     who = "华尔街的交易员们"
        default:      who = "交易员们"
        }

        switch label {
        case "午间休市":
            return "\(who)去吃午饭了，顺便复盘上午的行情。"
        case "周末休市":
            return "\(who)去度假了，交易大厅的灯还亮着，但没人下单。"
        case "已收盘":
            return "\(who)下班了，屏幕暗下来，键盘声停了。"
        default:
            return "\(who)正在盯着屏幕，报价在跳。"
        }
    }

    /// 倒计时文案
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now)))
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60

        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(mins) 分" }
        if mins > 0 { return "\(mins) 分 \(secs % 60) 秒" }
        return "\(secs) 秒"
    }

    /// 市场所处的作息阶段图标
    static func icon(for market: Market, at date: Date = Date()) -> String {
        if market.is24x7 { return "bolt.fill" }
        let c = cal().dateComponents([.hour], from: date)
        let h = c.hour ?? 12
        if isOpenNow(market, at: date) { return "sun.max.fill" }
        if h >= 22 || h < 6 { return "moon.zzz.fill" }
        return "moon.stars.fill"
    }
}
