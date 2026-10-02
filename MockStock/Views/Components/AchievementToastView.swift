import SwiftUI

/// 成就解锁横幅。从顶部滑入，3 秒后自动收起（由 AchievementCenter 控制）。
struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.tier.color.opacity(0.20))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(achievement.tier.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("成就解锁")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(achievement.tier.color)
                    Text(achievement.tier.title)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(achievement.tier.color.opacity(0.18))
                        .foregroundStyle(achievement.tier.color)
                        .clipShape(Capsule())
                }
                Text(achievement.title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.primary)
                Text(achievement.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(achievement.tier.color.opacity(0.5), lineWidth: 1.2)
        )
        .shadow(color: achievement.tier.color.opacity(0.35), radius: 12, y: 4)
        .padding(.horizontal, 14)
    }
}
