import Foundation

/// 行情时间戳工具。
///
/// 腾讯接口三个市场的 `f[30]` 字段格式各不相同（实测）：
/// - A股：`20260930161458`  紧凑 14 位
/// - 港股：`2026/10/02 16:08:10`
/// - 美股：`2026-10-01 16:00:01`
///
/// 抽出数字后位序一致（yyyyMMddHHmmss），所以统一按数字解析，
/// 输出 `MM-dd HH:mm` 给界面展示。
enum QuoteClock {

    /// 解析成 `09-30 16:14`。解析不出返回 nil。
    static func display(_ raw: String) -> String? {
        guard let p = parts(raw) else { return nil }
        return String(format: "%02d-%02d %02d:%02d", p.month, p.day, p.hour, p.minute)
    }

    /// 数据日期是否为今天（按本地时区）。
    ///
    /// 注意：美股时间戳是美东时间，换算到北京时间常落在后一天，
    /// 所以隔夜的美股会被判为「非今天」，这是预期行为 —— 它本来就是隔夜数据。
    static func isToday(_ raw: String) -> Bool {
        guard let p = parts(raw) else { return false }
        let now = Calendar.current.dateComponents([.month, .day], from: Date())
        return now.month == p.month && now.day == p.day
    }

    private static func parts(_ raw: String) -> (month: Int, day: Int, hour: Int, minute: Int)? {
        let digits = raw.filter { $0.isNumber }
        guard digits.count >= 12 else { return nil }
        let s = Array(digits)
        func num(_ lo: Int, _ hi: Int) -> Int? { Int(String(s[lo..<hi])) }
        guard let mo = num(4, 6), let da = num(6, 8),
              let h = num(8, 10), let mi = num(10, 12) else { return nil }
        guard (1...12).contains(mo), (1...31).contains(da), h < 24, mi < 60 else { return nil }
        return (mo, da, h, mi)
    }
}
