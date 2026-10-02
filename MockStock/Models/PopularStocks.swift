import Foundation

/// 精选热门股。
///
/// 存在的意义：只靠搜索的话，用户得先知道股票叫什么才能找到，
/// 等于「没有浏览入口」。这里给一份各市场最具代表性的名单，点一下就能加自选。
enum PopularStocks {
    struct Group: Identifiable {
        let title: String
        let codes: [String]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "A股", codes: [
            "sh600519",   // 贵州茅台
            "sz300750",   // 宁德时代
            "sz000858",   // 五粮液
            "sh601318",   // 中国平安
            "sz002594",   // 比亚迪
            "sh600036",   // 招商银行
            "sh601899",   // 紫金矿业
            "sz000001",   // 平安银行
        ]),
        Group(title: "港股", codes: [
            "hk00700",    // 腾讯控股
            "hk09988",    // 阿里巴巴-W
            "hk03690",    // 美团-W
            "hk01810",    // 小米集团-W
        ]),
        Group(title: "美股", codes: [
            "usAAPL",     // 苹果
            "usTSLA",     // 特斯拉
            "usNVDA",     // 英伟达
            "usMSFT",     // 微软
        ]),
    ]

    static var allCodes: [String] { groups.flatMap(\.codes) }
}
