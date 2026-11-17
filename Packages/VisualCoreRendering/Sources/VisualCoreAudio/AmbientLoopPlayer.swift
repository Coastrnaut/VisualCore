// AmbientLoopPlayer — feature 155 (A21-P04) T-A21-403 (FR-A21-405; gap G-LOOP; spec Clarification Q1): plays one
// `AmbientLoopRecipe`, rendered once, looped on an AVAudioPlayerNode of its own engine in the ambient session
// category (mixes with other audio, follows the silent switch, never opens the input, so no microphone permission).
// The volume is the player node's volume, so a change is immediate and never re-renders the buffer. Interruptions,
// media-services resets and moving to the background stop the loop. Modelled on `SoundEffectPlayer` (feature 077);
// the output sits behind an internal seam so tests exercise the state without audio. No render block: the buffer is
// scheduled with `.loops`, so nothing runs on the audio thread that `scripts/check_audio_hot_path.py` would check.
import AVFAudio
import Foundation
import UIKit
import VisualCoreAudioDSP

/// Where the loop goes (internal seam): the system engine in the app, a double in tests.
@MainActor
protocol AmbientLoopOutput: AnyObject {
    /// Configures the session and starts the engine if it is not running; cheap when it already runs.
    /// - Throws: when the session or the engine cannot start.
    func start() throws
    /// Schedules `samples` looped at `volume` and starts the player node.
    /// - Returns: `false` when the loop could not be scheduled.
    func playLooped(_ samples: [Float], volume: Float) -> Bool
    /// Sets the player node's volume (0…1); takes effect at once.
    func setVolume(_ volume: Float)
    /// Stops the player node and pauses the engine.
    func stop()
    /// Drops the engine (after a media-services reset); the next `start()` builds a new one.
    func reset()
}

/// Plays a quiet synthesised ambient loop, seamlessly repeated, on the ambient audio session (FR-A21-405).
///
/// The recipe is rendered by ``AmbientLoopSynth`` once, on the first ``play()``, and kept. ``volume`` is the player
/// node's volume, clamped to 0…1, and a non-finite value is ignored. The audio session category is
/// ``sessionCategory`` (ambient); the input node is never used, so playing never asks for the microphone. An
/// audio-session interruption, a media-services reset or the app moving to the background calls ``stop()``; the loop
/// does not restart by itself.
@MainActor
public final class AmbientLoopPlayer {
    /// The audio session category the player sets: ambient (mixes with other audio, silenced by the silent switch,
    /// no input).
    public static let sessionCategory: AVAudioSession.Category = .ambient

    /// The recipe the player renders and loops.
    public let recipe: AmbientLoopRecipe

    /// Whether ``play()`` plays anything; setting it to `false` also stops the loop.
    public var isEnabled = true {
        didSet { if !isEnabled { stop() } }
    }

    /// Whether the loop is playing.
    public private(set) var isPlaying = false

    /// The loop's volume on the player node, 0…1 (1 by default). A value outside the range is clamped; a non-finite
    /// value is ignored and the previous volume stays. A change applies at once, without re-rendering.
    public var volume: Float {
        get { storedVolume }
        set {
            guard newValue.isFinite else { return }
            storedVolume = min(1, max(0, newValue))
            output.setVolume(storedVolume)
        }
    }

    /// Number of times the recipe has been rendered (for tests; at most 1).
    private(set) var renderCount = 0

    private let output: any AmbientLoopOutput
    private let center: NotificationCenter
    private var storedVolume: Float = 1
    private var samples: [Float]?
    private var observers: [any NSObjectProtocol] = []

    /// Creates a player over the system audio engine; nothing touches the audio session until the first play.
    /// - Parameter recipe: the loop to play (``AmbientLoopRecipe/gentle`` by default).
    public convenience init(recipe: AmbientLoopRecipe = .gentle) {
        self.init(recipe: recipe, output: SystemAmbientLoopOutput(sampleRate: AmbientLoopRecipe.sampleRate),
                  center: .default)
    }

    /// Creates a player over `output`, observing interruptions and backgrounding on `center` (tests inject both).
    init(recipe: AmbientLoopRecipe, output: any AmbientLoopOutput, center: NotificationCenter) {
        self.recipe = recipe
        self.output = output
        self.center = center
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
        output.stop()
    }

    /// Starts the loop; does nothing more when it already plays.
    /// - Returns: `true` when the loop plays; `false` when the player is disabled, the recipe is invalid, or the
    ///   session or engine could not start (no crash).
    @discardableResult
    public func play() -> Bool {
        guard isEnabled else { return false }
        if isPlaying { return true }
        guard let samples = renderedSamples() else { return false }
        do {
            try output.start()
        } catch {
            return false
        }
        guard output.playLooped(samples, volume: storedVolume) else { return false }
        isPlaying = true
        return true
    }

    /// Stops the loop; afterwards ``isPlaying`` is `false`. Safe to call at any time.
    public func stop() {
        isPlaying = false
        output.stop()
    }

    private func renderedSamples() -> [Float]? {
        if let samples { return samples }
        let rendered = AmbientLoopSynth.render(recipe)
        guard !rendered.isEmpty else { return nil }
        renderCount += 1
        samples = rendered
        return rendered
    }

    private func handle(_ event: AudioSessionEvent?, background: Bool) {
        if background || event == .interruptionBegan {
            stop()
        } else if event == .mediaServicesReset {
            stop()
            output.reset()
        }
    }
}

/// The system output: an `AVAudioEngine` with one `AVAudioPlayerNode` connected to the main mixer, in the ambient
/// session category, the buffer scheduled with `.loops`. The input node is never accessed.
@MainActor
final class SystemAmbientLoopOutput: AmbientLoopOutput {
    private let format: AVAudioFormat?
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?
    private var volume: Float = 1

    /// Creates an idle output; nothing touches the audio session until `start()`.
    init(sampleRate: Double) {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    }

    isolated deinit { tearDown() }

    func start() throws {
        if let engine, engine.isRunning { return }
        guard let format else { throw AudioSourceError.engineFailed("no ambient-loop format") }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(AmbientLoopPlayer.sessionCategory, mode: .default, options: [])
        try session.setActive(true)
        let engine: AVAudioEngine
        if let existing = self.engine {
            engine = existing
        } else {
            engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            node.volume = volume
            engine.prepare()
            self.engine = engine
            self.node = node
        }
        try engine.start()
    }

    func playLooped(_ samples: [Float], volume: Float) -> Bool {
        guard let node, let buffer = buffer(for: samples) else { return false }
        setVolume(volume)
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        node.play()
        return true
    }

    func setVolume(_ volume: Float) {
        self.volume = volume
        node?.volume = volume
    }

    func stop() {
        node?.stop()
        engine?.pause()
    }

    func reset() { tearDown() }

    private func buffer(for samples: [Float]) -> AVAudioPCMBuffer? {
        if let buffer { return buffer }
        guard let format, !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        self.buffer = buffer
        return buffer
    }

    private func tearDown() {
        node?.stop()
        if let engine {
            engine.stop()
            if let node { engine.detach(node) }
        }
        node = nil
        engine = nil
    }
}
