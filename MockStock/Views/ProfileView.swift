import SwiftUI

/// 我的：玩法世界 / 成就 / 挂单 / 账户统计 / 设置 / 重置
struct ProfileView: View {
    @EnvironmentObject private var store: AccountStore
    @ObservedObject private var achievements = AchievementCenter.shared
    @ObservedObject private var orders = OrderCenter.shared

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
                worldSection
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
                Text("当前持仓、成交记录、成就与挂单将全部清空，并重新选择玩法世界与起始资金。")
            }
        }
    }

    // MARK: - 世界

    private var worldSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(world.accent.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: world.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(world.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(world.title)
                        .font(.system(size: 18, weight: .bold))
                    Text(world.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 6)

            HStack(spacing: 10) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 15))
                    .foregroundStyle(mode.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(mode.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(mode.capitalText)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(mode.accent)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 玩法入口

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
                        Text("平行宇宙事件")
                        Spacer()
                        Text("\(EventCenter.shared.log.count) 条")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text("玩法")
        }
    }

    // MARK: - 账户

    private var accountSection: some View {
        Section("账户") {
            LabeledContent("初始资金", value: mode.capitalText)
            LabeledContent("成交笔数", value: "\(store.account.records.count)")
            LabeledContent("持仓数量", value: "\(store.account.positions.count)")
            if store.isGame {
                LabeledContent("游戏内天数", value: "第 \(GameEngine.shared.dayIndex + 1) 天")
            }
        }
    }

    // MARK: - 设置

    private var settingsSection: some View {
        Section {
            Toggle(isOn: $soundOn) {
                Label("音效与震动", systemImage: "speaker.wave.2.fill")
            }
            .tint(.upRed)
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
                Text("重置账户 / 更换玩法世界")
            }
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("本 App 为模拟交易学习工具。现实虚拟盘使用公开接口的真实行情，"
                 + "游戏模式的价格由本地引擎模拟生成；两者均为虚拟撮合，不涉及任何真实资金，"
                 + "不构成投资建议。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
