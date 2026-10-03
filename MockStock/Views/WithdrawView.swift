import SwiftUI

/// 提现：USDT 换成人民币打到银行卡。
///
/// 门槛参照真实交易所：必须实名 + 绑卡，且**奖励金要打够流水**才能提。
struct WithdrawView: View {
    @ObservedObject private var crypto = CryptoStore.shared

    @State private var text = ""
    @State private var message: String?
    @State private var isError = false

    private var account: CryptoAccount { crypto.account }
    private var amount: Double { Double(text) ?? 0 }
    private var est: (fee: Double, cny: Double) { crypto.withdrawEstimate(amount) }

    private var canSubmit: Bool {
        account.kycDone && account.bankCard != nil && amount > 0
    }

    var body: some View {
        Form {
            balanceSection
            if !account.kycDone || account.bankCard == nil {
                requirementSection
            }
            amountSection
            summarySection
            if let message { messageSection(message) }
            submitSection
            historySection
            noteSection
        }
        .navigationTitle("提现")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 余额

    private var balanceSection: some View {
        Section {
            HStack {
                Text("可提现余额")
                Spacer()
                Text(Fmt.usdt(account.withdrawable))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.upRed)
                    .monospacedDigit()
            }
            HStack {
                Text("账户余额")
                Spacer()
                Text(Fmt.usdt(account.usdt))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if account.lockedReward > 0.01 {
                HStack {
                    Label("奖励金锁定中", systemImage: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(Fmt.usdt(account.lockedReward))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: account.rewardProgress)
                        .tint(.orange)
                    Text("还需累计 \(Fmt.u(account.turnoverToUnlock)) USDT 流水解锁")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("余额")
        }
    }

    private var requirementSection: some View {
        Section {
            if !account.kycDone {
                requirementRow(icon: "checkmark.shield.fill",
                               title: "未完成实名认证",
                               detail: "完成认证后才能提现",
                               color: .orange)
            }
            if account.bankCard == nil {
                requirementRow(icon: "creditcard.fill",
                               title: "未绑定银行卡",
                               detail: "绑定本人银行卡后才能提现",
                               color: .blue)
            }
        } header: {
            Text("提现前置条件")
        } footer: {
            Text("以上两项可在「币圈 → 实名与银行卡」里完成。")
        }
    }

    private func requirementRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 金额

    private var amountSection: some View {
        Section {
            HStack {
                TextField("提现数量", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(.title3, design: .rounded))
                Text("USDT")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { r in
                    Button {
                        let v = (account.withdrawable * r * 1e8).rounded(.down) / 1e8
                        text = v > 0 ? Fmt.shares(v) : ""
                    } label: {
                        Text(r == 1.0 ? "全部" : "\(Int(r * 100))%")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        } header: {
            Text("提现金额")
        } footer: {
            Text("单笔最低 \(Fmt.u(CryptoStore.minWithdraw)) USDT，手续费 \(Fmt.price(CryptoStore.withdrawFeeRate * 100))%。")
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("到账银行卡")
                Spacer()
                Text(account.bankCard.map { "\($0.bankName) \($0.shortMasked)" } ?? "未绑定")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("手续费（1%）")
                Spacer()
                Text(Fmt.usdt(est.fee))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text("预计到账")
                Spacer()
                Text(Fmt.money(est.cny))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.upRed)
                    .monospacedDigit()
            }
        } header: {
            Text("到账预估")
        } footer: {
            Text("按 1 USDT ≈ \(Fmt.price(CryptoStore.rate)) 元折算。")
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
                Text("确认提现")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.upRed)
            .disabled(!canSubmit)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 历史

    @ViewBuilder
    private var historySection: some View {
        if !account.withdrawals.isEmpty {
            Section("提现记录") {
                ForEach(account.withdrawals) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Fmt.usdt(w.amount))
                                .font(.system(size: 14, weight: .medium))
                                .monospacedDigit()
                            Text(w.cardTail + " · " + w.status.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.money(w.received))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.upRed)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var noteSection: some View {
        Section {
            Text("模拟提现，不会产生任何真实转账。真实交易所的提现通常还需要"
                 + "二次验证、风控审核，且到账时间为 T+1。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func submit() {
        if let err = crypto.withdraw(usdt: amount) {
            message = err
            isError = true
        } else {
            message = "提现申请已提交：\(Fmt.usdt(amount)) → \(Fmt.money(est.cny))"
            isError = false
            text = ""
        }
    }
}
