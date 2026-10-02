import SwiftUI
import Charts

/// K 线上的买卖点标记
struct ChartMarker: Identifiable {
    let id = UUID()
    let date: String
    let price: Double
    let side: TradeSide

    var dateValue: Date { KLine.parse(date) }
}

/// 收盘价走势图（折线 + 渐变面积 + 买卖点标记）
struct TrendChartView: View {
    let klines: [KLine]
    /// 用于 Y 轴价格格式。加密货币的坐标值是人民币折算价，标签要还原成 USDT
    var code: String = ""
    /// 买卖点
    var markers: [ChartMarker] = []

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
        Chart {
            ForEach(klines) { k in
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

            ForEach(markers) { m in
                PointMark(
                    x: .value("日期", m.dateValue),
                    y: .value("价格", m.price)
                )
                .foregroundStyle(m.side == .buy ? Color.upRed : Color.downGreen)
                .symbolSize(70)
                .annotation(position: m.side == .buy ? .bottom : .top, spacing: 2) {
                    Text(m.side == .buy ? "B" : "S")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(m.side == .buy ? Color.upRed : Color.downGreen)
                        .clipShape(Capsule())
                }
            }
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
        var values = klines.map(\.close)
        values.append(contentsOf: markers.map(\.price))
        guard let mn = values.min(), let mx = values.max(), mx > mn else {
            return 0...1
        }
        let pad = (mx - mn) * 0.12
        return (mn - pad)...(mx + pad)
    }
}
