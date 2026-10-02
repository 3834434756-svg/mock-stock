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
    /// 支持的币种。
    ///
    /// 名单里的每一个交易对都实际请求过币安接口验证存在 —— 币安的批量行情接口
    /// 只要有一个 symbol 非法就整批返回 400，所以这里宁缺毋滥。
    /// `CryptoAPI` 另外做了分片降级，将来真有币种下架也不会拖垮整批。
    static let all: [CryptoCoin] = [
        // 主流
        CryptoCoin(symbol: "BTCUSDT",    name: "比特币",       short: "BTC"),
        CryptoCoin(symbol: "ETHUSDT",    name: "以太坊",       short: "ETH"),
        CryptoCoin(symbol: "BNBUSDT",    name: "币安币",       short: "BNB"),
        CryptoCoin(symbol: "SOLUSDT",    name: "Solana",      short: "SOL"),
        CryptoCoin(symbol: "XRPUSDT",    name: "瑞波币",       short: "XRP"),
        CryptoCoin(symbol: "DOGEUSDT",   name: "狗狗币",       short: "DOGE"),
        CryptoCoin(symbol: "ADAUSDT",    name: "艾达币",       short: "ADA"),
        CryptoCoin(symbol: "TRXUSDT",    name: "波场",         short: "TRX"),
        CryptoCoin(symbol: "AVAXUSDT",   name: "雪崩协议",     short: "AVAX"),
        CryptoCoin(symbol: "LINKUSDT",   name: "Chainlink",   short: "LINK"),
        CryptoCoin(symbol: "DOTUSDT",    name: "波卡",         short: "DOT"),
        CryptoCoin(symbol: "LTCUSDT",    name: "莱特币",       short: "LTC"),
        CryptoCoin(symbol: "TONUSDT",    name: "Toncoin",     short: "TON"),
        CryptoCoin(symbol: "BCHUSDT",    name: "比特现金",     short: "BCH"),
        CryptoCoin(symbol: "SHIBUSDT",   name: "柴犬币",       short: "SHIB"),
        CryptoCoin(symbol: "PEPEUSDT",   name: "佩佩蛙",       short: "PEPE"),
        // 公链 / 一层网络
        CryptoCoin(symbol: "NEARUSDT",   name: "NEAR 协议",    short: "NEAR"),
        CryptoCoin(symbol: "APTUSDT",    name: "Aptos",       short: "APT"),
        CryptoCoin(symbol: "SUIUSDT",    name: "Sui",         short: "SUI"),
        CryptoCoin(symbol: "ATOMUSDT",   name: "宇宙币",       short: "ATOM"),
        CryptoCoin(symbol: "ETCUSDT",    name: "以太经典",     short: "ETC"),
        CryptoCoin(symbol: "XLMUSDT",    name: "恒星币",       short: "XLM"),
        CryptoCoin(symbol: "ALGOUSDT",   name: "阿尔戈",       short: "ALGO"),
        CryptoCoin(symbol: "ICPUSDT",    name: "互联网计算机", short: "ICP"),
        CryptoCoin(symbol: "HBARUSDT",   name: "哈希图",       short: "HBAR"),
        CryptoCoin(symbol: "STXUSDT",    name: "Stacks",      short: "STX"),
        CryptoCoin(symbol: "SEIUSDT",    name: "Sei",         short: "SEI"),
        CryptoCoin(symbol: "TIAUSDT",    name: "Celestia",    short: "TIA"),
        CryptoCoin(symbol: "FILUSDT",    name: "文件币",       short: "FIL"),
        CryptoCoin(symbol: "MATICUSDT",  name: "Polygon",     short: "MATIC"),
        // 二层 / 基础设施
        CryptoCoin(symbol: "ARBUSDT",    name: "Arbitrum",    short: "ARB"),
        CryptoCoin(symbol: "OPUSDT",     name: "Optimism",    short: "OP"),
        CryptoCoin(symbol: "IMXUSDT",    name: "Immutable",   short: "IMX"),
        CryptoCoin(symbol: "RENDERUSDT", name: "Render",      short: "RENDER"),
        CryptoCoin(symbol: "INJUSDT",    name: "Injective",   short: "INJ"),
        // DeFi / 应用
        CryptoCoin(symbol: "UNIUSDT",    name: "Uniswap",     short: "UNI"),
        CryptoCoin(symbol: "AAVEUSDT",   name: "Aave",        short: "AAVE"),
        CryptoCoin(symbol: "MKRUSDT",    name: "Maker",       short: "MKR"),
        CryptoCoin(symbol: "WLDUSDT",    name: "Worldcoin",   short: "WLD"),
        // 迷因
        CryptoCoin(symbol: "WIFUSDT",    name: "dogwifhat",   short: "WIF"),
        CryptoCoin(symbol: "BONKUSDT",   name: "Bonk",        short: "BONK"),
    ]

    static let allCodes: [String] = all.map(\.code)
    static let allSymbols: [String] = all.map(\.symbol)

    /// 按关键词筛选（中文名 / 简称 / 交易对都能匹配）
    static func search(_ keyword: String) -> [CryptoCoin] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !kw.isEmpty else { return all }
        return all.filter {
            $0.name.uppercased().contains(kw)
                || $0.short.uppercased().contains(kw)
                || $0.symbol.uppercased().contains(kw)
        }
    }

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
