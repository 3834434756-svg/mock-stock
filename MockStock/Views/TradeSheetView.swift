import SwiftUI

/// 下单面板
struct TradeSheetView: View {
    let code: String
    let name: String
    let price: Double
    let side: TradeSide

    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var sharesText = ""
    @State private var message: String?
    @State private var messageIsError = false

    private var shares: Int { Int(sharesText) ?? 0 }
    private var amount: Double { price * Double(shares) }
    private var account: Account { store.account }
    private var heldShares: Int { account.position(for: code)?.shares ?? 0 }

    private var maxShares: Int {
        if side == .sell { return heldShares }
        guard price > 0 else { return 0 }
        if account.mode.isUnlimited { return 10_000_000 }
        return Int(account.cash / price)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(name).font(.headline)
                        Spacer()
                        Text(code.uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("现价")
                        Spacer()
                        Text(Fmt.money(price))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    HStack {
                        Text(side == .buy ? "可用资金" : "持仓数量")
                        Spacer()
                        Text(side == .buy
                             ? Fmt.money(account.cash, unlimited: account.mode.isUnlimited)
                             : "\(heldShares) 股")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("数量（股）") {
                    TextField("输入股数", text: $sharesText)
                        .keyboardType(.numberPad)
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
            let n = Int(Double(maxShares) * ratio)
            sharesText = n > 0 ? "\(n)" : ""
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
            message = "\(side.label)成功：\(shares) 股 @ \(Fmt.price(price))"
            messageIsError = false
            sharesText = ""
        }
    }
}
