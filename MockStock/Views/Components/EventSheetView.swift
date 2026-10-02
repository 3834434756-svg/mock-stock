import SwiftUI

/// 平行宇宙事件弹窗。
///
/// 事件不是纯弹窗 —— 你选的每一项都会真的把冲击打到本地模拟价格上，
/// 所以「追进去」之后 K 线真的会往上走。
struct EventSheetView: View {
    let event: MarketEvent
    let targetName: String

    @ObservedObject private var events = EventCenter.shared
    @State private var chosen: MarketEventOption?
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    banner
                    bodyText

                    if showResult {
                        resultCard
                    } else {
                        optionsList
                    }
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("突发事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") { events.dismissCurrent() }
                        .disabled(!showResult && chosen != nil)
                }
            }
            .interactiveDismissDisabled(!showResult)
            .onDisappear {
                // 被划掉 / 被关闭时确保事件收尾，避免下次刷不出新事件
                if events.active != nil { events.dismissCurrent() }
            }
        }
    }

    // MARK: - 顶部

    private var banner: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(event.mood.color.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: event.icon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(event.mood.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(event.mood.title)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(event.mood.color.opacity(0.18))
                        .foregroundStyle(event.mood.color)
                        .clipShape(Capsule())
                    Text(event.isMarketWide ? "全市场" : targetName)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                Text(event.headline)
                    .font(.system(size: 19, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(event.mood.color.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(event.mood.color.opacity(0.25), lineWidth: 1))
    }

    private var bodyText: some View {
        Text(event.body)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 选项

    private var optionsList: some View {
        VStack(spacing: 10) {
            ForEach(Array(event.options.enumerated()), id: \.element.id) { idx, opt in
                Button {
                    decide(idx, opt)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opt.label)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(opt.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.09), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 结果

    private var resultCard: some View {
        VStack(spacing: 14) {
            Image(systemName: (chosen?.countsAsGood ?? false) ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle((chosen?.countsAsGood ?? false) ? Color.upRed : Color.secondary)

            Text(events.lastResult ?? "已做出选择")
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                events.dismissCurrent()
            } label: {
                Text("继续")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.upRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }

    private func decide(_ idx: Int, _ opt: MarketEventOption) {
        chosen = opt
        events.resolve(optionIndex: idx)
        withAnimation(.easeOut(duration: 0.25)) { showResult = true }
    }
}
