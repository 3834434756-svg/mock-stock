import SwiftUI

/// 币币下单面板。
///
/// 与股票下单最大的区别：**这里的一切都以 USDT 计价**。
/// 买入填的是「花多少 U」，卖出填的是「卖多少个币」，
/// 手续费按成交额 0.1% 双向收取。
struct CryptoTradeSheetView: View {
    let code: String
    let name: String
    let short: String
    let side: TradeSide

    @ObservedObject private var crypto = CryptoStore.shared
    @Environment(\.dismiss) private var dismiss

    /// 买入：USDT 金额；卖出：币的数量
    @State private var inputText = ""
    @State private var message: String?
    @State private var messageIsError = false

    private var price: Double { crypto.price(of: code) }
    private var account: CryptoAccount { crypto.account }
    private var held: Double { account.position(for: code)?.shares ?? 0 }

    private var value: Double { Double(inputText) ?? 0 }

    /// 成交额（USDT）
    private var gross: Double {
        side == .buy ? value : value * price
    }

    private var fee: Double { gross * CryptoStore.feeRate }

    /// 预计得到的币数量
    private var estShares: Double {
        guard price > 0 else { return 0 }
        return side == .buy ? (value - fee) / price : value
    }

    /// 预计回款（USDT）
    private var estProceeds: Double {
        side == .buy ? 0 : gross - fee
    }

    private var unit: String { side == .buy ? "USDT" : short }

    var body: some View {
        NavigationStack {
            Form {
                quoteSection
                amountSection
                summarySection
                if let message { messageSection(message) }
                submitSection
            }
            .navigationTitle(side == .buy ? "买入 \(short)" : "卖出 \(short)")
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
                Text(short + "/USDT")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("现价")
                Spacer()
                Text("$" + Fmt.price(price))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            HStack {
                Text(side == .buy ? "可用 USDT" : "持有")
                Spacer()
                Text(side == .buy ? Fmt.usdt(account.usdt) : Fmt.coin(held, short))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 数量

    private var amountSection: some View {
        Section {
            HStack {
                Text(side == .buy ? "花费" : "数量")
                Spacer()
                TextField(side == .buy ? "0.00" : "0", text: $inputText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
                    .font(.system(.title3, design: .rounded))
                Text(unit)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                quickButton("25%", 0.25)
                quickButton("50%", 0.5)
                quickButton("75%", 0.75)
                quickButton("全部", 1.0)
            }
        } header: {
            Text(side == .buy ? "买入金额（USDT）" : "卖出数量（\(short)）")
        } footer: {
            Text(side == .buy
                 ? "手续费 0.1% 从这笔金额里扣除，剩余部分按现价换成 \(short)。"
                 : "手续费 0.1% 从回款里扣除。")
        }
    }

    private func quickButton(_ title: String, _ ratio: Double) -> some View {
        Button(title) {
            let v = (side == .buy ? account.usdt : held) * ratio
            // 向下截断到 8 位小数，避免四舍五入把金额顶过可用余额
            let t = (v * 1e8).rounded(.down) / 1e8
            inputText = t > 0 ? Fmt.shares(t) : ""
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
        .font(.system(size: 13))
    }

    // MARK: - 预估

    private var summarySection: some View {
        Section {
            HStack {
                Text("成交额")
                Spacer()
                Text(Fmt.usdt(gross))
                    .monospacedDigit()
            }
            HStack {
                Text("手续费（0.1%）")
                Spacer()
                Text(Fmt.usdt(fee))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if side == .buy {
                HStack {
                    Text("预计得到")
                    Spacer()
                    Text(Fmt.coin(estShares, short))
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.upRed)
                        .monospacedDigit()
                }
            } else {
                HStack {
                    Text("预计回款")
                    Spacer()
                    Text(Fmt.usdt(estProceeds))
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.downGreen)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("预估")
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
                Text("确认\(side.label)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(side == .buy ? Color.upRed : Color.downGreen)
            .disabled(value <= 0 || price <= 0)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func submit() {
        let result: String?
        if side == .buy {
            result = crypto.buy(code: code, name: name, short: short, price: price, usdt: value)
        } else {
            result = crypto.sell(code: code, price: price, shares: value)
        }

        if let result {
            message = result
            messageIsError = true
        } else {
            message = side == .buy
                ? "买入成功：\(Fmt.coin(estShares, short)) @ $\(Fmt.price(price))"
                : "卖出成功：\(Fmt.coin(value, short)) @ $\(Fmt.price(price))"
            messageIsError = false
            inputText = ""
        }
    }
}
