import SwiftUI

@main
struct MockStockApp: App {
    @StateObject private var store = AccountStore.shared
    @StateObject private var market = MarketViewModel()

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
        }
    }
}
