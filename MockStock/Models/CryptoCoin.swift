import Foundation

/// 汇率。加密货币以 USDT 计价，账户以人民币记账，按此固定汇率折算。
///
/// 用固定汇率而不是实时汇率，是为了让「账户总资产」这个数字稳定可预期 ——
/// 否则汇率波动会让盈亏里混进一块跟行情无关的涨跌，新手根本分不清。
enum FX {
    static let usdtToCNY = 7.2
}

/// 加密货币币种（数据源：币安公开行情接口）
struct CryptoCoin: Identifiable, Hashable {
    let symbol: String      // 币安交易对，如 BTCUSDT
    let name: String        // 中文名
    let short: String       // 简称，如 BTC

    var id: String { symbol }

    /// 本 App 内部代码，加 cb 前缀与股票代码区分
    var code: String { "cb" + symbol }
}

extension CryptoCoin {
    /// 支持的币种（按市值大致排序）
    static let all: [CryptoCoin] = [
        CryptoCoin(symbol: "BTCUSDT",  name: "比特币",    short: "BTC"),
        CryptoCoin(symbol: "ETHUSDT",  name: "以太坊",    short: "ETH"),
        CryptoCoin(symbol: "BNBUSDT",  name: "币安币",    short: "BNB"),
        CryptoCoin(symbol: "SOLUSDT",  name: "Solana",   short: "SOL"),
        CryptoCoin(symbol: "XRPUSDT",  name: "瑞波币",    short: "XRP"),
        CryptoCoin(symbol: "DOGEUSDT", name: "狗狗币",    short: "DOGE"),
        CryptoCoin(symbol: "ADAUSDT",  name: "艾达币",    short: "ADA"),
        CryptoCoin(symbol: "AVAXUSDT", name: "雪崩协议",  short: "AVAX"),
        CryptoCoin(symbol: "LINKUSDT", name: "Chainlink", short: "LINK"),
        CryptoCoin(symbol: "DOTUSDT",  name: "波卡",      short: "DOT"),
        CryptoCoin(symbol: "LTCUSDT",  name: "莱特币",    short: "LTC"),
        CryptoCoin(symbol: "TRXUSDT",  name: "波场",      short: "TRX"),
    ]

    static let allCodes: [String] = all.map(\.code)
    static let allSymbols: [String] = all.map(\.symbol)

    static func coin(for code: String) -> CryptoCoin? {
        all.first { $0.code.lowercased() == code.lowercased() }
    }

    /// 由内部代码反查简称：cbBTCUSDT -> BTC
    static func shortName(_ code: String) -> String {
        if let c = coin(for: code) { return c.short }
        // 兜底：剥掉 cb 前缀与 USDT 后缀
        var s = code
        if s.lowercased().hasPrefix("cb") { s = String(s.dropFirst(2)) }
        if s.uppercased().hasSuffix("USDT") { s = String(s.dropLast(4)) }
        return s.uppercased()
    }

    /// 由内部代码反查中文名
    static func displayName(_ code: String) -> String {
        if let c = coin(for: code) { return c.name }
        return shortName(code)
    }
}

extension Quote {
    /// 展示价。库里统一存人民币折算价（记账简单、不出错），
    /// 加密货币展示时再还原成 USDT，跟交易所看到的一致。
    var displayPrice: Double {
        market == .crypto ? price / FX.usdtToCNY : price
    }

    /// 展示用代码。加密货币显示成 `BTC/USDT`，股票就是原代码大写
    var displayCode: String {
        if market == .crypto {
            return CryptoCoin.shortName(code) + "/USDT"
        }
        return code.uppercased()
    }

    /// 列表里的价格文本。只有加密货币带货币符号，股票加符号太挤
    var priceLabel: String {
        market == .crypto ? "$" + Fmt.price(displayPrice) : Fmt.price(price)
    }

    /// 把记账价（人民币）还原成展示价
    func display(_ v: Double) -> Double {
        market == .crypto ? v / FX.usdtToCNY : v
    }

    /// 展示用的涨跌额
    var displayChange: Double { display(change) }

    /// 展示用的今开/昨收/最高/最低
    var displayOpen: Double { display(open) }
    var displayPrevClose: Double { display(prevClose) }
    var displayHigh: Double { display(high) }
    var displayLow: Double { display(low) }
}

extension Position {
    /// 展示用代码。加密货币显示成 `BTC/USDT`，股票是原代码大写
    var displayCode: String {
        market == .crypto ? CryptoCoin.shortName(code) + "/USDT" : code.uppercased()
    }
}

extension TradeRecord {
    var displayCode: String {
        market == .crypto ? CryptoCoin.shortName(code) + "/USDT" : code.uppercased()
    }
}
