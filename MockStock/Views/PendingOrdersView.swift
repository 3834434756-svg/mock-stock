import SwiftUI

/// 我的挂单：预埋单 / 限价单。
///
/// 现实模式的预埋单会在开盘后由 `OrderCenter` 自动撮合；
/// 游戏模式的限价单会在模拟价格触达时成交。
struct PendingOrdersView: View {
    @ObservedObject private var orders = OrderCenter.shared

    var body: some View {
        List {
            if orders.orders.isEmpty {
                Section {
                    Text("还没有挂单。\n在个股详情页点「买入 / 卖出」，选「限价」就能挂一笔；\n现实模式休市时下的市价单也会自动排进这里。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !orders.pending.isEmpty {
                Section("挂单中") {
                    ForEach(orders.pending) { o in
                        row(o)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    orders.cancel(o.id)
                                } label: {
                                    Label("撤销", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }

            if !orders.history.isEmpty {
                Section("历史") {
                    ForEach(orders.history) { o in
                        row(o)
                    }
                }
            }

            if !orders.orders.isEmpty {
                Section {
                    Text("挂单只在本机生效，App 关闭期间不会执行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的挂单")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ o: PendingOrder) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(o.side.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(o.side == .buy ? Color.upRed : Color.downGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(o.name)
                    .font(.system(size: 15, weight: .semibold))

                if o.leverage > 1 {
                    Text("\(Int(o.leverage))x")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.2))
                        .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(o.status.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor(o.status))
            }

            Text("\(Fmt.qty(o.shares, code: o.code)) · \(o.conditionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !o.note.isEmpty {
                Text(o.note)
                    .font(.caption2)
                    .foregroundStyle(o.status == .failed ? Color.upRed : Color.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func statusColor(_ s: OrderStatus) -> Color {
        switch s {
        case .pending: return .orange
        case .filled: return .downGreen
        case .cancelled: return .secondary
        case .failed: return .upRed
        }
    }
}
