// ArcadeEffects — feature 077 (A10-P03) T-A10-303 (FR-A10-320; clarifications 3 and 4; research D4; data-model
// "EffectCue", "Caps"). What the presenter shows, plays and makes felt after the run changed, derived purely from
// the last drawn run and the current one; nothing here changes the game.
//
// `ArcadeEffects.plan(previous:current:)` lists, in this order:
// 1. One cue per new collision event, oldest first: a `pickup` at the orb's last known position (its position in
//    `previous.objects`; the event holds only the step, the object id and the kind, and a picked-up orb is removed,
//    so the previous run is where the position is; the player's centre when it is not found) and a `hit` at the
//    player's centre. New events are the last (current.eventCount − previous.eventCount) of the kept events (at most
//    `GameRun.maxEvents` are kept, so more than 256 new events yield only the kept ones).
// 2. A `wave` cue when the wave number increased, at the top centre of the field (4.5, 16), where the sweep starts.
// 3. An `over` cue when the run became over, at the player's centre.
// Caps (clarification 3: "at most 3 bursts and 2 sounds start per step"): the first 3 cues are `visual`; the first 2
// carry their `sound` and its haptic (the haptic travels with the sound, so a dropped sound drops its haptic too).
// Cues beyond both caps are dropped, never delayed. No plan is made without a previous run (a restored or first drawn
// state is not new), for an unchanged run, or when `current` is not a continuation of `previous` (a new run: fewer
// steps or fewer events).
//
// `ArcadeSound` holds the four sound shapes of clarification 4 as plain values (the experience turns them into
// `VisualCoreAudioDSP.SoundEffect`s; the core does not depend on the audio modules), each with its haptic kind:
// pickup sine 880 → 1,320 Hz 0.12 s gain 0.5 impactLight; hit triangle 160 → 60 Hz 0.25 s noise 0.3 gain 0.7
// impactHeavy; wave sine 300 → 600 Hz 0.4 s gain 0.3 selection; over triangle 440 → 220 Hz 0.5 s gain 0.5 error.
// Attack and release are 5 ms each. The limits of data-model "SoundEffect" are checked by `ArcadeSound.validate()`.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// One synthesized sound shape with the haptic that accompanies it.
public struct ArcadeSound: Equatable, Sendable, Identifiable {
    /// The waveforms a sound effect may use.
    public static let waveforms: Set<String> = ["sine", "triangle", "square"]
    /// The allowed start and end frequency in Hz.
    public static let frequencyRange: ClosedRange<Double> = 40...4_000
    /// The allowed duration in seconds.
    public static let durationRange: ClosedRange<Double> = 0.02...1
    /// The shortest attack and release in seconds.
    public static let minimumFade = 0.002
    /// The attack and release every arcade sound uses, in seconds.
    public static let fade = 0.005
    /// The allowed noise mix.
    public static let noiseRange: ClosedRange<Double> = 0...1
    /// The allowed gain.
    public static let gainRange: ClosedRange<Double> = 0...0.9

    /// The cue this sound belongs to: "pickup", "hit", "wave" or "over".
    public var id: String
    /// The waveform name: "sine", "triangle" or "square".
    public var waveform: String
    /// The frequency at the start in Hz.
    public var startFrequency: Double
    /// The frequency at the end in Hz (swept linearly).
    public var endFrequency: Double
    /// The length in seconds.
    public var duration: Double
    /// The fade-in in seconds.
    public var attack: Double
    /// The fade-out in seconds.
    public var release: Double
    /// The noise mix, 0…1.
    public var noise: Double
    /// The peak gain, 0…0.9.
    public var gain: Double
    /// The haptic played with the sound (when haptics are on).
    public var haptic: HapticKind

    /// Creates a sound shape (validity is checked by ``validate()``).
    public init(id: String, waveform: String, startFrequency: Double, endFrequency: Double, duration: Double,
                attack: Double = ArcadeSound.fade, release: Double = ArcadeSound.fade, noise: Double = 0,
                gain: Double, haptic: HapticKind) {
        self.id = id; self.waveform = waveform; self.startFrequency = startFrequency
        self.endFrequency = endFrequency; self.duration = duration; self.attack = attack; self.release = release
        self.noise = noise; self.gain = gain; self.haptic = haptic
    }

    /// Orb pickup: a rising sine chime with a light tap.
    public static let pickup = ArcadeSound(id: "pickup", waveform: "sine", startFrequency: 880, endFrequency: 1_320,
                                           duration: 0.12, gain: 0.5, haptic: .impactLight)
    /// Hazard hit: a falling triangle thud with noise and a heavy tap.
    public static let hit = ArcadeSound(id: "hit", waveform: "triangle", startFrequency: 160, endFrequency: 60,
                                        duration: 0.25, noise: 0.3, gain: 0.7, haptic: .impactHeavy)
    /// Wave start: a soft rising sine sweep with a selection tick.
    public static let wave = ArcadeSound(id: "wave", waveform: "sine", startFrequency: 300, endFrequency: 600,
                                         duration: 0.4, gain: 0.3, haptic: .selection)
    /// Game over: a falling triangle tone with an error haptic.
    public static let over = ArcadeSound(id: "over", waveform: "triangle", startFrequency: 440, endFrequency: 220,
                                         duration: 0.5, gain: 0.5, haptic: .error)
    /// The four sounds in cue order.
    public static let all: [ArcadeSound] = [pickup, hit, wave, over]

