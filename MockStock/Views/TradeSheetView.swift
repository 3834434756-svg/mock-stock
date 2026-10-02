import SwiftUI

/// 下单面板。一个入口覆盖四种情形：
/// - 现实模式 · 开市中 → 立即成交
/// - 现实模式 · 休市中 → 自动转成**预埋单**，开盘后由 `OrderCenter` 自动撮合
/// - 游戏模式 · 市价 → 立即成交，可上杠杆
/// - 任意模式 · 限价 → 挂单等价格触达（游戏模式里最好玩）
///
/// 股票按「股」下单（整数），加密货币按「份额」下单（允许小数，如 0.0153 BTC）。
struct TradeSheetView: View {
    let code: String
    let name: String
    /// 人民币折算价。加密货币的报价已乘汇率，记账货币统一是人民币
    let price: Double
    let side: TradeSide

    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var sharesText = ""
    @State private var limitText = ""
    @State private var orderType: OrderType = .market
    @State private var leverage: Double = 1
    @State private var message: String?
    @State private var messageIsError = false

    enum OrderType: String, CaseIterable, Identifiable {
        case market, limit
        var id: String { rawValue }
        var title: String { self == .market ? "市价" : "限价" }
    }

    private let leverages: [Double] = [1, 2, 5, 10, 20, 50, 100]

    private var isCrypto: Bool { Market(code: code) == .crypto }
    private var account: Account { store.account }
    private var isGame: Bool { store.isGame }

    /// 成交数量。股票是整数股，加密货币是小数份额
    private var shares: Double { Double(sharesText) ?? 0 }
    private var amount: Double { price * shares }
    private var heldShares: Double { account.position(for: code)?.shares ?? 0 }

    /// 展示价。加密货币还原成 USDT，跟交易所看到的一致
    private var displayPrice: Double { isCrypto ? price / FX.usdtToCNY : price }

    private var unit: String { isCrypto ? CryptoCoin.shortName(code) : "股" }

    /// 该标的现在能不能立即成交
    private var marketOpen: Bool {
        QuoteProvider.shared.isTrading(code: code, quoteTime: nil)
    }

    /// 市价单是否会变成预埋单
    private var willQueue: Bool { orderType == .limit || !marketOpen }

    /// 杠杆只对游戏模式的买入开放
    private var showsLeverage: Bool { isGame && side == .buy }

    private var maxShares: Double {
        if side == .sell { return heldShares }
        guard price > 0 else { return 0 }
        if account.mode.isUnlimited { return 1_000_000 }
        // 杠杆买入时可用资金可以撬动更多份额
        return account.cash * max(1, leverage) / price
    }

