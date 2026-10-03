import SwiftUI

/// 突发事件记录。只有本地模拟盘才有 —— 引擎会随机抛事件，也可以在这里手动来一次。
struct EventLogView: View {
    @ObservedObject private var events = EventCenter.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        events.fireNow()
                    } label: {
                        Label("手动触发一次", systemImage: "bolt.horizontal.circle.fill")
                    }
                } footer: {
                    Text("平时引擎会自己随机抛事件，这里可以立刻来一次。")
                }

                Section {
                    if events.log.isEmpty {
                        Text("还没有发生过事件。")
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
                } header: {
                    Text("历史记录")
                }
            }
            .navigationTitle("突发事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
