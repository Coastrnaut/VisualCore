// SoundEffectPlayer — feature 077 (A10-P03) T-A10-302 (FR-A10-301, FR-A10-302; SC-A10-302, SC-A10-303; gap
// G-SOUNDFX; research D2): plays synthesised `SoundEffect`s on a few overlapping voices of the system audio engine in
// the ambient session category (mixes with other audio, follows the silent switch, never opens the input, so no
// microphone permission). The engine starts lazily on the first play; interruptions and moving to the background
// stop every voice. The output sits behind an internal seam so tests exercise the voice bookkeeping without audio.
import AVFAudio
import Foundation
import UIKit
import VisualCoreAudioDSP

/// Where the player's voices go (internal seam, research D2): the system engine in the app, a double in tests.
@MainActor
protocol SoundEffectOutput: AnyObject {
    /// Configures the session and starts the engine if it is not running; cheap when it already runs.
    /// - Throws: when the session or the engine cannot start.
    func start() throws
    /// Schedules `samples` (cached by `id`) on `voice` and starts it.
    /// - Parameter completion: called once, on any thread, when the buffer finished playing or was stopped.
    /// - Returns: `false` when the voice could not be scheduled.
    func schedule(_ samples: [Float], id: String, voice: Int, completion: @escaping @Sendable () -> Void) -> Bool
    /// Stops every voice and pauses the engine.
    func stopAll()
    /// Drops the engine (after a media-services reset); the next `start()` builds a new one.
    func reset()
}

/// Plays short synthesised sound effects on at most ``voiceCount`` overlapping voices (FR-A10-301, FR-A10-302).
///
/// Each effect is rendered by ``SoundEffectSynth`` once per id and kept; later plays with the same id reuse the
/// buffer (the id names the effect, so one id should always be used with the same effect). A request while every
/// voice is busy is dropped. The audio session category is ``sessionCategory`` (ambient); the input node is never
/// used, so playing never asks for the microphone. An audio-session interruption, a media-services reset or the app
/// moving to the background calls ``stopAll()``.
@MainActor
public final class SoundEffectPlayer {
    /// The audio session category the player sets: ambient (mixes with other audio, silenced by the silent switch,
    /// no input).
    public static let sessionCategory: AVAudioSession.Category = .ambient

    /// Number of voices (simultaneous effects).
    public let voiceCount: Int
    /// Sample rate of the rendered buffers in hertz.
    public let sampleRate: Double

    /// Whether ``play(_:id:)`` plays anything; setting it to `false` also stops every voice.
    public var isEnabled = true {
        didSet { if !isEnabled { stopAll() } }
    }

    /// Number of voices currently playing an effect.
    public var activeVoices: Int { busy.reduce(0) { $0 + ($1 ? 1 : 0) } }

    /// Number of effect ids whose buffer has been rendered and kept (for tests).
    var cachedEffectCount: Int { cache.count }

    private let output: any SoundEffectOutput
    private let center: NotificationCenter
    private var busy: [Bool]
    private var generations: [UInt64]
    private var cache: [String: [Float]] = [:]
    private var observers: [any NSObjectProtocol] = []

    /// Creates a player over the system audio engine; nothing touches the audio session until the first play.
    /// - Parameters:
    ///   - voices: simultaneous effects (at least 1; 4 by default).
    ///   - sampleRate: sample rate of the rendered buffers in hertz (48,000 by default; invalid values use 48,000).
    public convenience init(voices: Int = 4, sampleRate: Double = 48_000) {
        let voices = max(1, voices)
        let rate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        self.init(voices: voices, sampleRate: rate, output: SystemSoundEffectOutput(voices: voices, sampleRate: rate),
                  center: .default)
    }

