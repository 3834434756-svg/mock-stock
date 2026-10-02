import SwiftUI

/// 热门股卡片：点上半部分进详情，点底部按钮加自选。
///
/// 之所以把「加自选」做成独立按钮而不是整卡点击 —— 整卡既想跳详情又想加自选会打架，
/// 拆成两个明确的可点区域反而更清楚。
struct PopularCard: View {
    let quote: Quote
    let watched: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                DetailView(code: quote.code, seed: quote)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(quote.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(Fmt.price(quote.price))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.change(quote.change))
                        .monospacedDigit()

                    Text(Fmt.percent(quote.changePercent))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.change(quote.change))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onAdd) {
                HStack(spacing: 3) {
                    Image(systemName: watched ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text(watched ? "已自选" : "加自选")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(watched ? Color.white.opacity(0.07) : Color.upRed.opacity(0.16))
                .foregroundStyle(watched ? Color.secondary : Color.upRed)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(watched)
        }
        .padding(11)
        .frame(width: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
