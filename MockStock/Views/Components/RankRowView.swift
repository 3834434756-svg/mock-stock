import SwiftUI

/// 榜单行：排名 + 名称/代码 + 价格 + 涨跌幅
struct RankRowView: View {
    let rank: Int
    let item: RankItem
    let watched: Bool

    var body: some View {
        HStack(spacing: 11) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? Color.upRed : Color.secondary)
                .monospacedDigit()
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if watched {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }
                Text("\(item.code.uppercased()) · 额 \(Fmt.compact(item.turnoverValue))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.price(item.price))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.change(item.changePercent))
                    .monospacedDigit()

                Text(Fmt.percent(item.changePercent))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.change(item.changePercent))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 3)
    }
}
