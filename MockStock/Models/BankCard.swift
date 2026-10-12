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

/// 提现的到账方式。
///
/// 币账户的钱有两条出口：
/// - `bankCard`：换成人民币打到银行卡，收 1% 提现手续费，需实名 + 绑卡
/// - `stockAccount`：换回人民币划进「交易账户」（股票账户）——
///   属于 App 内部划转，不收手续费，也不需要实名 / 绑卡
///
/// **两条出口都受可提现额度（打码）限制。** 否则被锁定的奖励金可以直接
/// 划回股票账户，打码就形同虚设了。
enum WithdrawChannel: String, Codable, CaseIterable, Identifiable {
    case bankCard
    case stockAccount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bankCard:     return "银行卡"
        case .stockAccount: return "交易账户"
        }
    }

    /// 提现手续费率。划回自己的交易账户属于内部划转，不收费。
    /// 与 `CryptoStore.withdrawFeeRate` 是同一个口径
    var feeRate: Double {
        switch self {
        case .bankCard:     return 0.01
        case .stockAccount: return 0
        }
    }

    /// 是否必须先完成实名认证 + 绑定银行卡
    var requiresKYCAndCard: Bool { self == .bankCard }
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
    /// 到账方式。老存档没有这个字段，解码为 nil，一律按「银行卡」展示。
    /// 用可选类型是为了让旧记录能正常解码 —— 写成非可选会让整个
    /// `CryptoAccount` 解码失败，用户币账户会被静默清空
    var channel: WithdrawChannel?

    /// 展示用：老记录缺 channel 时按银行卡处理
    var channelOrDefault: WithdrawChannel { channel ?? .bankCard }

    /// 记录列表里的到账目标文案
    var targetLabel: String {
        switch channelOrDefault {
        case .bankCard:     return cardTail
        case .stockAccount: return "交易账户"
        }
    }

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
