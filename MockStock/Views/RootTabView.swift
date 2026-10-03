import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var market: MarketViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            MarketView()
                .tabItem { Label("行情", systemImage: "chart.line.uptrend.xyaxis") }

            PortfolioView()
                .tabItem { Label("持仓", systemImage: "briefcase.fill") }

            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(.upRed)
        .task {
            await market.load()
            await market.loadPopular()
            await market.loadCrypto()
            market.startPolling()
        }
        .onChange(of: scenePhase) { phase in
            // 回到前台时立刻补一次数据。后台期间 Timer 不走，
            // 不补的话加密货币价格会停在切出去那一刻
            guard phase == .active else { return }
            Task {
                await market.load()
                await market.loadPopular()
                await market.loadCrypto()
            }
        }
    }
}