    /// The sound's problems against the data-model limits, empty when it is valid: a known waveform, frequencies
    /// 40…4,000 Hz, duration 0.02…1 s, attack and release ≥ 2 ms and together within the duration, noise 0…1,
    /// gain 0…0.9, all finite.
    public func validate() -> [String] {
        var problems: [String] = []
        if id.isEmpty { problems.append("the sound has no id") }
        if !Self.waveforms.contains(waveform) { problems.append("waveform \(waveform) is unknown") }
        for (name, value) in [("start frequency", startFrequency), ("end frequency", endFrequency)]
        where !value.isFinite || !Self.frequencyRange.contains(value) {
            problems.append("\(name) \(value) is outside 40…4,000 Hz")
        }
        if !duration.isFinite || !Self.durationRange.contains(duration) {
            problems.append("duration \(duration) is outside 0.02…1 s")
        }
        if !attack.isFinite || attack < Self.minimumFade { problems.append("attack \(attack) is below 2 ms") }
        if !release.isFinite || release < Self.minimumFade { problems.append("release \(release) is below 2 ms") }
        if attack + release > duration { problems.append("attack and release exceed the duration") }
        if !noise.isFinite || !Self.noiseRange.contains(noise) { problems.append("noise \(noise) is outside 0…1") }
        if !gain.isFinite || !Self.gainRange.contains(gain) { problems.append("gain \(gain) is outside 0…0.9") }
        return problems
    }
}

/// One effect the presenter starts.
public struct EffectCue: Equatable, Sendable {
    /// What the cue is for.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// An orb was collected: a burst of cyan particles.
        case pickup
        /// A hazard cost a life: a red ring (and tint unless reduced flashing) with particles.
        case hit
        /// A new wave began: a horizontal cyan sweep.
        case wave
        /// The run became over.
        case over
    }

    /// What the cue is for.
    public var kind: Kind
    /// Where the visual effect starts, in game units.
    public var position: Vec2
    /// True when the visual effect starts (within the cap of ``ArcadeEffects/maxVisualCues``).
    public var visual: Bool
    /// The sound to play, or nil when the cap of ``ArcadeEffects/maxSoundCues`` was reached.
    public var sound: ArcadeSound?
    /// The haptic to play with the sound (nil exactly when ``sound`` is nil).
    public var haptic: HapticKind? { sound?.haptic }

    /// Creates a cue.
    public init(kind: Kind, position: Vec2, visual: Bool, sound: ArcadeSound?) {
        self.kind = kind; self.position = position; self.visual = visual; self.sound = sound
    }

    /// The sound shape of each kind.
    public static func sound(for kind: Kind) -> ArcadeSound {
        switch kind {
        case .pickup: return .pickup
        case .hit: return .hit
        case .wave: return .wave
        case .over: return .over
        }
    }
}

/// Derives the effect cues of a run change (see the file header).
public enum ArcadeEffects {
    /// The most visual effects started per plan (per step).
    public static let maxVisualCues = 3
    /// The most sounds (each with its haptic) started per plan (per step).
    public static let maxSoundCues = 2
    /// Where the wave sweep starts: the top centre of the field.
    public static let waveSweepPosition = Vec2(GameRun.fieldWidth / 2, GameRun.fieldHeight)

    /// The cues of the change from `previous` to `current`, in event order and capped; empty without a previous run,
    /// for an unchanged run or for a run that does not continue `previous`.
    public static func plan(previous: GameRun?, current: GameRun) -> [EffectCue] {
        guard let previous, current.step >= previous.step, current.eventCount >= previous.eventCount else {
            return []
        }
        var kinds: [(EffectCue.Kind, Vec2)] = []
        let newCount = min(current.eventCount - previous.eventCount, current.events.count)
        for event in current.events.suffix(newCount) {
            switch event.kind {
            case .pickup:
                let position = previous.objects.first(where: { $0.id == event.objectId })?.position
                    ?? current.player.center
                kinds.append((.pickup, position))
            case .hit:
                kinds.append((.hit, current.player.center))
            }
        }
        if current.wave > previous.wave { kinds.append((.wave, waveSweepPosition)) }
        if current.over && !previous.over { kinds.append((.over, current.player.center)) }

        var cues: [EffectCue] = []
        for (index, (kind, position)) in kinds.enumerated() {
            let visual = index < maxVisualCues
            let sound = index < maxSoundCues ? EffectCue.sound(for: kind) : nil
            guard visual || sound != nil else { break }
            cues.append(EffectCue(kind: kind, position: position, visual: visual, sound: sound))
        }
        return cues
    }
}
