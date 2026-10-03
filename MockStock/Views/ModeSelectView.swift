import SwiftUI

extension GameMode {
    var accent: Color {
        switch self {
        case .hard: return .upRed
        case .fromZero: return Color(red: 0.94, green: 0.63, blue: 0.19)
        case .steady: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .easy: return .downGreen
        case .mega: return Color(red: 0.85, green: 0.66, blue: 0.18)
        case .unlimited: return Color(red: 0.66, green: 0.33, blue: 0.97)
        }
    }

    var capitalText: String {
        if isUnlimited { return "∞" }
        // 50 亿这个量级写成「¥50亿」更好读，也不至于把卡片撑破
        if initialCapital >= 100_000_000 {
            let yi = initialCapital / 100_000_000
            return yi == yi.rounded() ? "¥\(Int(yi))亿" : "¥\(String(format: "%.2f", yi))亿"
        }
        return Fmt.money(initialCapital)
    }
}

extension TradingWorld {
    var accent: Color {
        switch self {
        case .real: return Color(red: 0.23, green: 0.55, blue: 0.98)
        case .game: return Color(red: 0.66, green: 0.33, blue: 0.97)
        }
    }
}

/// 首次启动 / 重置后：先选世界，再选起始资金。
///
/// 两个世界是**并存**的两套玩法，不是新旧替换：
/// - 现实虚拟盘：接真实行情、遵守真实开闭市，适合认真练手
/// - 游戏模式：真实盘后数据起手，之后本地模拟，带杠杆 / 事件 / 成就
struct ModeSelectView: View {
    @EnvironmentObject private var store: AccountStore

    @State private var world: TradingWorld = .real
    @State private var mode: GameMode = .fromZero

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.11),
                         Color(red: 0.13, green: 0.09, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        worldSection
                        modeSection
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
            Text("先挑一个玩法世界")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    private func stepTitle(_ index: Int, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 第一步：世界

    private var worldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(1, "选择玩法世界")

            ForEach(TradingWorld.allCases) { w in
                worldCard(w)
            }
        }
    }

    private func worldCard(_ w: TradingWorld) -> some View {
        let isSelected = world == w

        return Button {
            withAnimation(.easeOut(duration: 0.18)) { world = w }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(w.accent.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: w.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(w.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(w.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)
                        if w == .real {
                            Text("拟真")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.10))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(w.tagline)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(w.accent)
                    Text(w.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? w.accent : Color.white.opacity(0.18))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(isSelected ? 0.09 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? w.accent : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 第二步：资金

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(2, "选择起始资金")

            VStack(spacing: 10) {
                ForEach(GameMode.allCases) { m in
                    modeCard(m)
                }
            }
        }
    }

    private func modeCard(_ m: GameMode) -> some View {
        let isSelected = mode == m

        return Button {
            withAnimation(.easeOut(duration: 0.18)) { mode = m }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(m.accent.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: m.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(m.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(m.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                        stars(m.difficulty)
                    }
                    Text(m.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(m.capitalText)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(m.accent)
                    .monospacedDigit()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.09 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? m.accent : Color.white.opacity(0.07),
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
        VStack(spacing: 8) {
            Text("进入「\(world.title) · \(mode.title)」")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                store.choose(world: world, mode: mode)
            } label: {
                Text("开始")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [world.accent, mode.accent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 10)
        .background(.ultraThinMaterial)
    }
}
