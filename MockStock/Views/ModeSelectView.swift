import SwiftUI

extension GameMode {
    var accent: Color {
        switch self {
        case .hard: return .upRed
        case .fromZero: return Color(red: 0.94, green: 0.63, blue: 0.19)
        case .steady: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .easy: return .downGreen
        case .unlimited: return Color(red: 0.66, green: 0.33, blue: 0.97)
        }
    }

    var capitalText: String {
        isUnlimited ? "∞" : Fmt.money(initialCapital)
    }
}

/// 首次启动：选择游戏模式
struct ModeSelectView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var selected: GameMode = .fromZero

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.11),
                         Color(red: 0.14, green: 0.09, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(GameMode.allCases) { mode in
                            modeCard(mode)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                confirmButton
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 8) {
            Text("模拟股神")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.upRed, Color(red: 1.0, green: 0.55, blue: 0.35)],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text("选择你的起始模式")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 44)
        .padding(.bottom, 24)
    }

    // MARK: - 模式卡片

    private func modeCard(_ mode: GameMode) -> some View {
        let isSelected = selected == mode

        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selected = mode }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(mode.accent.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mode.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(mode.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)
                        stars(mode.difficulty)
                    }
                    Text(mode.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(mode.capitalText)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(mode.accent)
                    .monospacedDigit()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? mode.accent : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func stars(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(i < count ? Color(red: 1.0, green: 0.78, blue: 0.25) : Color.white.opacity(0.18))
            }
        }
    }

    // MARK: - 确认

    private var confirmButton: some View {
        Button {
            store.chooseMode(selected)
        } label: {
            Text("以「\(selected.title)」开始")
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selected.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }
}
