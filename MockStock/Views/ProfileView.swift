import SwiftUI

/// 我的：账户概览 / 功能入口 / 统计 / 设置 / 重置
struct ProfileView: View {
    @EnvironmentObject private var store: AccountStore
    @ObservedObject private var achievements = AchievementCenter.shared
    @ObservedObject private var orders = OrderCenter.shared
    @ObservedObject private var engine = GameEngine.shared
    @ObservedObject private var crypto = CryptoStore.shared

    @AppStorage("mockstock.sound.on") private var soundOn = true

    @State private var showResetAlert = false

    private var world: TradingWorld { store.account.world }
    private var mode: GameMode { store.account.mode }

    private var achievementTotal: Int { achievements.list(for: world).count }
    private var achievementDone: Int {
        achievements.list(for: world).filter { achievements.isUnlocked($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                playSection
                accountSection
                settingsSection
                resetSection
                disclaimerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .alert("确认重置？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    store.resetToSetup()
                }
            } message: {
                Text("当前持仓、成交记录、成就、挂单，以及币币账户与任务进度将全部清空，"
                     + "并重新选择起始资金。")
            }
        }
    }

    // MARK: - 账户概览

    private var overviewSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(mode.accent.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(mode.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("起始资金")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(mode.capitalText)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(mode.accent)
                            .monospacedDigit()
                    }
                    Text(world.tagline)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 功能入口

    private var playSection: some View {
        Section {
            NavigationLink {
                AchievementsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.24))
                        .frame(width: 26)
                    Text("成就")
                    Spacer()
                    Text("\(achievementDone) / \(achievementTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            NavigationLink {
                PendingOrdersView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                        .frame(width: 26)
                    Text("我的挂单")
                    Spacer()
                    if !orders.pending.isEmpty {
                        Text("\(orders.pending.count) 笔挂单中")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            if store.isGame {
                NavigationLink {
                    EventLogView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                            .frame(width: 26)
                        Text("突发事件")
                        Spacer()
                        Text("\(EventCenter.shared.log.count) 条")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text("功能")
        }
    }

    // MARK: - 账户

    private var accountSection: some View {
        Section {
            LabeledContent("成交笔数", value: "\(store.account.records.count)")
            LabeledContent("持仓数量", value: "\(store.account.positions.count)")
            LabeledContent("币币账户", value: Fmt.usdt(crypto.account.usdt))
        } header: {
            Text("账户")
        } footer: {
            Text("币币账户与股票账户相互独立，以 USDT 计价，可在「币圈」里交易、入金与提现。")
        }
    }

    // MARK: - 设置

    private var settingsSection: some View {
        Section {
            Toggle(isOn: $soundOn) {
                Label("音效与震动", systemImage: "speaker.wave.2.fill")
            }
            .tint(.upRed)

            // 本地模拟盘的行情是引擎自己推进的，可以调速；
            // 真实盘的时间就是真实时间，没有这一项
            if store.isGame {
                Picker(selection: $engine.speed) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("5x").tag(5.0)
                } label: {
                    Label("行情推进速度", systemImage: "gauge.with.dots.needle.67percent")
                }
            }
        } header: {
            Text("设置")
        } footer: {
            Text("音效由波形实时合成，不占安装包体积。")
        }
    }

    // MARK: - 重置

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Text("重置账户")
            }
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("本 App 为模拟交易学习工具。真实行情来自公开接口，"
                 + "本地模拟盘的价格由本地引擎生成；两者均为虚拟撮合，"
                 + "不涉及任何真实资金，不构成投资建议。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
