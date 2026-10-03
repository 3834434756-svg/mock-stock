import SwiftUI

/// 币圈：独立于股票账户的加密货币窗口。
///
/// 与「行情」页的区别在于这里是**交易账户**视角 —— 顶部是 USDT 资产，
/// 下面是持仓和币种行情。计价单位统一是 USDT，不再折人民币。
struct CryptoHubView: View {
    @ObservedObject private var crypto = CryptoStore.shared
    @ObservedObject private var missions = MissionCenter.shared
    @EnvironmentObject private var market: MarketViewModel

    @State private var keyword = ""

    private var account: CryptoAccount { crypto.account }

    var body: some View {
        NavigationStack {
            List {
                assetSection
                actionSection
                if !account.positions.isEmpty { positionSection }
                marketSection
                footnoteSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("币圈")
            .task { await crypto.refreshPrices() }
            .onAppear { crypto.sync(quotes: market.cryptoQuotes) }
            .onChange(of: market.cryptoQuotes) { list in
                // 行情页已经在轮询，这里直接同步，不重复请求接口
                crypto.sync(quotes: list)
            }
            .refreshable {
                await market.loadCrypto()
                crypto.sync(quotes: market.cryptoQuotes)
            }
        }
    }

    // MARK: - 资产总览

    private var assetSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("总资产折合")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(Fmt.u(crypto.totalAssets))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("USDT")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    statCell("可用余额", Fmt.u(account.usdt))
                    statCell("持仓市值", Fmt.u(crypto.positionsValue))
                    statCell("今日盈亏", Fmt.signed(crypto.todayProfit),
                             color: Color.change(crypto.todayProfit))
                }

                if account.lockedReward > 0.01 { unlockBar }
            }
            .padding(.vertical, 4)
        }
    }

    /// 奖励金打码进度。奖励能立刻拿来交易，但要提现就得先打够流水
    private var unlockBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("奖励金 \(Fmt.u(account.lockedReward)) USDT 待解锁")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("还需 \(Fmt.u(account.turnoverToUnlock)) 买卖流水")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .foregroundStyle(.orange)

            ProgressView(value: account.rewardProgress)
                .tint(.orange)

            Text("买入再卖出即可累计流水，买卖各算一次。入金的本金不受限制，随时可提。")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func statCell(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 功能入口

    private var actionSection: some View {
        Section {
            NavigationLink {
                DepositView()
            } label: {
                actionRow("入金", subtitle: "划转资金兑换 USDT",
                          icon: "arrow.down.circle.fill", color: .downGreen)
            }

            NavigationLink {
                WithdrawView()
            } label: {
                actionRow("提现",
                          subtitle: crypto.withdrawable >= CryptoStore.minWithdraw
                              ? "可提 \(Fmt.u(crypto.withdrawable)) USDT"
                              : "USDT 换成人民币到银行卡",
                          icon: "arrow.up.circle.fill", color: .upRed)
            }

            NavigationLink {
                MissionCenterView()
            } label: {
                actionRow("任务中心", subtitle: "做任务领 USDT 奖励",
                          icon: "gift.fill", color: .yellow, badge: missions.claimableCount)
            }

            NavigationLink {
                BankCardView()
            } label: {
                actionRow("实名与银行卡",
                          subtitle: account.bankCard?.shortMasked ?? "未绑定，提现前需完成",
                          icon: "creditcard.fill", color: .blue)
            }
        } header: {
            Text("账户")
        }
    }

    private func actionRow(_ title: String, subtitle: String, icon: String,
                           color: Color, badge: Int = 0) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.upRed))
            }
        }
    }

    // MARK: - 持仓

    private var positionSection: some View {
        Section("我的持仓") {
            ForEach(account.positions) { pos in
                NavigationLink {
                    DetailView(code: pos.code)
                } label: {
                    positionRow(pos)
                }
            }
        }
    }

    private func positionRow(_ pos: CryptoPosition) -> some View {
        let price = crypto.price(of: pos.code)
        let profit = pos.profit(price: price)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pos.short)
                    .font(.system(size: 15, weight: .semibold))
                Text(Fmt.coin(pos.shares, pos.short))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.u(pos.marketValue(price: price)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(Fmt.signed(profit) + "  " + Fmt.percent(pos.profitPercent(price: price)))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.change(profit))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 行情

    private var marketSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("搜索币种（BTC / 以太坊 / SOL…）", text: $keyword)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if market.cryptoQuotes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载行情…")
                    Spacer()
                }
            } else if filtered.isEmpty {
                Text("没有匹配的币种")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { q in
                    NavigationLink {
                        DetailView(code: q.code, seed: q)
                    } label: {
                        CryptoRowView(quote: q)
                    }
                }
            }
        } header: {
            Text("行情 · \(CryptoCoin.all.count) 个币种")
        } footer: {
            Text("行情来自\(CryptoAPI.shared.sourceLabel)公开接口，7×24 小时交易，随时可买卖。")
        }
    }

    private var filtered: [Quote] {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return market.cryptoQuotes }
        let allowed = Set(CryptoCoin.search(kw).map(\.code))
        return market.cryptoQuotes.filter { allowed.contains($0.code) }
    }

    // MARK: - 免责

    private var footnoteSection: some View {
        Section {
            Text("币币账户与股票账户相互独立，资金通过「入金 / 提现」互通。"
                 + "本功能为模拟交易，不涉及任何真实资金。"
                 + "虚拟货币交易在中国大陆不受法律保护，请勿据此进行真实投资。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 币种行情行（USDT 计价）
struct CryptoRowView: View {
    let quote: Quote

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(CryptoCoin.shortName(quote.code))
                    .font(.system(size: 15, weight: .semibold))
                Text(CryptoCoin.displayName(quote.code))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("$" + Fmt.price(quote.displayPrice))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(Fmt.percent(quote.changePercent))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.change(quote.change))
                    .monospacedDigit()
            }
        }
    }
}
