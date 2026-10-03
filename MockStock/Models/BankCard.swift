import Foundation

/// 银行卡。只保留后四位用于展示，界面上不出现完整卡号。
struct BankCard: Codable, Equatable {
    var bankName: String
    var cardNumber: String
    var holder: String
    var phone: String

    /// 掩码卡号，如 `**** **** **** 8888`
    var masked: String {
        "**** **** **** " + tail
    }

    /// 尾号，如 `尾号 8888`
    var shortMasked: String { "尾号 " + tail }

    private var tail: String {
        cardNumber.count >= 4 ? String(cardNumber.suffix(4)) : cardNumber
    }
}

/// 提现记录
struct Withdrawal: Codable, Identifiable {
    var id: UUID = UUID()
    var amount: Double      // 提现金额（USDT）
    var fee: Double         // 手续费（USDT）
    var received: Double    // 到账人民币
    var rate: Double        // 当时汇率
    var cardTail: String
    var date: Date
    var status: WithdrawStatus = .done

    enum WithdrawStatus: String, Codable {
        case pending, done, failed

        var label: String {
            switch self {
            case .pending: return "处理中"
            case .done:    return "已到账"
            case .failed:  return "已驳回"
            }
        }
    }
}

/// 绑定银行卡时可选的开户行
enum BankCatalog {
    static let names = ["工商银行", "建设银行", "农业银行", "中国银行", "招商银行",
                        "交通银行", "邮储银行", "浦发银行", "民生银行", "兴业银行",
                        "中信银行", "光大银行", "平安银行", "广发银行", "华夏银行"]
}
