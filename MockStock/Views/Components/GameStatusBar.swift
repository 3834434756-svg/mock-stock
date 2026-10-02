import SwiftUI

/// 游戏模式顶栏：游戏内天数、运行时长、倍速、召唤事件。
///
/// 现实虚拟盘没有这一条 —— 那边的时间就是真实时间，不需要也不能加速。
struct GameStatusBar: View {
    @ObservedObject private var engine = GameEngine.shared
    @ObservedObject private var events = EventCenter.shared

    @State private var showLog = false

    private let speeds: [Double] = [1, 2, 5]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("游戏内第 \(engine.dayIndex + 1) 天")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text("已运行 \(engine.elapsedText) · 5 分钟 = 1 个交易日")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 4)

                speedPicker

                Button {
                    events.fireNow()
                } label: {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(events.active == nil ? Color(red: 0.98, green: 0.78, blue: 0.24) : Color.secondary)
                }
                .accessibilityLabel("召唤突发事件")

                Button {
                    showLog = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("事件记录")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().opacity(0.4)
        }
        .background(Color(red: 0.10, green: 0.08, blue: 0.14))
        .sheet(isPresented: $showLog) { EventLogView() }
    }

    private var speedPicker: some View {
        HStack(spacing: 2) {
            ForEach(speeds, id: \.self) { s in
                Button {
                    engine.speed = s
                } label: {
                    Text(s == 1 ? "1x" : "\(Int(s))x")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(width: 30, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(abs(engine.speed - s) < 0.01
                                      ? Color(red: 0.66, green: 0.33, blue: 0.97)
                                      : Color.white.opacity(0.07))
                        )
                        .foregroundStyle(abs(engine.speed - s) < 0.01 ? Color.white : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 事件记录
struct EventLogView: View {
    @ObservedObject private var events = EventCenter.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if events.log.isEmpty {
                    Text("还没有发生过事件。行情页右上角的闪电可以主动召唤一次。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events.log) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: entry.good ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(entry.good ? Color.upRed : Color.downGreen)
                                Text(entry.headline)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("你的选择：\(entry.choice)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.date.formatted(date: .numeric, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle("平行宇宙事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
