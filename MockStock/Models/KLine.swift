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
        Self.formatter.date(from: date) ?? Date()
    }
}
