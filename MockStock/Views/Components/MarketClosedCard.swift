import SwiftUI

/// 休市提示卡 —— 把「市场关门」做成一幕 NPC 作息，而不是一个冷冰冰的报错。
///
/// 每秒重算一次，倒计时是活的。
/// 除了按作息表判断，还会看行情时间戳：节假日交易所不接单但作息表照样显示「交易中」，
/// 这时用时间戳兜底，改成「休市中」。
struct MarketClosedCard: View {
    let market: Market
    /// 该标的的行情时间戳。用于识别节假日（作息表看不出来）
    var quoteTime: String? = nil
    /// 点「挂预埋单」的回调
    var onQueue: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { ctx in
            content(now: ctx.date)
        }
    }

    private func content(now: Date) -> some View {
        let st = MarketClock.status(for: market, now: now)
        let stale = quoteTime.map { !QuoteClock.isToday($0) } ?? false
        let isOpen = st.isOpen && !stale
        let holiday = st.isOpen && stale

        let label = isOpen ? st.label : (holiday ? "休市中" : st.label)
        let npc = isOpen
            ? st.npcLine
            : (holiday
               ? "今天是节假日，\(who)都放假了 —— 交易大厅空无一人，行情停在上一交易日。"
               : st.npcLine)

        let tint: Color = isOpen ? .upRed : .orange

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: isOpen ? "sun.max.fill" : "moon.zzz.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(market.displayName)
                        .font(.system(size: 15, weight: .bold))
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.18))
                        .foregroundStyle(tint)
                        .clipShape(Capsule())
                }

                Text(npc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !isOpen, !holiday, let d = st.nextChange {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("\(st.nextChangeLabel)还有 \(MarketClock.countdown(to: d, from: now))")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                }

                if !isOpen, let onQueue {
                    Button {
                        onQueue()
                    } label: {
                        Label("挂预埋单 · 开盘自动下单", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.22), lineWidth: 1))
    }

    private var who: String {
        switch market {
        case .aShare: return "上交所和深交所的交易员们"
        case .hk:     return "中环的交易员们"
        case .us:     return "华尔街的交易员们"
        default:      return "交易员们"
        }
    }
}
