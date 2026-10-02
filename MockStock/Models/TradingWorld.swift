import Foundation

/// 顶层玩法世界。
///
/// 这是「加一个新模式」，不是替换 —— 现实虚拟盘的全部行为保持不变，
/// 游戏模式是另起一套引擎。两者共用账户结构、交易撮合与界面骨架。
enum TradingWorld: String, Codable, CaseIterable, Identifiable {
    /// 现实虚拟盘：接真实行情，遵守真实开闭市
    case real
    /// 游戏模式：读真实盘后数据作种子，之后本地模拟，永不休市
    case game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .real: return "现实虚拟盘"
        case .game: return "游戏模式"
        }
    }

    /// 卡片副标题
    var tagline: String {
        switch self {
        case .real: return "真实行情 · 真实开闭市"
        case .game: return "真实盘后数据起手 · 之后全靠模拟"
        }
    }

    /// 卡片长描述
    var detail: String {
        switch self {
        case .real:
            return "接腾讯财经实时行情，A股 / 港股 / 美股 / 加密货币全都有。市场休市时价格会停住 —— 这是真实的，也是我们想让你体会的。"
        case .game:
            return "以真实收盘价作起点，之后由本地引擎模拟走势，24 小时永不休市。带杠杆、随机事件、成就与爆仓，纯玩。"
        }
    }

    var symbolName: String {
        switch self {
        case .real: return "building.columns.fill"
        case .game: return "gamecontroller.fill"
        }
    }

    /// 世界主色（放在视图层扩展里更合适，但这里要用于卡片，集中定义）
    var accentName: String {
        switch self {
        case .real: return "real"
        case .game: return "game"
        }
    }
}
