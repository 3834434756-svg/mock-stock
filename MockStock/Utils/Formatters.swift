import SwiftUI

/// 数字格式化
enum Fmt {
    static func price(_ v: Double) -> String {
        String(format: "%.2f", v)
    }

    /// 带符号，用于涨跌额
    static func signed(_ v: Double) -> String {
        String(format: "%+.2f", v)
    }

    /// 带符号百分比
    static func percent(_ v: Double) -> String {
        String(format: "%+.2f%%", v)
    }

    /// 金额（千分位）
    static func money(_ v: Double, symbol: String = "¥", unlimited: Bool = false) -> String {
        if unlimited { return "∞" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let s = f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
        return symbol + s
    }

    /// 紧凑金额，如 1.23万 / 4.56亿
    static func compact(_ v: Double) -> String {
        let absV = abs(v)
        if absV >= 100_000_000 {
            return String(format: "%.2f亿", v / 100_000_000)
        }
        if absV >= 10_000 {
            return String(format: "%.2f万", v / 10_000)
        }
        return String(format: "%.2f", v)
    }
}

/// 涨红跌绿（A 股习惯）
extension Color {
    static let upRed = Color(red: 0.90, green: 0.27, blue: 0.27)     // #E64545
    static let downGreen = Color(red: 0.12, green: 0.65, blue: 0.45) // #1EA672

    static func change(_ v: Double) -> Color {
        if v > 0 { return .upRed }
        if v < 0 { return .downGreen }
        return Color.secondary
    }
}
