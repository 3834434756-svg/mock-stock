import Foundation
import Combine

/// 游戏模式的本地行情引擎。
///
/// 核心思路：**只读一次真实盘后数据当种子，之后价格完全由本地随机游走驱动**。
/// 所以它永不休市、周末照跑、节假日照跑 —— 你想什么时候玩就什么时候玩。
///
/// 时间被加速：默认现实 5 分钟 = 游戏内 1 个交易日，
/// 这样你能亲眼看着日 K 一根一根长出来，而不是干等一整天。
@MainActor
final class GameEngine: ObservableObject {
    static let shared = GameEngine()

    /// 单个标的的模拟状态
    struct Sim {
        let code: String
        var name: String
        /// 真实收盘价（种子）。价格会围绕它做轻微均值回归，避免飘到离谱
        let base: Double
        var price: Double
        var prevClose: Double
        var open: Double
        var high: Double
        var low: Double
        /// 每 tick 的波动率
        let volatility: Double
        /// 事件冲击残留，逐 tick 衰减
        var drift: Double
        var volume: Double

        var change: Double { price - prevClose }
        var changePercent: Double { prevClose > 0 ? (price - prevClose) / prevClose * 100 : 0 }
    }

    @Published private(set) var sims: [String: Sim] = [:]
    /// 真实历史日线（种子时缓存，避免反复请求）
    private(set) var realKlines: [String: [KLine]] = [:]
    /// 游戏内新生成的日线（最后一根是正在走的）
    @Published private(set) var bars: [String: [KLine]] = [:]
    @Published private(set) var isRunning = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var dayIndex = 0
    /// 每个标的见过的最低涨跌幅，用于「力挽狂澜」判定
    private(set) var lowestChange: [String: Double] = [:]

    /// 游戏内 1 天 = 现实多少秒
    let dayLength: TimeInterval = 300
    /// tick 间隔（秒）
    private let baseInterval: TimeInterval = 1.5

    /// 时间加速倍率
    @Published var speed: Double = 1.0 {
        didSet { if isRunning { restartTimer() } }
    }

    private var timer: Timer?
    private var lastTick = Date()
    private var rng = SystemRandomNumberGenerator()

    private init() {}

    // MARK: - 生命周期

    /// 用真实行情做种子。已在跑的标的保留当前价，只补新标的
    func seed(_ quotes: [Quote]) {
        for q in quotes where q.price > 0 {
            if var s = sims[q.code] {
                s.name = q.name
                sims[q.code] = s
            } else {
                let vol = Self.volatility(for: Market(code: q.code))
                sims[q.code] = Sim(
                    code: q.code,
                    name: q.name,
                    base: q.price,
                    price: q.price,
                    prevClose: q.prevClose > 0 ? q.prevClose : q.price,
                    open: q.price,
                    high: q.price,
                    low: q.price,
                    volatility: vol,
                    drift: 0,
                    volume: 0
                )
                bars[q.code] = [Self.newBar(date: Date(), price: q.price)]
                lowestChange[q.code] = 0
            }
        }
    }

