import SwiftUI

/// 行情页：自选股列表
struct MarketView: View {
    @EnvironmentObject private var market: MarketViewModel
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            content
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
                .refreshable {
                    await market.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if market.sortedQuotes.isEmpty {
            if market.isLoading {
                ProgressView("加载行情…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        } else {
            quoteList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(market.lastError ?? "自选列表是空的")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("添加自选") { showSearch = true }
                .buttonStyle(.borderedProminent)
                .tint(.upRed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var quoteList: some View {
        List {
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

            Section {
                Text("行情来自腾讯财经公开接口，仅供学习娱乐，不构成投资建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}
