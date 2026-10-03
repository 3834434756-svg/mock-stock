import SwiftUI

/// 提现：USDT 换成人民币打到银行卡。
///
/// 门槛参照真实交易所：必须实名 + 绑卡，且**奖励金要打够流水**才能提。
/// 入金的本金不受打码限制，随时可提 —— 这一点必须在界面上说清楚，
/// 否则用户看到「账户里明明有钱却提不出来」，只会当成 bug。
struct WithdrawView: View {
    @ObservedObject private var crypto = CryptoStore.shared

    @State private var text = ""
    @State private var message: String?
    @State private var isError = false

    private var account: CryptoAccount { crypto.account }
    /// 金额解析。容忍粘贴进来的千分位与全角字符 ——
    /// `Double("1,000")` 会返回 nil，之前会让用户以为"填了金额却没反应"
    private var amount: Double {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0
    }
    private var est: (fee: Double, cny: Double) { crypto.withdrawEstimate(amount) }

    /// 可提现额度。走 CryptoStore 的口径（净值 − 锁定奖励，再截断到现金），
    /// 这样奖励金买成币之后不会显示成 0
    private var available: Double { crypto.withdrawable }
    /// 前置条件（实名 + 绑卡）是否齐了
    private var prerequisiteOK: Bool { account.kycDone && account.bankCard != nil }

    private var canSubmit: Bool { prerequisiteOK && amount >= CryptoStore.minWithdraw && amount <= available + 1e-6 }

    var body: some View {
        Form {
            statusSection
            if !prerequisiteOK { requirementSection }
            amountSection
            if amount > 0 { summarySection }
            if let message { messageSection(message) }
            submitSection
            if let reason = blockReason { blockSection(reason) }
            unlockGuideSection
            historySection
            noteSection
        }
        .navigationTitle("提现")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 可提现额度

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(Fmt.u(available))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(available > 0 ? Color.upRed : Color.secondary)
                        .monospacedDigit()
                    Text("USDT 可提现")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    statCell("可用余额", Fmt.u(account.usdt))
                    statCell("持仓市值", Fmt.u(crypto.positionsValue))
                    statCell("奖励锁定", Fmt.u(account.lockedReward),
                             color: account.lockedReward > 0.01 ? .orange : .secondary)
                }

                if account.lockedReward > 0.01 {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: account.rewardProgress)
                            .tint(.orange)
                        Text("还需累计 \(Fmt.u(account.turnoverToUnlock)) USDT 买卖流水解锁")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                // 钱都压在币里时，用户最需要知道的就是「先卖再提」
                if available < CryptoStore.minWithdraw, crypto.positionsValue > 0.01 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11))
                        Text("持仓里有 \(Fmt.usdt(crypto.positionsValue)) 可以变现。"
                             + "先去「币圈」卖出换成可用余额，就能提现。")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("可提现额度")
        } footer: {
            Text("入金的本金不受限制、随时可提；任务奖励要打够 "
                 + "\(Int(CryptoAccount.rewardMultiple)) 倍流水才能提。")
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

    // MARK: - 前置条件

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
                        fill(r)
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
                Text("手续费（\(Fmt.price(CryptoStore.withdrawFeeRate * 100))%）")
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

    // MARK: - 提不了的原因

    /// 提交按钮为什么是灰的。
    /// 之前这里完全静默 —— 用户点「全部」没反应、点提交没反应，
    /// 只能得出「提现坏了」这一个结论。现在把原因摆出来。
    private var blockReason: String? {
        if !account.kycDone {
            return "还未完成实名认证。去「币圈 → 实名与银行卡」完成认证后即可提现。"
        }
        if account.bankCard == nil {
            return "还未绑定银行卡。绑定本人银行卡后即可提现。"
        }

        // 已经填了金额，就针对这个金额说问题。
        // 此前只要 amount > 0 就直接返回 nil，导致填 5 USDT（低于门槛）
        // 时界面上一条提示都没有，点了提交才弹错 —— 很像"按钮坏了"
        if amount > 0 {
            if amount < CryptoStore.minWithdraw {
                return "单笔最低提现 \(Fmt.u(CryptoStore.minWithdraw)) USDT，"
                    + "当前 \(Fmt.u(amount)) USDT。"
            }
            if amount > available + 1e-6 {
                return "可提现额度为 \(Fmt.usdt(available))，"
                    + "当前输入 \(Fmt.usdt(amount)) 超出了这个额度。"
            }
            return nil
        }

        // 还没填金额，说说整体卡在哪
        if available < CryptoStore.minWithdraw {
            if account.lockedReward > 0.01 {
                return "奖励金还有 \(Fmt.usdt(account.lockedReward)) 被锁定，"
                    + "再完成 \(Fmt.u(account.turnoverToUnlock)) USDT 买卖流水即可解锁"
                    + "（在「币圈」买入再卖出即可，买卖各算一次）。"
            }
            if crypto.positionsValue > 0.01 {
                return "可用余额 \(Fmt.usdt(account.usdt))，另有 "
                    + "\(Fmt.usdt(crypto.positionsValue)) 在持仓里。"
                    + "先去「币圈」卖出持仓，换成可用余额再提。"
            }
            if account.usdt > 0.01 {
                return "可提现 \(Fmt.usdt(available))，不足单笔最低 "
                    + "\(Fmt.u(CryptoStore.minWithdraw)) USDT。"
            }
            return "账户可用余额为 0。先去「币圈」入金，或到任务中心领取奖励。"
        }
        return "请输入提现金额。"
    }

    /// 快捷比例填充。
    ///
    /// 之前点「全部」在可提现为 0 时会把输入框设成空串 —— 点了完全没反应，
    /// 用户只能认为功能坏了。现在点不动也要给个说法。
    private func fill(_ ratio: Double) {
        let v = (available * ratio * 1e8).rounded(.down) / 1e8
        guard v >= CryptoStore.minWithdraw else {
            text = ""
            message = available > 0
                ? "可提现 \(Fmt.usdt(available))，不足单笔最低 \(Fmt.u(CryptoStore.minWithdraw)) USDT。"
                : (blockReason ?? "暂无可提现额度。")
            isError = true
            return
        }
        text = Fmt.shares(v)
        message = nil
    }

    private func blockSection(_ reason: String) -> some View {
        Section {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 解锁引导：告诉用户具体该做什么，而不是只丢一个进度条
    @ViewBuilder
    private var unlockGuideSection: some View {
        if available < CryptoStore.minWithdraw || account.lockedReward > 0.01 {
            Section {
                if available < CryptoStore.minWithdraw {
                    NavigationLink {
                        DepositView()
                    } label: {
                        Label("去入金（本金可随时提现）", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                    }
                }
                if account.lockedReward > 0.01 {
                    NavigationLink {
                        MissionCenterView()
                    } label: {
                        Label("去任务中心领更多奖励", systemImage: "gift.fill")
                            .font(.system(size: 14))
                    }
                }
            } header: {
                Text("如何解锁")
            } footer: {
                Text("在「币圈」买入再卖出任意币种都会累计流水，买入和卖出各算一次。"
                     + "赚到的差价、领到的奖励都留在币账户里，随时可以再来提。")
            }
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
