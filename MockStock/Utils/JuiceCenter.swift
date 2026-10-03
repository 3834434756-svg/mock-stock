import SwiftUI

/// 全屏爽感特效的中转站。
///
/// 触发点在 `Juice` 里（成交、浮盈、爆仓、成就），展示点在根视图的 `JuiceOverlay` 上。
/// 中间用这个单例把两边接起来 —— 免得让业务代码持有任何视图状态。
@MainActor
final class JuiceCenter: ObservableObject {
    static let shared = JuiceCenter()

    @Published var effect: JuiceEffect?
    /// 特效附带的一行说明，目前只有爆仓用得上（「XXX 已强制平仓」）
    @Published var caption: String?

    /// 特效展示时长
    private let duration: TimeInterval = 1.7

    private init() {}

    func fire(_ e: JuiceEffect, caption: String? = nil) {
        effect = e
        self.caption = caption
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            // 期间如果又触发了新的特效，不要把它清掉
            if effect == e {
                effect = nil
                self.caption = nil
            }
        }
    }

    func clear() {
        effect = nil
        caption = nil
    }
}
