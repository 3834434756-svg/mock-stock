import SwiftUI

/// 个股详情：报价 + 走势 + 持仓 + 买卖入口
struct DetailView: View {
    @StateObject private var vm: DetailViewModel
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var market: MarketViewModel
    @State private var tradeSide: TradeSide?

    init(code: String, seed: Quote? = nil) {
        _vm = StateObject(wrappedValue: DetailViewModel(code: code, seed: seed))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                chartCard
                if let pos = store.account.position(for: vm.code) {
                    positionCard(pos)
                }
                disclaimer
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(vm.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if market.isWatched(vm.code) {
                        market.remove(vm.code)
                    } else {
                        market.add(vm.code)
                    }
                } label: {
                    Image(systemName: market.isWatched(vm.code) ? "star.fill" : "star")
                }
                .tint(market.isWatched(vm.code) ? Color.yellow : Color.secondary)
                .accessibilityLabel(market.isWatched(vm.code) ? "移出自选" : "加入自选")
            }
        }
        .task {
            await vm.load()
            // 停在详情页时也保持报价新鲜
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                await vm.refreshQuote()
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(item: $tradeSide) { side in
            TradeSheetView(
                code: vm.code,
                name: vm.quote?.name ?? vm.code,
                price: vm.quote?.price ?? 0,
                side: side
            )
        }
    }

    // MARK: - 报价卡

    private var headerCard: some View {
        VStack(spacing: 14) {
            if let q = vm.quote {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(q.priceLabel)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.change(q.change))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.signed(q.displayChange))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.change(q.change))
                            .monospacedDigit()
                        Text(Fmt.percent(q.changePercent))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.change(q.change))
                            .monospacedDigit()
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    infoCell("今开", Fmt.price(q.displayOpen))
                    infoCell("昨收", Fmt.price(q.displayPrevClose))
                    infoCell("最高", Fmt.price(q.displayHigh))
                    infoCell("最低", Fmt.price(q.displayLow))
                }

                // 休市时数据会停在上一交易日，标出来免得误以为 App 卡住
                if let t = QuoteClock.display(q.time) {
                    HStack(spacing: 5) {
                        Image(systemName: QuoteClock.isToday(q.time) ? "clock" : "exclamationmark.triangle.fill")
                        Text(QuoteClock.isToday(q.time) ? "行情更新于 \(t)" : "行情停留在 \(t)（非实时）")
                    }
                    .font(.caption2)
                    .foregroundStyle(QuoteClock.isToday(q.time) ? Color.secondary : Color.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if vm.isLoading {
                ProgressView().frame(height: 130)
            } else {
                Text(vm.errorText ?? "暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(height: 130)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func infoCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 走势卡

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近 60 日走势")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TrendChartView(klines: vm.klines, code: vm.code)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    // MARK: - 持仓卡

    private func positionCard(_ pos: Position) -> some View {
        let price = vm.quote?.price ?? pos.costPrice
        let profit = pos.profit(price: price)

        return VStack(alignment: .leading, spacing: 12) {
            Text("我的持仓")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                infoCell("持有", Fmt.shares(pos.shares))
                infoCell("成本价", Fmt.marketPrice(pos.costPrice, code: pos.code))
                infoCell("市值", Fmt.compact(pos.marketValue(price: price)))
                statCell("浮动盈亏", Fmt.signed(profit), color: Color.change(profit))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func statCell(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var disclaimer: some View {
        Text(Market(code: vm.code) == .crypto
             ? "模拟交易，非真实成交。虚拟货币交易在中国大陆不受法律保护，本功能仅供学习娱乐。"
             : "模拟交易，非真实成交。数据仅供学习娱乐，不构成投资建议。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    // MARK: - 底部买卖栏

    private var bottomBar: some View {
        let hasPosition = store.account.position(for: vm.code) != nil

        return HStack(spacing: 12) {
            Button {
                tradeSide = .buy
            } label: {
                Text("买入")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.upRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                tradeSide = .sell
            } label: {
                Text("卖出")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasPosition ? Color.downGreen : Color.gray.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!hasPosition)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
