import SwiftUI

/// 数字格式化
enum Fmt {
    /// 价格。按量级自适应精度 —— 股票基本都在 1 以上，仍是两位小数；
    /// 加密货币可能是 0.00001234，固定两位会显示成 0.00
    static func price(_ v: Double) -> String {
        switch abs(v) {
        case 1...:           return String(format: "%.2f", v)
        case 0.1..<1:        return String(format: "%.3f", v)
        case 0.01..<0.1:     return String(format: "%.4f", v)
        case 0.0001..<0.01:  return String(format: "%.5f", v)
        default:             return String(format: "%.8f", v)
        }
    }

    /// 价格 + 该市场的货币符号，如 `$85800.02`
    static func priceText(_ v: Double, code: String) -> String {
        Market(code: code).currencySymbol + price(v)
    }

    /// 按市场展示价格。传入的是记账价（人民币），加密货币还原成 USDT；
    /// 股票不加符号，保持列表原有的清爽观感
    static func marketPrice(_ v: Double, code: String) -> String {
        if Market(code: code) == .crypto {
            return "$" + price(v / FX.usdtToCNY)
        }
        return price(v)
    }

    /// 数量。整数显示为整数，小数去掉尾部零（加密货币用）
    static func shares(_ v: Double) -> String {
        if abs(v - v.rounded()) < 1e-9 { return String(format: "%.0f", v) }
        var s = String(format: "%.8f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// 数量 + 单位，如 `100 股` / `0.0153 BTC`
    static func qty(_ v: Double, code: String) -> String {
        if Market(code: code) == .crypto {
            return "\(shares(v)) \(CryptoCoin.shortName(code))"
        }
        return "\(shares(v)) 股"
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
