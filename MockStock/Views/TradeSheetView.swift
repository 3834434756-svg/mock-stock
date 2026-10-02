import SwiftUI

/// 下单面板。
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
    @State private var message: String?
    @State private var messageIsError = false

    private var isCrypto: Bool { Market(code: code) == .crypto }
    private var account: Account { store.account }

    /// 成交数量。股票是整数股，加密货币是小数份额
    private var shares: Double { Double(sharesText) ?? 0 }
    private var amount: Double { price * shares }
    private var heldShares: Double { account.position(for: code)?.shares ?? 0 }

    /// 展示价。加密货币还原成 USDT，跟交易所看到的一致
    private var displayPrice: Double { isCrypto ? price / FX.usdtToCNY : price }

    private var unit: String { isCrypto ? CryptoCoin.shortName(code) : "股" }

    private var maxShares: Double {
        if side == .sell { return heldShares }
        guard price > 0 else { return 0 }
        if account.mode.isUnlimited { return 1_000_000 }
        return account.cash / price
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section("数量（\(unit)）") {
                    TextField("输入\(unit)数量", text: $sharesText)
                        .keyboardType(isCrypto ? .decimalPad : .numberPad)
                        .font(.system(.title3, design: .rounded))

                    HStack(spacing: 8) {
                        quickButton("全仓", ratio: 1.0)
                        quickButton("半仓", ratio: 0.5)
                        quickButton("1/3", ratio: 1.0 / 3.0)
                    }
                }

                Section {
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

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(messageIsError ? Color.upRed : Color.downGreen)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Text("确认\(side.label)")
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
            .navigationTitle(side.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
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
        let result: String?
        if side == .buy {
            result = store.buy(code: code, name: name, price: price, shares: shares)
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
}
