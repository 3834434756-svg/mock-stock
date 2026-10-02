import SwiftUI

@main
struct MockStockApp: App {
    @StateObject private var store = AccountStore.shared
    @StateObject private var market = MarketViewModel()
    @StateObject private var events = EventCenter.shared
    @StateObject private var achievements = AchievementCenter.shared
    @StateObject private var juice = JuiceCenter.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if store.needsSetup {
                    ModeSelectView()
                } else {
                    RootTabView()
                }
            }
            .environmentObject(store)
            .environmentObject(market)
            .preferredColorScheme(.dark)
            // 全屏爽感特效（金币雨 / 爆仓红闪 / 成就金光）
            .overlay(JuiceOverlay(effect: juice.effect))
            // 成就解锁横幅
            .overlay(alignment: .top) {
                if let a = achievements.toast {
                    AchievementToastView(achievement: a)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { achievements.clearToast() }
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: achievements.toast?.id)
            // 平行宇宙事件
            .sheet(item: $events.active) { evt in
                EventSheetView(event: evt, targetName: events.activeTargetName)
            }
        }
    }
}
