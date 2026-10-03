import SwiftUI

/// 个股详情：报价 + 走势 + 持仓 + 买卖入口
struct DetailView: View {
    @StateObject private var vm: DetailViewModel
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var market: MarketViewModel
    @ObservedObject private var crypto = CryptoStore.shared
    @State private var sheet: ActiveSheet?

    /// 加密货币走独立的币账户（USDT 计价），股票走人民币账户
    private var isCrypto: Bool { Market(code: vm.code) == .crypto }

    /// 同一个视图上挂两个 `.sheet` 在 iOS 上不可靠，统一用一个枚举驱动
    enum ActiveSheet: Identifiable {
        case trade(TradeSide)
        case cryptoTrade(TradeSide)
        case orders

        var id: String {
            switch self {
            case .trade(let s): return "trade-\(s.rawValue)"
            case .cryptoTrade(let s): return "cryptoTrade-\(s.rawValue)"
            case .orders: return "orders"
            }
        }
    }

    init(code: String, seed: Quote? = nil) {
        _vm = StateObject(wrappedValue: DetailViewModel(code: code, seed: seed))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                closedCard
                chartCard
                positionSection
                disclaimer
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(vm.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if market.isWatched(vm.code) {
                            market.remove(vm.code)
                        } else {
                            market.add(vm.code)
                        }
                    } label: {
                        Label(market.isWatched(vm.code) ? "移出自选" : "加入自选",
                              systemImage: market.isWatched(vm.code) ? "star.slash" : "star")
                    }

                    Button {
                        sheet = .orders
                    } label: {
                        Label("我的挂单", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: market.isWatched(vm.code) ? "star.fill" : "star")
                        .foregroundStyle(market.isWatched(vm.code) ? Color.yellow : Color.secondary)
                }
                .accessibilityLabel("更多")
            }
        }
        .task {
            await vm.load()
            // 停在详情页时也保持报价新鲜
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(vm.pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await vm.refreshQuote()
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(item: $sheet) { item in
            switch item {
            case .trade(let side):
                TradeSheetView(
                    code: vm.code,
                    name: vm.quote?.name ?? vm.code,
                    price: vm.quote?.price ?? 0,
                    side: side
                )
            case .cryptoTrade(let side):
                CryptoTradeSheetView(
                    code: vm.code,
                    name: vm.quote?.name ?? CryptoCoin.displayName(vm.code),
                    short: CryptoCoin.shortName(vm.code),
                    side: side
                )
            case .orders:
                NavigationStack { PendingOrdersView() }
            }
        }
    }

    // MARK: - 休市卡（NPC 作息 + 倒计时 + 预埋单入口）

    @ViewBuilder
    private var closedCard: some View {
        if !vm.isGame, !Market(code: vm.code).is24x7 {
            MarketClosedCard(market: Market(code: vm.code), quoteTime: vm.quote?.time) {
                sheet = .orders
            }
        }
    }

    // MARK: - 报价卡

    private var headerCard: some View {
        VStack(spacing: 14) {
            if let q = vm.quote {
                HStack(spacing: 6) {
                    badge(Market(code: vm.code).displayName, color: .secondary)
                    if vm.isGame {
                        badge("本地模拟", color: Color(red: 0.66, green: 0.33, blue: 0.97))
                    } else if Market(code: vm.code).is24x7 {
                        badge("24 小时交易", color: .upRed)
                    }
                    Spacer()
                }

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

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - 走势卡

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vm.isGame ? "本地模拟走势" : "近 60 日走势")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !vm.markers.isEmpty {
                    HStack(spacing: 8) {
                        legend("B", color: .upRed)
                        legend("S", color: .downGreen)
                    }
                }
            }
            TrendChartView(klines: vm.klines, code: vm.code, markers: vm.markers)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color)
                .clipShape(Capsule())
            Text(text == "B" ? "买入点" : "卖出点")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 持仓卡

    @ViewBuilder
    private var positionSection: some View {
        if isCrypto {
            if let pos = crypto.account.position(for: vm.code) {
                cryptoPositionCard(pos)
            }
        } else if let pos = store.account.position(for: vm.code) {
            positionCard(pos)
        }
    }

    /// 币币持仓卡。全部按 USDT 计，不再折算人民币
    private func cryptoPositionCard(_ pos: CryptoPosition) -> some View {
        let price = crypto.price(of: pos.code)
        let profit = pos.profit(price: price)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("我的持仓")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("USDT 计价")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.downGreen.opacity(0.18))
                    .foregroundStyle(Color.downGreen)
                    .clipShape(Capsule())
                Spacer()
            }

            HStack(spacing: 0) {
                infoCell("持有", Fmt.shares(pos.shares) + " " + pos.short)
                infoCell("成本价", "$" + Fmt.price(pos.costPrice))
                infoCell("市值", Fmt.u(pos.marketValue(price: price)))
                statCell("浮动盈亏", Fmt.signed(profit), color: Color.change(profit))
            }

            HStack(spacing: 0) {
                infoCell("成本合计", Fmt.u(pos.cost) + " USDT")
                infoCell("盈亏比例", Fmt.percent(pos.profitPercent(price: price)))
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func positionCard(_ pos: Position) -> some View {
        let price = vm.quote?.price ?? pos.costPrice
        let profit = pos.profit(price: price)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("我的持仓")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if pos.isLeveraged {
                    Text("\(Int(pos.leverage))x 杠杆")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.2))
                        .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            HStack(spacing: 0) {
                infoCell("持有", Fmt.qty(pos.shares, code: pos.code))
                infoCell("成本价", Fmt.marketPrice(pos.costPrice, code: pos.code))
                // 杠杆仓位显示净值（保证金 + 浮盈），无杠杆时净值就等于市值
                infoCell(pos.isLeveraged ? "净值" : "市值",
                         Fmt.compact(pos.netValue(price: price)))
                statCell("浮动盈亏", Fmt.signed(profit), color: Color.change(profit))
            }

            if pos.isLeveraged {
                HStack(spacing: 0) {
                    infoCell("占用保证金", Fmt.compact(pos.capitalUsed))
                    infoCell("名义规模", Fmt.compact(pos.marketValue(price: price)))
                    Spacer(minLength: 0)
                }
            }

            if pos.isLeveraged, let dist = pos.distanceToLiquidationPercent(price: price) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("强平价 \(Fmt.marketPrice(pos.liquidationPrice, code: pos.code)) · 距离 \(Fmt.price(dist))%")
                        .monospacedDigit()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(dist < 10 ? Color.upRed : Color.orange)
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
        let hasPosition = isCrypto
            ? crypto.account.position(for: vm.code) != nil
            : store.account.position(for: vm.code) != nil

        return HStack(spacing: 12) {
            Button {
                sheet = isCrypto ? .cryptoTrade(.buy) : .trade(.buy)
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
                sheet = isCrypto ? .cryptoTrade(.sell) : .trade(.sell)
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
