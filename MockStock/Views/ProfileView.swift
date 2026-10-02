import SwiftUI

/// 我的：模式信息 + 账户统计 + 重置
struct ProfileView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(store.account.mode.accent.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: store.account.mode.symbolName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(store.account.mode.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.account.mode.title)
                                .font(.system(size: 18, weight: .bold))
                            Text(store.account.mode.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("账户") {
                    LabeledContent("初始资金", value: store.account.mode.capitalText)
                    LabeledContent("成交笔数", value: "\(store.account.records.count)")
                    LabeledContent("持仓数量", value: "\(store.account.positions.count)")
                }

                Section("数据") {
                    LabeledContent("行情来源", value: "腾讯财经")
                    LabeledContent("更新频率", value: "15 秒")
                }

                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Text("重置账户 / 更换模式")
                    }
                }

                Section {
                    Text("本 App 为模拟交易学习工具。行情数据来自公开接口，交易为本地虚拟撮合，不涉及任何真实资金，不构成投资建议。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
            .alert("确认重置？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    store.resetToSetup()
                }
            } message: {
                Text("当前持仓与成交记录将全部清空，并重新选择游戏模式。")
            }
        }
    }
}
