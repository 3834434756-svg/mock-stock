import Foundation
import Combine

/// 任务中心。
///
/// 判定所需的原始数据全部来自 `CryptoStore`，这里只负责「进度 → 可领取 → 已领取」
/// 这三态，以及把奖励发下去。奖励一律以 USDT 发放并计入打码量，
/// 所以领得越多，需要打够的流水也越多 —— 跟真实交易所一个套路。
@MainActor
final class MissionCenter: ObservableObject {
    static let shared = MissionCenter()

    /// 已领取的任务 id -> 领取时间。每日任务靠这个日期判断今天领没领过
    @Published private(set) var claimed: [String: Date] = [:]
    /// 最近一次领取成功的提示
    @Published var toast: Mission?

    private let key = "mockstock.mission.v1"

    private init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let m = try? JSONDecoder().decode([String: Date].self, from: d) {
            claimed = m
        }
    }

    // MARK: - 状态判定

    private var account: CryptoAccount { CryptoStore.shared.account }

    /// 任务条件是否已满足
    func isDone(_ m: Mission) -> Bool {
        switch m.kind {
        case .register:          return true          // 装上了就算注册
        case .kyc:               return account.kycDone
        case .bankCard:          return account.bankCard != nil
        case .deposit:           return account.totalDeposit > 0
        case .tradeCount(let n): return account.records.count >= n
        case .turnover(let t):   return account.turnover >= t
        case .holdKinds(let n):  return account.positions.count >= n
        case .dailySign:         return true          // 签到随时可做
        case .dailyTrade:        return tradedToday
        }
    }

    /// 今天有没有成交过
    var tradedToday: Bool {
        account.records.contains { Calendar.current.isDateInToday($0.date) }
    }

    /// 是否已领取。每日任务按当天判断，跨天自动重置
    func isClaimed(_ m: Mission) -> Bool {
        guard let d = claimed[m.id] else { return false }
        if m.kind.isDaily { return Calendar.current.isDateInToday(d) }
        return true
    }

    func canClaim(_ m: Mission) -> Bool {
        isDone(m) && !isClaimed(m)
    }

    /// 进度 0...1
    func progress(_ m: Mission) -> Double {
        switch m.kind {
        case .register:          return 1
        case .kyc:               return account.kycDone ? 1 : 0
        case .bankCard:          return account.bankCard != nil ? 1 : 0
        case .deposit:           return account.totalDeposit > 0 ? 1 : 0
        case .tradeCount(let n): return n > 0 ? min(1, Double(account.records.count) / Double(n)) : 1
        case .turnover(let t):   return t > 0 ? min(1, account.turnover / t) : 1
        case .holdKinds(let n):  return n > 0 ? min(1, Double(account.positions.count) / Double(n)) : 1
        case .dailySign:         return isClaimed(m) ? 1 : 0
        case .dailyTrade:        return tradedToday ? 1 : 0
        }
    }

    /// 当前值（用于「3 / 10 笔」这类文案）
    func current(_ m: Mission) -> Double {
        switch m.kind {
        case .tradeCount: return Double(account.records.count)
        case .turnover:   return account.turnover
        case .holdKinds:  return Double(account.positions.count)
        default:          return progress(m)
        }
    }

    /// 可领取数量，用于红点
    var claimableCount: Int {
        Mission.all.filter { canClaim($0) }.count
    }

    /// 累计从任务里领到的奖励（USDT）
    var totalClaimed: Double {
        Mission.all
            .filter { isClaimed($0) }
            .reduce(0) { $0 + $1.reward }
    }

    // MARK: - 领取

    @discardableResult
    func claim(_ m: Mission) -> Bool {
        guard canClaim(m) else { return false }
        claimed[m.id] = Date()
        CryptoStore.shared.creditReward(m.reward)
        toast = m
        Juice.achievement()
        save()
        // 3 秒后自动收起。期间又领了别的任务就别抢它的位置
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast?.id == m.id { toast = nil }
        }
        return true
    }

    /// 一键领取所有可领的任务
    @discardableResult
    func claimAll() -> Double {
        var sum: Double = 0
        for m in Mission.all where canClaim(m) {
            claimed[m.id] = Date()
            sum += m.reward
        }
        guard sum > 0 else { return 0 }
        CryptoStore.shared.creditReward(sum)
        save()
        Haptic.success()
        SoundKit.shared.fanfare()
        JuiceCenter.shared.fire(.jackpot)
        return sum
    }

    func clearToast() { toast = nil }

    /// 数据变动后让界面重算进度
    func refresh() { objectWillChange.send() }

    /// 重开一局
    func reset() {
        claimed = [:]
        toast = nil
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(claimed) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}
