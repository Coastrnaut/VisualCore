// GardenSounds — feature 149 (A20-P05) T-A20-503 (FR-A20-501; clarification Q3; data-model.md "Sounds";
// contracts/quiet.md "Sound and haptics"; gap G-QUIET). Digital Zen Garden's three soft tones, made in code from
// VisualCoreAudioDSP (no sound file): `stroke` on a stroke commit, `place` on a stone placement and `remove` on a stone
// removal, each a quiet, low one-shot (0.12–0.25 s, 180–420 Hz, gain at most 0.2). The presenter talks to a
// `GardenSoundSink`; the default `GardenSoundPlayer` hands the tones to VisualCore's `SoundEffectPlayer` (ambient
// session, so the silent switch mutes it and other audio keeps playing), created on the first play with `isEnabled`
// following the sound switch (off at start, although the player's own default is on). Tests pass a recording sink.
import VisualCoreAudio
import VisualCoreAudioDSP

/// The three tones of the garden (feature 149).
enum GardenSound: String, CaseIterable, Sendable {
    /// A stroke was committed.
    case stroke
    /// A stone was placed.
    case place
    /// A stone was removed.
    case remove

    /// The shortest tone in seconds.
    static let shortest = 0.12
    /// The longest tone in seconds.
    static let longest = 0.25
    /// The frequencies every tone stays inside, in hertz.
    static let frequencies: ClosedRange<Double> = 180...420
    /// The loudest peak gain of a tone.
    static let maxGain = 0.2

    /// The id the tone is played under: `a20.<name>`.
    var id: String { "a20." + rawValue }

    /// The tone as a VisualCore sound effect: `stroke` a soft falling sine with a little noise (300 → 240 Hz, 0.18 s,
    /// gain 0.12), `place` a low falling sine (230 → 190 Hz, 0.22 s, gain 0.16) and `remove` a short rising sine
    /// (260 → 320 Hz, 0.14 s, gain 0.12); each fades in over 10 ms and out over most of its length.
    var effect: SoundEffect {
        switch self {
        case .stroke:
            return SoundEffect(waveform: .sine, startFrequency: 300, endFrequency: 240, duration: 0.18, attack: 0.01,
                               release: 0.12, noise: 0.15, gain: 0.12)
        case .place:
            return SoundEffect(waveform: .sine, startFrequency: 230, endFrequency: 190, duration: 0.22, attack: 0.01,
                               release: 0.16, noise: 0, gain: 0.16)
        case .remove:
            return SoundEffect(waveform: .sine, startFrequency: 260, endFrequency: 320, duration: 0.14, attack: 0.01,
                               release: 0.1, noise: 0, gain: 0.12)
        }
    }
}

/// Where the presenter's tones go (feature 149).
@MainActor
protocol GardenSoundSink: AnyObject {
    /// Whether a play makes a sound; the presenter sets it from the sound switch. Turning it off stops every tone.
    var isEnabled: Bool { get set }
    /// Plays `effect` under `id` now (nothing while disabled).
    func play(_ effect: SoundEffect, id: String)
    /// Stops every tone that is playing (suspension, background, teardown).
    func stopAll()
}

/// The default sink: VisualCore's `SoundEffectPlayer`, created on the first play while enabled (feature 149).
@MainActor
final class GardenSoundPlayer: GardenSoundSink {
    /// The player; nil before the first play.
    private(set) var player: SoundEffectPlayer?

    /// Whether a play makes a sound: off at start (the sound switch's default); passed on to the player.
    var isEnabled = false {
        didSet { player?.isEnabled = isEnabled }
    }

    /// A sink that is off and has no player yet.
    init() {}

    /// Plays `effect` under `id` through the player (made now if needed) while enabled.
    func play(_ effect: SoundEffect, id: String) {
        guard isEnabled else { return }
        let player = self.player ?? SoundEffectPlayer()
        player.isEnabled = isEnabled
        self.player = player
        _ = player.play(effect, id: id)
    }

    /// Stops every tone of the player.
    func stopAll() {
        player?.stopAll()
    }
}