    var body: some View {
        NavigationStack {
            Form {
                quoteSection
                typeSection
                amountSection
                if showsLeverage { leverageSection }
                if willQueue { queueSection }
                if let message { messageSection(message) }
                submitSection
            }
            .navigationTitle(side.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - 行情

    private var quoteSection: some View {
        Section {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text(isCrypto ? CryptoCoin.shortName(code) + "/USDT" : code.uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("现价")
                Spacer()
                Text(isCrypto ? "$" + Fmt.price(displayPrice) : Fmt.money(displayPrice))
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            HStack {
                Text(side == .buy ? "可用资金" : "持仓数量")
                Spacer()
                Text(side == .buy
                     ? Fmt.money(account.cash, unlimited: account.mode.isUnlimited)
                     : Fmt.qty(heldShares, code: code))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 订单类型

    private var typeSection: some View {
        Section {
            Picker("订单类型", selection: $orderType) {
                ForEach(OrderType.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)

            if orderType == .limit {
                HStack {
                    Text(side == .buy ? "买入限价" : "卖出限价")
                    Spacer()
                    TextField(isCrypto ? "USDT" : "元", text: $limitText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .font(.system(.body, design: .rounded))
                }
                Button("用现价填入") {
                    limitText = isCrypto
                        ? Fmt.price(displayPrice)
                        : Fmt.price(price)
                }
                .font(.footnote)
            }
        } footer: {
            Text(orderType == .limit
                 ? (side == .buy ? "价格跌到限价时自动买入。" : "价格涨到限价时自动卖出。")
                 : "以当前价格立即成交。")
        }
    }

    // MARK: - 数量

    private var amountSection: some View {
        Section("数量（\(unit)）") {
            TextField("输入\(unit)数量", text: $sharesText)
                .keyboardType(isCrypto ? .decimalPad : .numberPad)
                .font(.system(.title3, design: .rounded))

            HStack(spacing: 8) {
                quickButton("全仓", ratio: 1.0)
                quickButton("半仓", ratio: 0.5)
                quickButton("1/3", ratio: 1.0 / 3.0)
            }

            HStack {
                Text("预估金额")
                Spacer()
                Text(Fmt.money(amount))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(side == .buy ? Color.upRed : Color.downGreen)
            }

            if isCrypto {
                Text("按 1 USDT ≈ \(Fmt.price(FX.usdtToCNY)) 元折算")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 杠杆（仅游戏模式买入）

    private var leverageSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(leverages, id: \.self) { l in
                        Button {
                            leverage = l
                        } label: {
                            Text(l == 1 ? "无杠杆" : "\(Int(l))x")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(abs(leverage - l) < 0.01
                                                   ? Color(red: 0.66, green: 0.33, blue: 0.97)
                                                   : Color.white.opacity(0.08))
                                )
                                .foregroundStyle(abs(leverage - l) < 0.01 ? Color.white : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            if leverage > 1 {
                HStack {
                    Text("占用保证金")
                    Spacer()
                    Text(Fmt.money(amount / leverage))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("强平价")
                    Spacer()
                    Text(Fmt.marketPrice(price * (1 - 1 / leverage), code: code))
                        .foregroundStyle(Color.downGreen)
                        .monospacedDigit()
                }
                Text("价格跌到强平价时，这笔仓位会被强制平掉，本金归零。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("杠杆")
        } footer: {
            Text("杠杆只放大盈亏，不改变方向。100x 意味着反向波动 1% 就爆仓。")
        }
    }

    // MARK: - 挂单提示

    private var queueSection: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: orderType == .limit ? "target" : "moon.zzz.fill")
                    .foregroundStyle(.orange)
                Text(orderType == .limit
                     ? "这笔单会先挂起来，价格触达后自动成交。可以在「我的 → 我的挂单」里撤销。"
                     : "当前 \(Market(code: code).displayName) 休市，这笔单会转成预埋单，等开盘后自动以市价成交。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func messageSection(_ text: String) -> some View {
        Section {
            Text(text)
                .font(.footnote)
                .foregroundStyle(messageIsError ? Color.upRed : Color.downGreen)
        }
    }

    // MARK: - 提交

    private var submitSection: some View {
        Section {
            Button {
                submit()
            } label: {
                Text(willQueue ? "挂单" : "确认\(side.label)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(side == .buy ? Color.upRed : Color.downGreen)
            .disabled(shares <= 0 || price <= 0)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func quickButton(_ title: String, ratio: Double) -> some View {
        Button(title) {
            let n = maxShares * ratio
            if isCrypto {
                // 向下截断到 8 位小数：四舍五入可能把金额顶过可用资金，导致「全仓」买不进
                let truncated = (n * 1e8).rounded(.down) / 1e8
                sharesText = truncated > 0 ? Fmt.shares(truncated) : ""
            } else {
                let i = Int(n)
                sharesText = i > 0 ? "\(i)" : ""
            }
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func submit() {
        if orderType == .limit {
            guard let limit = parsedLimit, limit > 0 else {
                message = "请输入有效的限价"
                messageIsError = true
                return
            }
            queue(limit: limit)
        } else if !marketOpen {
            queue(limit: nil)
        } else {
            tradeNow()
        }
    }

    private var parsedLimit: Double? {
        guard let v = Double(limitText) else { return nil }
        // 加密货币填的是 USDT 价，要折回记账用的人民币价
        return isCrypto ? v * FX.usdtToCNY : v
    }

    private func tradeNow() {
        let result: String?
        if side == .buy {
            result = store.buy(code: code, name: name, price: price,
                               shares: shares, leverage: showsLeverage ? leverage : 1)
        } else {
            result = store.sell(code: code, price: price, shares: shares)
        }

        if let result {
            message = result
            messageIsError = true
        } else {
            let priceStr = isCrypto ? "$" + Fmt.price(displayPrice) : Fmt.money(displayPrice)
            message = "\(side.label)成功：\(Fmt.qty(shares, code: code)) @ \(priceStr)"
            messageIsError = false
            sharesText = ""
        }
    }

    private func queue(limit: Double?) {
        let order = PendingOrder(
            code: code,
            name: name,
            side: side,
            shares: shares,
            limitPrice: limit,
            leverage: showsLeverage ? leverage : 1
        )
        OrderCenter.shared.add(order)
        Haptic.success()
        message = limit == nil
            ? "已挂预埋单：开盘后自动\(side.label) \(Fmt.qty(shares, code: code))"
            : "已挂限价单：\(order.conditionText)"
        messageIsError = false
        sharesText = ""
        limitText = ""
    }
}
