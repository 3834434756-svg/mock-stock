import SwiftUI

/// 行情页：自选（含热门股一键加自选）+ 涨幅榜 / 跌幅榜
struct MarketView: View {
    @EnvironmentObject private var market: MarketViewModel
    @State private var sheet: ActiveSheet?
    @State private var cryptoKeyword = ""
    @State private var tab: MarketTab = .watchlist

    /// 同一个视图上挂两个 `.sheet` 在 iOS 上不可靠，统一用一个枚举驱动
    enum ActiveSheet: String, Identifiable {
        case search, orders
        var id: String { rawValue }
    }

    enum MarketTab: String, CaseIterable, Identifiable {
        case watchlist = "自选"
        case gainers = "涨幅榜"
        case losers = "跌幅榜"
        case crypto = "加密货币"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(MarketTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)

                content
            }
            .navigationTitle("行情")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            sheet = .search
                        } label: {
                            Label("搜索股票", systemImage: "magnifyingglass")
                        }
                        Button {
                            sheet = .orders
                        } label: {
                            Label("我的挂单", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .search: SearchView()
                case .orders: NavigationStack { PendingOrdersView() }
                }
            }
            .task {
                await market.loadPopular()
            }
            .task(id: tab) {
                switch tab {
                case .gainers, .losers:
                    await market.loadRank()
                case .crypto:
                    await market.loadCrypto()
                case .watchlist:
                    break
                }
            }
        }
    }

    /// 自选里出现过、且现在关着门的市场。用来展示 NPC 作息卡
    private var closedMarkets: [Market] {
        guard !market.isGame else { return [] }
        let present = Set(market.sortedQuotes.map(\.market))
        return [Market.aShare, .hk, .us].filter {
            present.contains($0) && !MarketClock.isOpenNow($0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .watchlist:
            watchlistContent
        case .gainers:
            rankContent(mode: .gainers)
        case .losers:
            rankContent(mode: .losers)
        case .crypto:
            cryptoContent
        }
    }

    // MARK: - 加密货币

    private var filteredCrypto: [Quote] {
        guard !cryptoKeyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            return market.cryptoQuotes
        }
        let allowed = Set(CryptoCoin.search(cryptoKeyword).map(\.code))
        return market.cryptoQuotes.filter { allowed.contains($0.code) }
    }

    private var cryptoContent: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.upRed)
                    Text("24 小时交易，没有开盘收盘 —— 随时都能买卖，\(CryptoCoin.all.count) 个币种")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    TextField("搜索币种（BTC / 以太坊 / SOL…）", text: $cryptoKeyword)
                        .font(.system(size: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    if !cryptoKeyword.isEmpty {
                        Button {
                            cryptoKeyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if market.cryptoQuotes.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("加载中…")
                        Spacer()
                    }
                }
            } else if filteredCrypto.isEmpty {
                Section {
                    Text("没有匹配的币种")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("加密货币") {
                    ForEach(filteredCrypto) { q in
                        NavigationLink {
                            DetailView(code: q.code, seed: q)
                        } label: {
                            QuoteRowView(quote: q)
                        }
                        .swipeActions(edge: .trailing) {
                            if market.isWatched(q.code) {
                                Button(role: .destructive) {
                                    market.remove(q.code)
                                } label: {
                                    Label("移除", systemImage: "star.slash")
                                }
                            } else {
                                Button {
                                    market.add(q.code)
                                } label: {
                                    Label("加自选", systemImage: "star")
                                }
                                .tint(.upRed)
                            }
                        }
                    }
                }
            }

            Section {
                Text("行情来自\(CryptoAPI.shared.sourceLabel)公开接口，按 1 USDT ≈ \(Fmt.price(FX.usdtToCNY)) 元折算。"
                     + "虚拟货币交易在中国大陆不受法律保护，本功能仅供学习娱乐，不构成任何投资建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await market.loadCrypto() }
    }

    // MARK: - 自选

    private var watchlistContent: some View {
        List {
            // 休市时，把「市场关门」讲成一幕 NPC 作息，而不是让价格无声地冻住
            if !closedMarkets.isEmpty {
                Section {
                    ForEach(closedMarkets, id: \.self) { m in
                        MarketClosedCard(market: m) { sheet = .orders }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
            }

            if market.isGame {
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                        Text("游戏模式：价格由本地引擎模拟，永不休市。去「我的」看成就。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !market.popularQuotes.isEmpty {
                Section("热门股 · 一键加自选") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(market.popularQuotes) { q in
                                PopularCard(quote: q, watched: market.isWatched(q.code)) {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        market.add(q.code)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if market.sortedQuotes.isEmpty {
                Section("我的自选") {
                    if market.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text(market.lastError ?? "还没有自选股。点上面的热门股「加自选」，或用右上角搜索。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("我的自选") {
                    ForEach(market.sortedQuotes) { q in
                        NavigationLink {
                            DetailView(code: q.code, seed: q)
                        } label: {
                            QuoteRowView(quote: q)
                        }
                    }
                    .onDelete { offsets in
                        market.remove(at: offsets)
                    }
                }
            }

            Section {
                if let t = market.latestWatchTime {
                    HStack(spacing: 5) {
                        Image(systemName: market.watchQuotesToday ? "clock" : "exclamationmark.triangle.fill")
                        Text(market.watchQuotesToday ? "行情更新于 \(t)" : "行情停留在 \(t)（非实时）")
                    }
                    .font(.caption)
                    .foregroundStyle(market.watchQuotesToday ? Color.secondary : Color.orange)
                }
                Text("行情来自腾讯财经公开接口，仅供学习娱乐，不构成投资建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await market.load()
            await market.loadPopular()
        }
    }

    // MARK: - 榜单

    private func rankContent(mode: MarketViewModel.RankMode) -> some View {
        let items = market.ranked(mode)

        return List {
            if items.isEmpty {
                Section {
                    if market.isLoadingRank {
                        HStack {
                            Spacer()
                            ProgressView("加载榜单…")
                            Spacer()
                        }
                    } else {
                        Text("榜单加载失败，下拉重试")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("A股 · \(mode.title)") {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink {
                            DetailView(code: item.code)
                        } label: {
                            RankRowView(rank: idx + 1, item: item,
                                        watched: market.isWatched(item.code))
                        }
                        .swipeActions(edge: .trailing) {
                            if market.isWatched(item.code) {
                                Button(role: .destructive) {
                                    market.remove(item.code)
                                } label: {
                                    Label("移除", systemImage: "star.slash")
                                }
                            } else {
                                Button {
                                    market.add(item.code)
                                } label: {
                                    Label("加自选", systemImage: "star")
                                }
                                .tint(.upRed)
                            }
                        }
                    }
                }

                Section {
                    Text("榜单为沪深两市成交额前 100 名，左滑可加自选。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await market.loadRank()
        }
    }
}
