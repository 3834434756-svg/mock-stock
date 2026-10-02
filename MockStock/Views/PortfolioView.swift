import SwiftUI

/// 持仓页：资产总览 + 持仓盈亏 + 最近成交
struct PortfolioView: View {
    @EnvironmentObject private var store: AccountStore
    @StateObject private var vm = PortfolioViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }

                if store.account.positions.isEmpty {
                    Section("持仓") {
                        Text("还没有持仓，去行情页挑一只买入吧")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("持仓") {
                        ForEach(store.account.positions) { pos in
                            positionRow(pos)
                        }
                    }
                }

                if !store.account.records.isEmpty {
                    Section("最近成交") {
                        ForEach(Array(store.account.records.prefix(20))) { r in
                            recordRow(r)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("持仓")
            .refreshable {
                await vm.refresh(positions: store.account.positions)
            }
            .task {
                // 进入页面先拉一次，之后每 15 秒自动刷新浮动盈亏。
                // 视图消失（切 Tab / 返回）时 task 会被自动取消，无需手动停表。
                await vm.refresh(positions: store.account.positions)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    if Task.isCancelled { break }
                    await vm.refresh(positions: store.account.positions)
                }
            }
        }
    }

    // MARK: - 总览

    private var summaryCard: some View {
        let quotes = vm.quotes
        let total = store.account.totalAssets(quotes: quotes)
        let ret = store.account.totalReturnPercent(quotes: quotes)
        let unlimited = store.account.mode.isUnlimited

        return VStack(alignment: .leading, spacing: 14) {
            Text(store.account.mode.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(store.account.mode.accent.opacity(0.2))
                .foregroundStyle(store.account.mode.accent)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 5) {
                Text("总资产")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(unlimited ? "∞" : Fmt.money(total))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                statBlock("可用资金", unlimited ? "∞" : Fmt.compact(store.account.cash))
                statBlock("持仓市值", Fmt.compact(store.account.positionsValue(quotes: quotes)))
                statBlock("总收益", unlimited ? "—" : Fmt.percent(ret), color: Color.change(ret))
            }

            // 数据新鲜度：休市时行情会停在上一交易日，必须让用户看得见
            if let t = vm.latestQuoteTime {
                HStack(spacing: 5) {
                    Image(systemName: vm.allQuotesToday ? "clock" : "exclamationmark.triangle.fill")
                    Text(vm.allQuotesToday ? "行情更新于 \(t)" : "行情停留在 \(t)（非实时）")
                }
                .font(.caption2)
                .foregroundStyle(vm.allQuotesToday ? Color.secondary : Color.orange)
            }
        }
        .padding(.vertical, 8)
    }

    private func statBlock(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 5) {
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

    // MARK: - 持仓行

    private func positionRow(_ pos: Position) -> some View {
        let price = vm.quotes[pos.code]?.price ?? pos.costPrice
        let profit = pos.profit(price: price)
        let pct = pos.profitPercent(price: price)

        return VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(pos.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(pos.code.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.signed(profit))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.change(profit))
                    .monospacedDigit()
            }

            HStack {
                Text("\(pos.shares) 股 · 成本 \(Fmt.price(pos.costPrice))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.percent(pct))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.change(profit))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 成交行

    private func recordRow(_ r: TradeRecord) -> some View {
        HStack(spacing: 10) {
            Text(r.side.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(r.side == .buy ? Color.upRed : Color.downGreen)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(r.name)
                    .font(.system(size: 14, weight: .medium))
                Text(r.date.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(r.amount))
                    .font(.system(size: 14, design: .rounded))
                    .monospacedDigit()
                Text("\(r.shares) 股 @ \(Fmt.price(r.price))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
