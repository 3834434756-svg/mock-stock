import SwiftUI

/// 行情列表行（涨红跌绿）
struct QuoteRowView: View {
    let quote: Quote

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(quote.displayCode)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(quote.market.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                Text(quote.priceLabel)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.change(quote.change))
                    .monospacedDigit()

                Text(Fmt.percent(quote.changePercent))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.change(quote.change))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 5)
    }
}
