import Foundation

/// 日K线数据点
struct KLine: Identifiable {
    let date: String
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double

    var id: String { date }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()

    var dateValue: Date {
        Self.parse(date)
    }

    /// 把 `yyyy-MM-dd` 解析成 Date（也供买卖点标记复用）
    static func parse(_ s: String) -> Date {
        formatter.date(from: s) ?? Date()
    }

    /// 把 Date 格式化成 `yyyy-MM-dd`
    static func string(_ d: Date) -> String {
        formatter.string(from: d)
    }
}
