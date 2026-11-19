import AVFoundation

/// 8-bit sound effects synthesized on the fly (square/triangle waves + noise), like the web's WebAudio version.
final class Sfx {
    static let shared = Sfx()
    var enabled = true

    private struct Voice {
        var start: Double   // seconds, engine time
        var dur: Double
        var f0: Double
        var f1: Double?
        var vol: Double
        var wave: Int       // 0 square, 1 triangle, 2 noise
        var phase: Double = 0
    }

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var time: Double = 0          // advanced by the render thread
    private var sampleRate: Double = 44100
    private var started = false

    private init() {}

    private func ensureStarted() -> Bool {
        guard enabled else { return false }
        if started { return true }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let fmt = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = fmt.sampleRate > 0 ? fmt.sampleRate : 44100
        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let src = AVAudioSourceNode(format: mono) { [unowned self] _, _, frameCount, abl -> OSStatus in
            let buf = UnsafeMutableAudioBufferListPointer(abl)
            guard let out = buf.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.lock.lock()
            let dt = 1.0 / self.sampleRate
            for i in 0..<Int(frameCount) {
                var s = 0.0
                let t = self.time
                for v in self.voices.indices {
                    let local = t - self.voices[v].start
                    if local < 0 || local > self.voices[v].dur { continue }
                    let p = local / self.voices[v].dur
                    let f: Double
                    if let f1 = self.voices[v].f1 { f = self.voices[v].f0 * pow(f1 / self.voices[v].f0, p) } else { f = self.voices[v].f0 }
                    self.voices[v].phase += f * dt
                    let ph = self.voices[v].phase.truncatingRemainder(dividingBy: 1)
                    let w: Double
                    switch self.voices[v].wave {
                    case 1: w = ph < 0.5 ? ph * 4 - 1 : 3 - ph * 4
                    case 2: w = Double.random(in: -1...1) * (1 - p)
                    default: w = ph < 0.5 ? 1 : -1
                    }
                    // exponential-ish decay like gain.exponentialRampToValueAtTime
                    s += w * self.voices[v].vol * pow(0.0001 / self.voices[v].vol, p)
                }
                out[i] = Float(max(-1, min(1, s * 2.2)))
                self.time += dt
            }
            self.voices.removeAll { self.time - $0.start > $0.dur + 0.05 }
            self.lock.unlock()
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: mono)
        do { try engine.start() } catch { return false }
        node = src
        started = true
        return true
    }

    private func tone(_ f: Double, _ dur: Double, wave: Int = 0, vol: Double = 0.05, at: Double = 0, to: Double? = nil) {
        guard ensureStarted() else { return }
        lock.lock()
        voices.append(Voice(start: time + 0.01 + at, dur: dur, f0: f, f1: to, vol: vol, wave: wave))
        lock.unlock()
    }
    private func noise(_ dur: Double, vol: Double = 0.08, at: Double = 0) { tone(1, dur, wave: 2, vol: vol, at: at) }

    private let notes: [Double] = [523, 659, 784, 1047, 1319, 1568, 2093]

    func click() { tone(660, 0.05, vol: 0.03) }
    func tick(_ i: Double) { tone(220 + i * 40, 0.05, vol: 0.03) }
    func tear() { noise(0.25, vol: 0.12); tone(180, 0.2, vol: 0.04, to: 900) }
    func rip(_ p: Double) { noise(0.05, vol: 0.05 + p * 0.05); tone(300 + p * 500, 0.04, vol: 0.025) }
    func star() { tone(1568, 0.08, vol: 0.04); tone(2093, 0.16, vol: 0.04, at: 0.08) }
    func complete() { tone(784, 0.07, vol: 0.035); tone(1175, 0.12, vol: 0.035, at: 0.07) }
    func levelUp() { for (i, f) in [523.0, 659, 784, 1047].enumerated() { tone(f, 0.14, vol: 0.04, at: Double(i) * 0.09) } }
    func reveal(_ r: String) {
        let n = ["N": 2, "R": 3, "SR": 5, "SSR": 7][r] ?? 2
        for i in 0..<n { tone(notes[i], 0.12, vol: 0.045, at: Double(i) * 0.06) }
        if r == "SSR" {
            for f in [1047.0, 1319, 1568] { tone(f, 0.7, wave: 1, vol: 0.035, at: Double(n) * 0.06 + 0.05) }
            tone(2093, 0.5, vol: 0.03, at: Double(n) * 0.06 + 0.1)
        } else if r == "SR" {
            for f in [784.0, 988, 1175] { tone(f, 0.45, wave: 1, vol: 0.03, at: Double(n) * 0.06 + 0.04) }
        }
    }
}
