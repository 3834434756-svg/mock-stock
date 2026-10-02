import SwiftUI
import Charts

/// 收盘价走势图（折线 + 渐变面积）
struct TrendChartView: View {
    let klines: [KLine]
    /// 用于 Y 轴价格格式。加密货币的坐标值是人民币折算价，标签要还原成 USDT
    var code: String = ""

    private var isCrypto: Bool { Market(code: code) == .crypto }

    var body: some View {
        if klines.isEmpty {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .frame(height: 220)
                .overlay(
                    Text("暂无走势数据")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                )
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(klines) { k in
            AreaMark(
                x: .value("日期", k.dateValue),
                y: .value("收盘", k.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [lineColor.opacity(0.32), lineColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("日期", k.dateValue),
                y: .value("收盘", k.close)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    .foregroundStyle(Color.secondary)
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(isCrypto ? Fmt.price(v / FX.usdtToCNY) : Fmt.price(v))
                            .foregroundStyle(Color.secondary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .frame(height: 220)
    }

    private var lineColor: Color {
        guard let first = klines.first, let last = klines.last else { return .upRed }
        return last.close >= first.open ? .upRed : .downGreen
    }

    private var yDomain: ClosedRange<Double> {
        let values = klines.map(\.close)
        guard let mn = values.min(), let mx = values.max(), mx > mn else {
            return 0...1
        }
        let pad = (mx - mn) * 0.12
        return (mn - pad)...(mx + pad)
    }
}
