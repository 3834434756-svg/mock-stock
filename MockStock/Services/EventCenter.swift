import Foundation
import Combine

/// 平行宇宙事件中心。
///
/// 只在游戏模式跑。每隔一段时间掷一次骰子，挑一个标的（优先你持有或关注的）
/// 或者整个市场，弹出一次决策。选完之后冲击会打到本地模拟价格上 ——
/// 也就是说，事件真的会改变走势，不是纯弹窗。
@MainActor
final class EventCenter: ObservableObject {
    static let shared = EventCenter()

    @Published var active: MarketEvent?
    /// 事件目标名称（展示用）
    @Published var activeTargetName: String = ""
    @Published var lastResult: String?
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var isRunning = false

    struct LogEntry: Identifiable {
        let id = UUID()
        let headline: String
        let choice: String
        let good: Bool
        let date: Date
    }

    /// 平均触发间隔（秒）。实际会在 0.6x ~ 1.5x 之间浮动，避免节奏太规律
    var interval: TimeInterval = 50

    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        schedule()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func schedule() {
        timer?.invalidate()
        let jitter = Double.random(in: 0.6...1.5, using: &rng)
        let next = max(15, interval * jitter)
        timer = Timer.scheduledTimer(withTimeInterval: next, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireNow()
                if self?.isRunning == true { self?.schedule() }
            }
        }
    }

    /// 立刻触发一次（也用于「手动召唤」按钮）
    func fireNow() {
        guard active == nil else { return }
        let engine = GameEngine.shared
        let codes = engine.allCodes
        guard !codes.isEmpty else { return }

        // 30% 全市场事件
        if Double.random(in: 0...1, using: &rng) < 0.3,
           let evt = EventPool.marketWide.randomElement(using: &rng) {
            active = evt
            activeTargetName = "全市场"
            Juice.event()
            return
        }

        // 优先挑持仓 / 自选里的标的
        let account = AccountStore.shared.account
        let watch = Set(MarketViewModelStore.watchlist)
        let preferred = codes.filter { code in
            account.position(for: code) != nil || watch.contains(code)
        }
        let pool = preferred.isEmpty ? codes : (Double.random(in: 0...1, using: &rng) < 0.75 ? preferred : codes)
        guard let code = pool.randomElement(using: &rng),
              let sim = engine.sims[code] else { return }

        active = EventPool.event(for: code, name: sim.name)
        activeTargetName = sim.name
        Juice.event()
    }

    /// 玩家做出决策
    func resolve(optionIndex: Int) {
        guard let evt = active, evt.options.indices.contains(optionIndex) else { return }
        let option = evt.options[optionIndex]
        let engine = GameEngine.shared
        let store = AccountStore.shared

        let targetName = evt.code.flatMap { engine.sims[$0]?.name } ?? "全市场"

        // 1) 价格冲击
        if let code = evt.code {
            engine.shock(code: code, percent: option.shock)
        } else {
            engine.shockAll(percent: option.shock)
        }

        // 2) 附加动作
        var actionNote = option.label
        if let code = evt.code, let sim = engine.sims[code] {
            switch option.action {
            case .none:
                break
            case .buyRatio(let r):
                let budget = store.budget(ratio: r)
                let shares = sim.price > 0 ? budget / sim.price : 0
                if shares > 0 {
                    let err = store.buy(code: code, name: sim.name, price: sim.price, shares: shares)
                    actionNote += err == nil ? "（已买入）" : "（买入失败：\(err!)）"
                }
            case .buyLeveraged(let r, let lev):
                let budget = store.budget(ratio: r)
                let shares = sim.price > 0 ? budget * lev / sim.price : 0
                if shares > 0 {
                    let err = store.buy(code: code, name: sim.name, price: sim.price,
                                        shares: shares, leverage: lev)
                    actionNote += err == nil ? "（已 \(Int(lev))x 杠杆买入）" : "（买入失败：\(err!)）"
                }
            case .sellRatio(let r):
                if let pos = store.account.position(for: code) {
                    let shares = pos.shares * r
                    _ = store.sell(code: code, price: sim.price, shares: shares)
                    actionNote += "（已卖出）"
                } else {
                    actionNote += "（无持仓）"
                }
            }
        }

        AchievementCenter.shared.recordEventDecision(good: option.countsAsGood)

        let moodText = option.shock > 0 ? "价格被拉高" : (option.shock < 0 ? "价格被打下去" : "价格没怎么动")
        lastResult = "\(targetName)：\(actionNote)，\(moodText)"

        log.insert(LogEntry(headline: evt.headline, choice: option.label,
                            good: option.countsAsGood, date: Date()), at: 0)
        if log.count > 50 { log = Array(log.prefix(50)) }

        // 这里**不**清空 active —— 交给弹窗先把结果展示完，再由它调 dismissCurrent()
    }

    /// 弹窗展示完结果（或直接被划掉）后调用
    func dismissCurrent() {
        active = nil
        lastResult = nil
    }

    func clearResult() { lastResult = nil }

    func reset() {
        stop()
        active = nil
        lastResult = nil
        log = []
    }
}

/// 供事件中心读取自选列表（避免直接依赖 ViewModel 单例）
enum MarketViewModelStore {
    static var watchlist: [String] {
        UserDefaults.standard.array(forKey: "mockstock.watchlist.v1") as? [String] ?? []
    }
}
