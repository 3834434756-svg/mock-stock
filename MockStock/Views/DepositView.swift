import SwiftUI

/// 入金：把股票账户的人民币按固定汇率换成 USDT 存进币账户。
struct DepositView: View {
    @ObservedObject private var crypto = CryptoStore.shared
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var message: String?
    @State private var isError = false

    private var cny: Double { Double(text) ?? 0 }
    private var usdt: Double { cny / CryptoStore.rate }
    private var unlimited: Bool { store.account.mode.isUnlimited }

    private let presets: [Double] = [1_000, 10_000, 50_000, 200_000]

    var body: some View {
        Form {
            balanceSection
            amountSection
            summarySection
            if let message { messageSection(message) }
            submitSection
            noteSection
        }
        .navigationTitle("入金")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var balanceSection: some View {
        Section {
            HStack {
                Text("交易账户可用")
                Spacer()
                Text(Fmt.money(store.account.cash, unlimited: unlimited))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text("币账户余额")
                Spacer()
                Text(Fmt.usdt(crypto.account.usdt))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } header: {
            Text("余额")
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                Text("¥")
                    .foregroundStyle(.secondary)
                TextField("输入人民币金额", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(.title3, design: .rounded))
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { v in
                    Button {
                        text = String(format: "%.0f", v)
                    } label: {
                        Text(Fmt.compact(v))
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }

            if !unlimited {
                Button("全部可用资金") {
                    text = String(format: "%.2f", store.account.cash)
                }
                .font(.footnote)
            }
        } header: {
            Text("入金金额")
        } footer: {
            Text("按 1 USDT ≈ \(Fmt.price(CryptoStore.rate)) 元的固定汇率折算。"
                 + "固定汇率是为了让盈亏里不混进跟行情无关的汇率波动。")
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("预计到账")
                Spacer()
                Text(Fmt.usdt(usdt))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.upRed)
                    .monospacedDigit()
            }
        } header: {
            Text("预估")
        }
    }

    private func messageSection(_ text: String) -> some View {
        Section {
            Text(text)
                .font(.footnote)
                .foregroundStyle(isError ? Color.upRed : Color.downGreen)
        }
    }

    private var submitSection: some View {
        Section {
            Button {
                submit()
            } label: {
                Text("确认入金")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.upRed)
            .disabled(cny <= 0)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var noteSection: some View {
        Section {
            Text("入金不产生手续费。币账户与股票账户相互独立，"
                 + "入金只是把资金从一边挪到另一边，不改变总资产。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func submit() {
        if let err = crypto.deposit(cny: cny) {
            message = err
            isError = true
        } else {
            message = "入金成功：\(Fmt.money(cny)) → \(Fmt.usdt(usdt))"
            isError = false
            text = ""
        }
    }
}
