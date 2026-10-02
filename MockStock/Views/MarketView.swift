import SwiftUI

/// 行情页：自选（含热门股一键加自选）+ 涨幅榜 / 跌幅榜
struct MarketView: View {
    @EnvironmentObject private var market: MarketViewModel
    @State private var showSearch = false
    @State private var tab: MarketTab = .watchlist

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
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
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

    private var cryptoContent: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.upRed)
                    Text("24 小时交易，没有开盘收盘 —— 随时都能买卖")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            } else {
                Section("加密货币") {
                    ForEach(market.cryptoQuotes) { q in
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
