import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var market: MarketViewModel

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
            market.startPolling()
        }
    }
}
