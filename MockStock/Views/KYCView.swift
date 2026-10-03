import SwiftUI

/// 实名认证（KYC）。
///
/// 模拟交易所的身份验证流程：填姓名 + 证件号，通过后解锁提现并发放认证奖励。
/// 注意这里**不做任何真实校验、不联网、不落盘敏感信息** —— 只存姓名用于展示。
struct KYCView: View {
    @ObservedObject private var crypto = CryptoStore.shared

    @State private var name = ""
    @State private var idNo = ""
    @State private var message: String?
    @State private var isError = false

    private var account: CryptoAccount { crypto.account }

    /// 简单校验：姓名 2 字以上，证件号 15 位以上
    private var valid: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2
            && idNo.trimmingCharacters(in: .whitespaces).count >= 15
    }

    var body: some View {
        Form {
            if account.kycDone {
                doneSection
            } else {
                introSection
                formSection
                if let message { messageSection(message) }
                submitSection
            }
            noteSection
        }
        .navigationTitle("实名认证")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 已认证

    private var doneSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.downGreen.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.downGreen)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("已完成实名认证")
                        .font(.system(size: 16, weight: .semibold))
                    Text(maskedName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            LabeledContent("证件号码", value: maskedId)
            LabeledContent("认证状态", value: "已通过")
        } header: {
            Text("认证信息")
        }
    }

    private var maskedName: String {
        guard let first = account.kycName.first else { return "—" }
        return String(first) + "**"
    }

    private var maskedId: String {
        let s = account.kycIdNo
        guard s.count > 8 else { return "—" }
        return String(s.prefix(4)) + "**********" + String(s.suffix(4))
    }

    // MARK: - 未认证

    private var introSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("完成认证可领 20 USDT")
                        .font(.system(size: 14, weight: .semibold))
                    Text("认证后解锁提现功能")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var formSection: some View {
        Section {
            HStack {
                Text("姓名")
                Spacer()
                TextField("与证件一致", text: $name)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180)
            }
            HStack {
                Text("证件号码")
                Spacer()
                TextField("身份证号", text: $idNo)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("身份信息")
        } footer: {
            Text("本功能为模拟演示，填写内容不会上传、不会联网核验，仅保存在本机。")
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
                crypto.verifyKYC(name: name.trimmingCharacters(in: .whitespaces),
                                 idNo: idNo.trimmingCharacters(in: .whitespaces))
                message = "认证通过，20 USDT 奖励已发放，去任务中心领取"
                isError = false
            } label: {
                Text("提交认证")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.upRed)
            .disabled(!valid)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var noteSection: some View {
        Section {
            Text("模拟认证，不会采集或上传任何个人信息。"
                 + "真实交易所的 KYC 需要上传身份证正反面并进行人脸识别。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