    /// 缓存真实历史日线，供详情页画图用
    func cacheKlines(_ klines: [KLine], for code: String) {
        guard realKlines[code] == nil, !klines.isEmpty else { return }
        realKlines[code] = klines
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastTick = Date()
        restartTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// 重开一局
    func reset() {
        stop()
        sims = [:]
        bars = [:]
        realKlines = [:]
        lowestChange = [:]
        elapsed = 0
        dayIndex = 0
        lastTick = Date()
    }

    private func restartTimer() {
        timer?.invalidate()
        let interval = max(0.25, baseInterval / max(0.25, speed))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: - 推进

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        elapsed += dt

        // 跨日：结算上一根日线，开一根新的
        while elapsed >= Double(dayIndex + 1) * dayLength {
            rollDay()
        }

        for code in Array(sims.keys) {
            guard var s = sims[code] else { continue }
            let g = gaussian()
            var ret = s.volatility * g
            ret += s.drift
            // 轻微均值回归，避免价格飘到不认识的数字
            if s.price > 0 { ret += (s.base / s.price - 1) * 0.0018 }
            let next = s.price * (1 + ret)
            s.price = max(s.base * 0.05, min(s.base * 20, next))
            s.drift *= 0.985
            s.high = max(s.high, s.price)
            s.low = min(s.low, s.price)
            s.volume += abs(ret) * 2_000_000
            sims[code] = s

            let pct = s.changePercent
            lowestChange[code] = min(lowestChange[code] ?? 0, pct)
            updateCurrentBar(s)
        }
    }

    private func updateCurrentBar(_ s: Sim) {
        var list = bars[s.code] ?? [Self.newBar(date: Date(), price: s.price)]
        guard !list.isEmpty else { return }
        var last = list[list.count - 1]
        last.close = s.price
        last.high = max(last.high, s.price)
        last.low = min(last.low, s.price)
        list[list.count - 1] = last
        bars[s.code] = list
    }

    private func rollDay() {
        dayIndex += 1
        for code in Array(sims.keys) {
            guard var s = sims[code] else { continue }
            s.prevClose = s.price
            s.open = s.price
            s.high = s.price
            s.low = s.price
            s.volume = 0
            sims[code] = s
            var list = bars[code] ?? []
            list.append(Self.newBar(date: Date(), price: s.price))
            // 只留最近 120 根，避免无限增长
            if list.count > 120 { list = Array(list.suffix(120)) }
            bars[code] = list
        }
    }

    // MARK: - 冲击

    /// 对单个标的施加冲击（百分比）
    func shock(code: String, percent: Double) {
        guard var s = sims[code] else { return }
        s.price = max(s.base * 0.05, min(s.base * 20, s.price * (1 + percent / 100)))
        s.high = max(s.high, s.price)
        s.low = min(s.low, s.price)
        sims[code] = s
        updateCurrentBar(s)
    }

    /// 对全市场施加冲击
    func shockAll(percent: Double) {
        for code in Array(sims.keys) { shock(code: code, percent: percent) }
    }

    /// 给某个标的注入持续漂移（用于「力挽狂澜」这类需要后续发酵的场景）
    func injectDrift(code: String, perTick: Double, ticks: Int) {
        guard var s = sims[code] else { return }
        s.drift = perTick
        sims[code] = s
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Double(ticks) * 1_500_000_000))
            if var t = self.sims[code] { t.drift = 0; self.sims[code] = t }
        }
    }

    // MARK: - 读取

    func price(of code: String) -> Double? { sims[code]?.price }

    func prices() -> [String: Double] {
        var out: [String: Double] = [:]
        for (k, v) in sims { out[k] = v.price }
        return out
    }

    /// 组装成标准 Quote，界面层完全不用区分真假行情
    func quotes(for codes: [String]) -> [Quote] {
        codes.compactMap { code in
            guard let s = sims[code] else { return nil }
            return Quote(
                code: s.code,
                name: s.name,
                price: s.price,
                prevClose: s.prevClose,
                open: s.open,
                high: s.high,
                low: s.low,
                change: s.change,
                changePercent: s.changePercent,
                time: Self.stamp()
            )
        }
    }

    func quote(for code: String) -> Quote? { quotes(for: [code]).first }

    /// 真实历史 + 游戏内生成
    func klines(for code: String, count: Int = 60) -> [KLine] {
        let real = realKlines[code] ?? []
        let game = bars[code] ?? []
        return Array((real + game).suffix(count))
    }

    /// 全部已跟踪代码
    var allCodes: [String] { Array(sims.keys) }

    /// 涨跌幅排行（供游戏模式的榜单用）
    func ranked() -> [Sim] {
        sims.values.sorted { $0.changePercent > $1.changePercent }
    }

    // MARK: - 工具

    private static func newBar(date: Date, price: Double) -> KLine {
        KLine(date: dayString(date), open: price, close: price, high: price, low: price, volume: 0)
    }

    private static func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: d)
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: Date())
    }

    /// 波动率按市场区分：加密货币最野，A股最稳
    private static func volatility(for market: Market) -> Double {
        switch market {
        case .aShare: return 0.0009
        case .hk:     return 0.0011
        case .us:     return 0.0016
        case .crypto: return 0.0034
        case .unknown: return 0.0010
        }
    }

    /// 标准正态随机数（Box-Muller）
    private func gaussian() -> Double {
        let u1 = Double.random(in: 1e-9...1, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    /// 游戏内已运行天数文案
    var elapsedText: String {
        let total = Int(elapsed)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
