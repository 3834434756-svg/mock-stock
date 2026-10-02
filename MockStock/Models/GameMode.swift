import Foundation

/// 游戏模式 —— 决定初始资金与难度
enum GameMode: String, Codable, CaseIterable, Identifiable {
    case hard       // 困难
    case fromZero   // 从零开始
    case steady     // 稳步前进
    case easy       // 简单
    case unlimited  // 无限资产

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hard: return "困难模式"
        case .fromZero: return "从零开始"
        case .steady: return "稳步前进"
        case .easy: return "简单模式"
        case .unlimited: return "无限资产"
        }
    }

    /// 初始资金。无限模式给一个大数（不用 .infinity，否则 JSON 编码会失败）
    var initialCapital: Double {
        switch self {
        case .hard: return 1_000
        case .fromZero: return 10_000
        case .steady: return 100_000
        case .easy: return 1_000_000
        case .unlimited: return 1_000_000_000
        }
    }

    /// 资金是否无限（买入不做余额校验）
    var isUnlimited: Bool { self == .unlimited }

    var subtitle: String {
        switch self {
        case .hard: return "¥1,000 起步，每一分钱都要算计"
        case .fromZero: return "¥10,000 起步，小资金滚雪球"
        case .steady: return "¥100,000 起步，标准体验"
        case .easy: return "¥1,000,000 起步，容错率高"
        case .unlimited: return "资金无限，随便买，专注练手"
        }
    }

    /// 难度星级 1–5
    var difficulty: Int {
        switch self {
        case .hard: return 5
        case .fromZero: return 4
        case .steady: return 3
        case .easy: return 2
        case .unlimited: return 1
        }
    }

    var symbolName: String {
        switch self {
        case .hard: return "flame.fill"
        case .fromZero: return "leaf.fill"
        case .steady: return "chart.bar.fill"
        case .easy: return "dollarsign.circle.fill"
        case .unlimited: return "infinity"
        }
    }
}
