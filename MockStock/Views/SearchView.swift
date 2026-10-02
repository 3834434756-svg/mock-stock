import SwiftUI

/// 搜索并添加自选
struct SearchView: View {
    @EnvironmentObject private var market: MarketViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var results: [SearchResult] = []
    @State private var searching = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if searching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(results) { r in
                    Button {
                        market.add(r.code)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(r.code.uppercased())
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(r.market.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: market.isWatched(r.code) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(market.isWatched(r.code) ? Color.upRed : Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("添加自选")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $keyword, prompt: "输入股票名称或代码")
            .onSubmit(of: .search) { runSearch() }
            .onChange(of: keyword) { newValue in
                if newValue.isEmpty {
                    results = []
                    errorText = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }

        searching = true
        errorText = nil

        Task {
            do {
                let r = try await MarketAPI.shared.search(keyword: kw)
                results = r
                if r.isEmpty { errorText = "没有找到匹配的股票" }
            } catch {
                results = []
                errorText = "搜索失败，请检查网络"
            }
            searching = false
        }
    }
}