    /// Creates a player over `output`, observing interruptions and backgrounding on `center` (tests inject both).
    init(voices: Int, sampleRate: Double, output: any SoundEffectOutput, center: NotificationCenter) {
        voiceCount = max(1, voices)
        self.sampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        self.output = output
        self.center = center
        busy = Array(repeating: false, count: voiceCount)
        generations = Array(repeating: 0, count: voiceCount)
        let names: [Notification.Name] = [AVAudioSession.interruptionNotification,
                                          AVAudioSession.mediaServicesWereResetNotification,
                                          UIApplication.didEnterBackgroundNotification]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let event = AudioSessionEvent(name: notification.name, userInfo: notification.userInfo)
                let background = notification.name == UIApplication.didEnterBackgroundNotification
                MainActor.assumeIsolated { self?.handle(event, background: background) }
            }
        }
    }

    isolated deinit {
        for observer in observers { center.removeObserver(observer) }
        output.stopAll()
    }

    /// Plays `effect` on a free voice.
    /// - Parameters:
    ///   - effect: the effect; rendered on the first play of `id` and kept.
    ///   - id: names the effect's buffer in the cache.
    /// - Returns: `true` when the effect started; `false` when the player is disabled, the effect is invalid, every
    ///   voice is busy, or the session or engine could not start (no crash).
    @discardableResult
    public func play(_ effect: SoundEffect, id: String) -> Bool {
        guard isEnabled, effect.isValid, let voice = busy.firstIndex(of: false) else { return false }
        let samples: [Float]
        if let cached = cache[id] {
            samples = cached
        } else {
            samples = SoundEffectSynth.render(effect, sampleRate: sampleRate)
            guard !samples.isEmpty else { return false }
            cache[id] = samples
        }
        do {
            try output.start()
        } catch {
            return false
        }
        generations[voice] &+= 1
        busy[voice] = true
        let completion = Self.makeCompletion(player: self, voice: voice, generation: generations[voice])
        guard output.schedule(samples, id: id, voice: voice, completion: completion) else {
            busy[voice] = false
            return false
        }
        return true
    }

    /// Stops every voice; afterwards ``activeVoices`` is 0. Safe to call at any time.
    public func stopAll() {
        for voice in busy.indices {
            generations[voice] &+= 1
            busy[voice] = false
        }
        output.stopAll()
    }

    private func voiceFinished(_ voice: Int, generation: UInt64) {
        guard generations.indices.contains(voice), generations[voice] == generation else { return }
        busy[voice] = false
    }

    private func handle(_ event: AudioSessionEvent?, background: Bool) {
        if background || event == .interruptionBegan {
            stopAll()
        } else if event == .mediaServicesReset {
            stopAll()
            output.reset()
        }
    }

    /// Builds the completion outside the main actor: it is called on the audio thread and hops back to the main
    /// actor, where a stale generation (a voice stopped and reused since) is ignored.
    private nonisolated static func makeCompletion(player: SoundEffectPlayer, voice: Int,
                                                   generation: UInt64) -> @Sendable () -> Void {
        { [weak player] in
            Task { @MainActor in player?.voiceFinished(voice, generation: generation) }
        }
    }
}

/// The system output: an `AVAudioEngine` with one `AVAudioPlayerNode` per voice connected to the main mixer, in the
/// ambient session category. The input node is never accessed.
@MainActor
final class SystemSoundEffectOutput: SoundEffectOutput {
    private let voices: Int
    private let format: AVAudioFormat?
    private var engine: AVAudioEngine?
    private var nodes: [AVAudioPlayerNode] = []
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    /// Creates an idle output; nothing touches the audio session until `start()`.
    init(voices: Int, sampleRate: Double) {
        self.voices = max(1, voices)
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    }

    isolated deinit { tearDown() }

    func start() throws {
        if let engine, engine.isRunning { return }
        guard let format else { throw AudioSourceError.engineFailed("no sound-effect format") }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(SoundEffectPlayer.sessionCategory, mode: .default, options: [])
        try session.setActive(true)
        let engine: AVAudioEngine
        if let existing = self.engine {
            engine = existing
        } else {
            engine = AVAudioEngine()
            let mixer = engine.mainMixerNode
            nodes = (0..<voices).map { _ in
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: mixer, format: format)
                return node
            }
            engine.prepare()
            self.engine = engine
        }
        try engine.start()
    }

    func schedule(_ samples: [Float], id: String, voice: Int, completion: @escaping @Sendable () -> Void) -> Bool {
        guard nodes.indices.contains(voice), let buffer = buffer(for: id, samples: samples) else { return false }
        let node = nodes[voice]
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack,
                            completionHandler: { _ in completion() })
        node.play()
        return true
    }

    func stopAll() {
        for node in nodes { node.stop() }
        engine?.pause()
    }

    func reset() { tearDown() }

    private func buffer(for id: String, samples: [Float]) -> AVAudioPCMBuffer? {
        if let cached = buffers[id] { return cached }
        guard let format, !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        buffers[id] = buffer
        return buffer
    }

    private func tearDown() {
        for node in nodes { node.stop() }
        if let engine {
            engine.stop()
            for node in nodes { engine.detach(node) }
        }
        nodes = []
        engine = nil
    }
}
