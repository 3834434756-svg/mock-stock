import Foundation
import AVFoundation

/// 音效合成器。
///
/// 全部波形现场算，**不需要任何音频资源文件** —— App 体积不会因为音效变大，
/// 也不用担心版权。引擎起不来时静默降级，绝不影响主流程。
final class SoundKit {
    static let shared = SoundKit()

    /// 总开关（「我的」页里可关）
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "mockstock.sound.on") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mockstock.sound.on") }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var ready = false

    private let sampleRate: Double = 44_100

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    // MARK: - 对外音效

    /// 小赚一声「叮」
    func coin() {
        play(notes: [Note(freq: 1046, dur: 0.06, gain: 0.5),
                     Note(freq: 1568, dur: 0.16, gain: 0.42)], waveform: .sine)
    }

    /// 大赚：金币掉落三连
    func jackpot() {
        play(notes: [Note(freq: 880, dur: 0.07, gain: 0.45),
                     Note(freq: 1174, dur: 0.07, gain: 0.45),
                     Note(freq: 1568, dur: 0.09, gain: 0.45),
                     Note(freq: 2093, dur: 0.26, gain: 0.40)], waveform: .sine)
    }

    /// 爆仓：下坠的警报
    func liquidation() {
        play(notes: [Note(freq: 392, dur: 0.14, gain: 0.42),
                     Note(freq: 311, dur: 0.14, gain: 0.42),
                     Note(freq: 233, dur: 0.34, gain: 0.46)], waveform: .saw)
    }

    /// 亏损提示
    func loss() {
        play(notes: [Note(freq: 330, dur: 0.10, gain: 0.34),
                     Note(freq: 262, dur: 0.18, gain: 0.34)], waveform: .triangle)
    }

    /// 成就解锁：小号角
    func fanfare() {
        play(notes: [Note(freq: 523, dur: 0.09, gain: 0.42),
                     Note(freq: 659, dur: 0.09, gain: 0.42),
                     Note(freq: 784, dur: 0.09, gain: 0.42),
                     Note(freq: 1046, dur: 0.30, gain: 0.46)], waveform: .triangle)
    }

    /// 下单成交
    func tick() {
        play(notes: [Note(freq: 1318, dur: 0.045, gain: 0.30)], waveform: .sine)
    }

    /// 事件警报
    func alert() {
        play(notes: [Note(freq: 740, dur: 0.12, gain: 0.40),
                     Note(freq: 740, dur: 0.12, gain: 0.40)], waveform: .square)
    }

    // MARK: - 合成

    private enum Waveform { case sine, triangle, saw, square }

    private struct Note {
        let freq: Double
        let dur: Double
        let gain: Double
    }

    private func play(notes: [Note], waveform: Waveform) {
        guard ready, enabled else { return }

        let total = notes.reduce(0) { $0 + $1.dur }
        let frames = AVAudioFrameCount(max(1, Int(total * sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let ch = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        var idx = 0
        for note in notes {
            let count = max(1, Int(note.dur * sampleRate))
            for i in 0..<count {
                if idx >= Int(frames) { break }
                let t = Double(i) / sampleRate
                let phase = 2 * Double.pi * note.freq * t
                // 简易 ADSR：起音 5ms，尾音淡出，避免爆音
                let attack = min(1.0, t / 0.005)
                let release = min(1.0, (note.dur - t) / 0.03)
                let env = max(0, min(attack, release))
                let wave: Double
                switch waveform {
                case .sine:     wave = sin(phase)
                case .triangle: wave = 2 / Double.pi * asin(sin(phase))
                case .saw:      wave = 2 * (t * note.freq - floor(t * note.freq + 0.5))
                case .square:   wave = sin(phase) >= 0 ? 1 : -1
                }
                ch[idx] = Float(wave * env * note.gain * 0.5)
                idx += 1
            }
        }

        // 播放到尾部时自动停止，避免节点累积
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
