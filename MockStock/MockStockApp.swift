import SwiftUI

@main
struct MockStockApp: App {
    @StateObject private var store = AccountStore.shared
    @StateObject private var market = MarketViewModel()
    @StateObject private var events = EventCenter.shared
    @StateObject private var achievements = AchievementCenter.shared
    @StateObject private var missions = MissionCenter.shared
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
            // 全屏爽感特效（金币雨 / 资产回撤 / 爆仓红闪 / 成就金光）
            .overlay(JuiceOverlay(effect: juice.effect, caption: juice.caption))
            // 成就解锁 / 任务奖励横幅
            .overlay(alignment: .top) {
                VStack(spacing: 6) {
                    if let a = achievements.toast {
                        AchievementToastView(achievement: a)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onTapGesture { achievements.clearToast() }
                    }
                    if let m = missions.toast {
                        MissionToastView(mission: m)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onTapGesture { missions.clearToast() }
                    }
                }
                .padding(.top, 6)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: achievements.toast?.id)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: missions.toast?.id)
            // 平行宇宙事件
            .sheet(item: $events.active) { evt in
                EventSheetView(event: evt, targetName: events.activeTargetName)
            }
        }
    }
}
