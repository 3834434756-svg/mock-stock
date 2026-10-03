import SwiftUI

/// 任务中心：注册 / 实名 / 绑卡 / 入金 / 流水阶梯 / 每日签到。
///
/// 奖励一律发 USDT，并且计入打码量 —— 领得越多，要打够的流水也越多。
struct MissionCenterView: View {
    @ObservedObject private var missions = MissionCenter.shared
    @ObservedObject private var crypto = CryptoStore.shared

    @State private var showKYC = false
    @State private var showBank = false
    @State private var showDeposit = false

    var body: some View {
        List {
            summarySection

            ForEach(MissionGroup.allCases) { g in
                Section {
                    ForEach(Mission.list(g)) { m in
                        missionRow(m)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Image(systemName: g.symbolName)
                        Text(g.rawValue)
                        Spacer()
                        Text(g.subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }

            ruleSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("任务中心")
        .navigationDestination(isPresented: $showKYC) { KYCView() }
        .navigationDestination(isPresented: $showBank) { BankCardView() }
        .navigationDestination(isPresented: $showDeposit) { DepositView() }
    }

    // MARK: - 汇总

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("累计领取奖励")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Fmt.usdt(missions.totalClaimed))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }

                    Spacer()

                    if missions.claimableCount > 0 {
                        Button {
                            missions.claimAll()
                        } label: {
                            Text("一键领取 \(missions.claimableCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.upRed))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if crypto.account.rewardTotal > 0 {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("提现打码进度")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(crypto.account.rewardProgress * 100))%")
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                        ProgressView(value: crypto.account.rewardProgress)
                            .tint(.orange)
                        Text("奖励金需累计 \(Int(CryptoAccount.rewardMultiple)) 倍流水方可提现 · "
                             + "已解锁 \(Fmt.u(crypto.account.rewardUnlocked)) / "
                             + "\(Fmt.u(crypto.account.rewardTotal)) USDT")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 单条任务

    private func missionRow(_ m: Mission) -> some View {
        let claimed = missions.isClaimed(m)
        let can = missions.canClaim(m)
        let tint = groupColor(m.group)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((claimed ? Color.secondary : tint).opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: claimed ? "checkmark" : m.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(claimed ? Color.secondary : tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium))
                    Text("+\(Fmt.u(m.reward))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.96, green: 0.77, blue: 0.26))
                        .monospacedDigit()
                }

                Text(m.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if m.target != nil, !claimed {
                    ProgressView(value: missions.progress(m))
                        .tint(tint)
                    Text(progressText(m))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 6)

            if claimed {
                Text("已领取")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if can {
                Text("领取")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.upRed))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { rowTap(m) }
    }

    private func progressText(_ m: Mission) -> String {
        let cur = missions.current(m)
        let target = m.target ?? 0
        switch m.kind {
        case .tradeCount, .holdKinds:
            return "\(Int(cur)) / \(Int(target)) \(m.progressUnit)"
        case .turnover:
            return "\(Fmt.u(cur)) / \(Fmt.u(target)) \(m.progressUnit)"
        default:
            return ""
        }
    }

    /// 点整行：能领就领，需要跳转的去对应页面
    private func rowTap(_ m: Mission) {
        if missions.canClaim(m) {
            missions.claim(m)
            return
        }
        guard !missions.isClaimed(m) else { return }
        switch m.kind {
        case .kyc:      showKYC = true
        case .bankCard: showBank = true
        case .deposit:  showDeposit = true
        default:        break
        }
    }

    private func groupColor(_ g: MissionGroup) -> Color {
        switch g {
        case .newbie:   return Color(red: 0.96, green: 0.77, blue: 0.26)
        case .turnover: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .daily:    return Color(red: 0.13, green: 0.77, blue: 0.37)
        }
    }

    // MARK: - 规则

    private var ruleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                ruleLine("奖励以 USDT 发放，到账后可立即用于交易。")
                ruleLine("奖励金需累计 \(Int(CryptoAccount.rewardMultiple)) 倍流水才能解锁提现。")
                ruleLine("流水按成交额累计，买入卖出都算。")
                ruleLine("每日任务在北京时间 00:00 重置。")
            }
            .padding(.vertical, 2)
        } header: {
            Text("活动规则")
        }
    }

    private func ruleLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·")
            Text(text)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

/// 任务奖励到账横幅
struct MissionToastView: View {
    let mission: Mission

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.downGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("任务完成 · \(mission.title)")
                    .font(.system(size: 13, weight: .semibold))
                Text("+\(Fmt.u(mission.reward)) USDT 已到账")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.96, green: 0.77, blue: 0.26))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.downGreen.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
