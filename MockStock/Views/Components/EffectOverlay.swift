import SwiftUI

/// 爽感特效类型
enum JuiceEffect: Equatable {
    case jackpot        // 暴富：金币雨
    case crash          // 重挫：资产大幅回撤（还没到爆仓）
    case liquidation    // 爆仓：红闪
    case achievement    // 成就：金光
}

/// 全屏特效层。放在根视图上，任何地方都能触发。
struct JuiceOverlay: View {
    let effect: JuiceEffect?
    /// 附带说明，目前只有爆仓用得上
    var caption: String? = nil

    @State private var progress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch effect {
                case .liquidation:
                    liquidation(geo)
                case .crash:
                    crash(geo)
                case .jackpot:
                    jackpot(geo)
                case .achievement:
                    achievement(geo)
                case .none:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onChange(of: effect) { newValue in
            guard newValue != nil else { return }
            progress = 0
            withAnimation(.easeOut(duration: 1.5)) { progress = 1 }
        }
    }

    // MARK: - 暴富

    private func jackpot(_ geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                coin(index: i, size: geo.size)
            }
            Text("暴富！")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.32), .upRed],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .upRed.opacity(0.6), radius: 12)
                .scaleEffect(1 + 0.35 * progress)
                .opacity(progress < 0.75 ? 1 : max(0, (1 - progress) / 0.25))
                .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
        }
    }

    private func coin(index i: Int, size: CGSize) -> some View {
        let x = size.width * (0.08 + 0.84 * pseudo(i))
        let delay = 0.06 * Double(i % 6)
        let p = max(0, min(1, (progress - delay) / max(0.01, 1 - delay)))
        return Image(systemName: "dollarsign.circle.fill")
            .font(.system(size: 20 + CGFloat(i % 4) * 7))
            .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.25))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .position(x: x, y: size.height * (0.98 - 0.8 * p))
            .opacity(1 - p * p)
            .scaleEffect(0.8 + 0.5 * p)
    }

    // MARK: - 重挫
    //
    // 跟爆仓区分开：资产回撤不等于仓位被强平。
    // 之前「卖出杠杆仓位」被误判成爆仓，屏幕上直接打「爆仓」两个字，很吓人。

    private func crash(_ geo: GeometryProxy) -> some View {
        ZStack {
            Color.red
                .opacity(progress < 0.15 ? 0.16 : 0.03)
            HStack(spacing: 7) {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 17, weight: .black))
                Text("资产回撤")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Color.downGreen)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.ultraThinMaterial))
            .scaleEffect(1 + 0.08 * progress)
            .opacity(progress < 0.7 ? 1 : max(0, (1 - progress) / 0.3))
            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
    }

    // MARK: - 爆仓

    private func liquidation(_ geo: GeometryProxy) -> some View {
        ZStack {
            Rectangle()
                .stroke(Color.red, lineWidth: 8)
                .opacity(progress < 0.6 ? 1 : max(0, (1 - progress) / 0.4))
            Color.red
                .opacity(progress < 0.15 ? 0.28 : 0.06)
            VStack(spacing: 6) {
                Image(systemName: "burst.fill")
                    .font(.system(size: 40))
                Text("爆仓")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text(caption ?? "仓位已强制平掉")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .shadow(color: .red.opacity(0.9), radius: 14)
            .scaleEffect(1 + 0.2 * progress)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
    }

    // MARK: - 成就

    private func achievement(_ geo: GeometryProxy) -> some View {
        RadialGradient(colors: [Color.yellow.opacity(0.35), .clear],
                       center: .center, startRadius: 10, endRadius: geo.size.width * 0.9)
            .opacity(progress < 0.5 ? 1 : max(0, (1 - progress) / 0.5))
    }

    /// 稳定的伪随机，保证每次特效形状一致不闪
    private func pseudo(_ i: Int) -> Double {
        let v = sin(Double(i) * 12.9898) * 43758.5453
        return v - v.rounded(.down)
    }
}

/// 挂到根视图上：`content.juice($effect)`
struct JuiceModifier: ViewModifier {
    @Binding var effect: JuiceEffect?
    var caption: String? = nil

    func body(content: Content) -> some View {
        content
            .overlay(JuiceOverlay(effect: effect, caption: caption))
            .onChange(of: effect) { newValue in
                guard newValue != nil else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { effect = nil }
                }
            }
    }
}

extension View {
    func juice(_ effect: Binding<JuiceEffect?>, caption: String? = nil) -> some View {
        modifier(JuiceModifier(effect: effect, caption: caption))
    }
}
