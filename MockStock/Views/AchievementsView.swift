import SwiftUI

/// 成就墙。按世界过滤 —— 杠杆、爆仓这类只有游戏模式能解锁。
struct AchievementsView: View {
    @EnvironmentObject private var store: AccountStore
    @ObservedObject private var center = AchievementCenter.shared

    private var list: [Achievement] { center.list(for: store.account.world) }

    var body: some View {
        List {
            Section {
                progressHeader
            }

            ForEach(AchievementTier.allCases, id: \.self) { tier in
                let items = list.filter { $0.tier == tier }
                if !items.isEmpty {
                    Section(tier.title) {
                        ForEach(items) { a in
                            row(a)
                        }
                    }
                }
            }

            Section {
                Text("成就与账户绑定，重置账户后清空。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressHeader: some View {
        let total = list.count
        let done = list.filter { center.isUnlocked($0.id) }.count
        let ratio = total > 0 ? Double(done) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已解锁")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(done) / \(total)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            ProgressView(value: ratio)
                .tint(.upRed)
        }
        .padding(.vertical, 4)
    }

    private func row(_ a: Achievement) -> some View {
        let unlocked = center.isUnlocked(a.id)
        let hidden = a.secret && !unlocked

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((unlocked ? a.tier.color : Color.white).opacity(unlocked ? 0.18 : 0.06))
                    .frame(width: 42, height: 42)
                Image(systemName: hidden ? "questionmark" : a.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(unlocked ? a.tier.color : Color.white.opacity(0.25))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(hidden ? "？？？" : a.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(unlocked ? Color.primary : Color.secondary)
                Text(hidden ? "隐藏成就" : a.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if unlocked, let date = center.unlocked[a.id] {
                Text(date.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .padding(.vertical, 3)
    }
}
