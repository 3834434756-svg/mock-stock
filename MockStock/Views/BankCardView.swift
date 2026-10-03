import SwiftUI

/// 实名与银行卡。
///
/// 这两件事是提现的前置条件，所以放在同一页：上半部分看认证状态，
/// 下半部分管银行卡。
struct BankCardView: View {
    @ObservedObject private var crypto = CryptoStore.shared

    @State private var bankName = BankCatalog.names[0]
    @State private var cardNumber = ""
    @State private var holder = ""
    @State private var phone = ""
    @State private var message: String?
    @State private var isError = false
    @State private var showUnbindAlert = false

    private var account: CryptoAccount { crypto.account }

    /// 卡号 16–19 位数字
    private var cardValid: Bool {
        let digits = cardNumber.filter { $0.isNumber }
        return digits.count >= 16 && digits.count <= 19
    }

    private var phoneValid: Bool {
        let digits = phone.filter { $0.isNumber }
        return digits.count == 11
    }

    private var formValid: Bool {
        cardValid && phoneValid && holder.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        Form {
            kycSection
            if account.bankCard == nil {
                bindFormSection
            } else {
                boundCardSection
            }
            if let message { messageSection(message) }
            noteSection
        }
        .navigationTitle("实名与银行卡")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认解绑？", isPresented: $showUnbindAlert) {
            Button("取消", role: .cancel) { }
            Button("解绑", role: .destructive) {
                crypto.unbindCard()
                message = "已解绑银行卡，提现功能已暂停"
                isError = true
            }
        } message: {
            Text("解绑后将无法提现，需要重新绑定。")
        }
    }

    // MARK: - 实名状态

    private var kycSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: account.kycDone ? "checkmark.shield.fill" : "shield.slash.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(account.kycDone ? Color.downGreen : Color.orange)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(account.kycDone ? "已实名认证" : "未实名认证")
                        .font(.system(size: 15, weight: .medium))
                    Text(account.kycDone
                         ? "提现功能已解锁"
                         : "提现前必须完成实名认证")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if account.kycDone {
                    Text("已通过")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.downGreen)
                }
            }
            .padding(.vertical, 2)

            if !account.kycDone {
                NavigationLink {
                    KYCView()
                } label: {
                    Label("去完成实名认证（+20 USDT）", systemImage: "person.text.rectangle")
                        .font(.system(size: 14))
                }
            }
        } header: {
            Text("实名认证")
        }
    }

    // MARK: - 已绑卡

    private var boundCardSection: some View {
        Section {
            if let card = account.bankCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 20))
                        Text(card.bankName)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("储蓄卡")
                            .font(.system(size: 11))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                    }

                    Text(card.masked)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .kerning(1.5)

                    HStack {
                        Text(card.holder)
                            .font(.system(size: 13))
                        Spacer()
                        Text(card.phone)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Color(red: 0.16, green: 0.30, blue: 0.62),
                                            Color(red: 0.09, green: 0.16, blue: 0.36)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                Button(role: .destructive) {
                    showUnbindAlert = true
                } label: {
                    Text("解绑银行卡")
                }
            }
        } header: {
            Text("已绑定")
        }
    }

    // MARK: - 绑卡表单

    private var bindFormSection: some View {
        Section {
            Picker("开户行", selection: $bankName) {
                ForEach(BankCatalog.names, id: \.self) { n in
                    Text(n).tag(n)
                }
            }

            HStack {
                Text("卡号")
                Spacer()
                TextField("16–19 位", text: $cardNumber)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("持卡人")
                Spacer()
                TextField("姓名", text: $holder)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180)
            }

            HStack {
                Text("预留手机号")
                Spacer()
                TextField("11 位", text: $phone)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180)
                    .font(.system(.body, design: .monospaced))
            }

            Button {
                bind()
            } label: {
                Text("确认绑定")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.upRed)
            .disabled(!formValid)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("绑定银行卡")
        } footer: {
            Text("需绑定本人名下银行卡。模拟绑定不会产生任何真实校验或扣款，"
                 + "卡号仅保存在本机。")
        }
    }

    private func bind() {
        let digits = cardNumber.filter { $0.isNumber }
        let card = BankCard(bankName: bankName,
                            cardNumber: digits,
                            holder: holder.trimmingCharacters(in: .whitespaces),
                            phone: phone.filter { $0.isNumber })
        crypto.bindCard(card)
        message = "绑定成功，去任务中心领取 15 USDT 奖励"
        isError = false
        cardNumber = ""
        holder = ""
        phone = ""
    }

    private func messageSection(_ text: String) -> some View {
        Section {
            Text(text)
                .font(.footnote)
                .foregroundStyle(isError ? Color.upRed : Color.downGreen)
        }
    }

    private var noteSection: some View {
        Section {
            Text("提现前需同时满足：已完成实名认证、已绑定银行卡、"
                 + "金额不低于 \(Fmt.u(CryptoStore.minWithdraw)) USDT、"
                 + "且奖励金已打够 \(Int(CryptoAccount.rewardMultiple)) 倍流水。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
