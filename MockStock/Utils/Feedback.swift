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

    /// 浮盈变化。`ratio` 是总资产相对上一次的变化比例（0.05 = 涨 5%）
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

    /// 浮亏变化。`ratio` 是总资产相对上一次的变化比例（-0.05 = 跌 5%）
    ///
    /// 这里**不打爆仓特效**。资产回撤和「仓位被强平」是两回事，
    /// 混在一起会让用户以为自己的仓位没了 —— 真爆仓走 `liquidation()`。
    static func loss(ratio: Double) {
        if ratio <= -0.5 {
            Haptic.error()
            SoundKit.shared.liquidation()
            JuiceCenter.shared.fire(.crash)
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

    /// 爆仓。只有**仓位真的被强制平掉**时才调用
    static func liquidation(detail: String? = nil) {
        Haptic.error()
        SoundKit.shared.liquidation()
        JuiceCenter.shared.fire(.liquidation, caption: detail)
    }

    /// 突发事件
    static func event() {
        Haptic.heavy()
        SoundKit.shared.alert()
    }
}
