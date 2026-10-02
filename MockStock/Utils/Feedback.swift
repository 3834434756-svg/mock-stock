import UIKit

/// 触感反馈
enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// 爽感触发点。把「什么时候该有反馈」集中在一处，
/// 免得散落在各个界面里，调不出统一的节奏。
///
/// 视觉特效只负责转发给 `JuiceCenter`，由根视图统一渲染；
/// 音效与震动在这里直接触发。
/// 全部调用点都在主线程（成交 / 刷新 / 事件），所以整组标成 `@MainActor`。
@MainActor
enum Juice {

    /// 下单成交
    static func trade() {
        Haptic.medium()
        SoundKit.shared.tick()
    }

    /// 浮盈变化。`ratio` 是盈亏相对初始资金的比例
    static func profit(ratio: Double) {
        if ratio >= 0.5 {
            Haptic.success()
            SoundKit.shared.jackpot()
            JuiceCenter.shared.fire(.jackpot)
        } else if ratio >= 0.05 {
            Haptic.light()
            SoundKit.shared.coin()
        }
    }

    /// 浮亏变化
    static func loss(ratio: Double) {
        if ratio <= -0.5 {
            Haptic.error()
            SoundKit.shared.liquidation()
            JuiceCenter.shared.fire(.liquidation)
        } else if ratio <= -0.05 {
            Haptic.warning()
            SoundKit.shared.loss()
        }
    }

    /// 成就解锁
    static func achievement() {
        Haptic.success()
        SoundKit.shared.fanfare()
        JuiceCenter.shared.fire(.achievement)
    }

    /// 爆仓
    static func liquidation() {
        Haptic.error()
        SoundKit.shared.liquidation()
        JuiceCenter.shared.fire(.liquidation)
    }

    /// 突发事件
    static func event() {
        Haptic.heavy()
        SoundKit.shared.alert()
    }
}
