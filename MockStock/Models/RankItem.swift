import Foundation

/// 排行榜条目（腾讯 A 股榜单接口）
///
/// 接口只支持按 价格 / 成交额 / 成交量 排序，所以拉一批回来由客户端自行排序，
/// 这样才能得到「涨幅榜 / 跌幅榜」。
struct RankItem: Identifiable, Equatable {
    let code: String
    let name: String
    let price: Double
    let changePercent: Double
    /// 成交额，单位「万元」（接口原始单位）
    let turnover: Double

    var id: String { code }
    var market: Market { Market(code: code) }

    /// 成交额，换算成「元」
    var turnoverValue: Double { turnover * 10_000 }
}
