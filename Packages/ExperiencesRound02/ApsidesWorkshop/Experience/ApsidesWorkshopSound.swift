// ApsidesWorkshopSound — feature 476 (R02-G18-06) T-R02G1806-005 (FR-R02G1806-006; SC-R02G1806-004; clarification
// Q4). When Apsides Workshop's sound plays, by the A21 rule (feature 156): exactly while the sound choice is on,
// the controls are on screen and the scene is active. Two sounds, both made in code:
//   - the ambient loop: its recipe comes from `ApsidesWorkshopSoundRecipe.recipe(play:)` (the actions left against
//     the budget, the quarters of the targets met in order and the stage); because a player fixes its recipe at
//     creation, the loop is rebuilt only when a new recipe is offered at a level opening, a tuning, undo, redo or the
//     play that changes the quarters, the root step or the stage, or the toggle turning on, never per frame;
//   - the audition of the pending orbit (`ApsidesWorkshopAudition`): its size tone with a fifth, a fourth or a 3 Hz
//     beat, 0.6 s per pending-orbit change, a new one replacing the last. The shared `AmbientLoopPlayer` only loops, so
//     the audition plays through the shared one-shot path, the `SoundEffectPlayer` of VisualCoreAudio (feature 077,
//     ambient session category, no input): each partial is one `SoundEffect` (a sine at the partial's frequency, 0.6 s,
//     a 2 ms attack and a release over the rest, the linear decay to silence, at the partial's gain), all started
//     together after the previous audition was stopped (`ApsidesWorkshopAuditionVoice.effects(_:)`). An audition is
//     played only while the loop may play (`shouldPlay`); turning the sound off, leaving the screen or the scene going
//     inactive also stops it.
// The sound choice off makes no player and touches no audio session. A `play()` that fails changes nothing else.
// Presentation only: no state, digest or snapshot sees it. Modelled on `CelestialEclipseLabSound` (feature 466).
#if os(iOS)
import ApsidesWorkshopCore
import VisualCoreAudio
import VisualCoreAudioDSP

/// What Apsides Workshop needs of a looping player (the tests' seam; ``AmbientLoopPlayer`` conforms).
@MainActor
protocol ApsidesWorkshopLoopPlaying: AnyObject {
    /// Whether `play()` plays anything.
    var isEnabled: Bool { get set }
    /// Whether the loop plays.
    var isPlaying: Bool { get }
    /// Starts the loop; false when it could not start.
    @discardableResult func play() -> Bool
    /// Stops the loop.
    func stop()
}

extension AmbientLoopPlayer: ApsidesWorkshopLoopPlaying {}

/// What Apsides Workshop needs of a one-shot player for the audition (the tests' seam;
/// ``ApsidesWorkshopAuditionVoice`` conforms over the shared ``SoundEffectPlayer``).
@MainActor
protocol ApsidesWorkshopAuditionPlaying: AnyObject {
    /// Stops the audition sounding, if any, and plays `audition` once; false when it could not start (an empty
    /// audition, a busy or failed audio engine).
    @discardableResult func play(_ audition: ApsidesWorkshopAudition) -> Bool
    /// Stops the audition sounding, if any.
    func stop()
}

/// The audition over the shared ``SoundEffectPlayer``: one sine ``SoundEffect`` per partial, started together.
@MainActor
final class ApsidesWorkshopAuditionVoice: ApsidesWorkshopAuditionPlaying {
    /// The voices of the player: the two partials of an audition plus one spare.
    static let voices = 3
    /// The attack of every partial, in seconds (the shortest fade the shared synthesiser allows: no click).
    static let attack: Double = SoundEffect.minimumFade

    /// The shared one-shot player; made on the first audition, so a silent session touches no audio.
    private var player: SoundEffectPlayer?

    /// An idle voice (no player until the first audition).
    init() {}

    /// The effects of `audition`, one per partial in order: a sine at the partial's frequency (no sweep), lasting
    /// ``ApsidesWorkshopAudition/duration`` (0.6 s), with an ``attack`` of 2 ms and a release over the rest, so the
    /// tone decays linearly to silence, at the partial's gain; no noise. Pure.
    static func effects(_ audition: ApsidesWorkshopAudition) -> [SoundEffect] {
        let duration: Double = ApsidesWorkshopAudition.duration
        return audition.partials.map { partial in
            SoundEffect(waveform: .sine, startFrequency: partial.frequency, endFrequency: partial.frequency,
                        duration: duration, attack: attack, release: duration - attack, noise: 0, gain: partial.gain)
        }
    }

    /// The cache id of `effect` in the shared player: its frequency and gain, exactly (one id per distinct effect).
    static func effectID(_ effect: SoundEffect) -> String {
        "apsides-workshop.audition.\(effect.startFrequency.bitPattern).\(effect.gain.bitPattern)"
    }

    /// Stops the previous audition and starts every partial of `audition`; true when every partial started.
    @discardableResult
    func play(_ audition: ApsidesWorkshopAudition) -> Bool {
        let effects: [SoundEffect] = Self.effects(audition)
        guard !effects.isEmpty else { return false }
        let player: SoundEffectPlayer = self.player ?? SoundEffectPlayer(voices: Self.voices)
        self.player = player
        player.stopAll()
        var all = true
        for effect in effects {
            if !player.play(effect, id: Self.effectID(effect)) { all = false }
        }
        return all
    }

    /// Stops the audition sounding, if any.
    func stop() { player?.stopAll() }
}

/// When Apsides Workshop's loop and audition play (see the file header).
@MainActor
final class ApsidesWorkshopSound {
    /// Makes a player for a recipe when one must play.
    let makePlayer: (AmbientLoopRecipe) -> any ApsidesWorkshopLoopPlaying
    /// Makes the audition's voice when the first audition must play.
    let makeVoice: () -> any ApsidesWorkshopAuditionPlaying
    /// The current player; nil until the loop first had to play.
    private(set) var player: (any ApsidesWorkshopLoopPlaying)?
    /// The recipe the current player plays.
    private(set) var playerRecipe: AmbientLoopRecipe?
    /// The recipe to play next (the latest one offered).
    private(set) var recipe: AmbientLoopRecipe
    /// The audition's voice; nil until the first audition had to play.
    private(set) var voice: (any ApsidesWorkshopAuditionPlaying)?
    /// Whether the person turned the sound on (off by default).
    private(set) var wanted = false
    /// Whether the controls view is on screen.
    private(set) var onScreen = false
    /// Whether the scene is active (true at start).
    private(set) var active = true
    /// Whether the last `play()` succeeded; false before one and after a stop.
    private(set) var started = false
    /// How many players were made (tests: rebuilds happen only at the named moments).
    private(set) var playersMade = 0
    /// How many auditions were played (tests: one per pending-orbit change while the sound may play, none otherwise).
    private(set) var auditionsPlayed = 0
    /// The last audition played, if any.
    private(set) var lastAudition: ApsidesWorkshopAudition?

    /// Whether the loop (and an audition) should play: `wanted && onScreen && active`.
    var shouldPlay: Bool { wanted && onScreen && active }

    /// A policy starting from `recipe`, making players with `makePlayer` (nil: `AmbientLoopPlayer(recipe:)`) and the
    /// audition's voice with `makeVoice` (nil: ``ApsidesWorkshopAuditionVoice``).
    init(recipe: AmbientLoopRecipe, makePlayer: ((AmbientLoopRecipe) -> any ApsidesWorkshopLoopPlaying)? = nil,
         makeVoice: (() -> any ApsidesWorkshopAuditionPlaying)? = nil) {
        self.recipe = recipe
        self.makePlayer = makePlayer ?? { AmbientLoopPlayer(recipe: $0) }
        self.makeVoice = makeVoice ?? { ApsidesWorkshopAuditionVoice() }
    }

    /// Sets whether the person wants the sound; turning it on plays the latest recipe.
    func setWanted(_ on: Bool) { update { wanted = on } }

    /// Sets whether the controls view is on screen.
    func setOnScreen(_ on: Bool) { update { onScreen = on } }

    /// Sets whether the scene is active.
    func setActive(_ on: Bool) { update { active = on } }

    /// Offers the recipe of a level opening or a change of the quarters, the root step or the stage: kept for the
    /// next start, and played at once (a new player) when the loop is playing and the recipe differs.
    func offer(_ next: AmbientLoopRecipe) {
        recipe = next
        guard shouldPlay, next != playerRecipe else { return }
        player?.stop()
        player = nil
        start()
    }

    /// Plays `audition` once (replacing a sounding one) when the sound may play (``shouldPlay``); otherwise nothing,
    /// and no voice is made. Returns whether it started.
    @discardableResult
    func audition(_ audition: ApsidesWorkshopAudition) -> Bool {
        guard shouldPlay, !audition.partials.isEmpty else { return false }
        let voice: any ApsidesWorkshopAuditionPlaying = self.voice ?? makeVoice()
        self.voice = voice
        auditionsPlayed += 1
        lastAudition = audition
        return voice.play(audition)
    }

    /// Changes an input with `change`, then plays or stops when ``shouldPlay`` changed.
    private func update(_ change: () -> Void) {
        let before = shouldPlay
        change()
        guard shouldPlay != before else { return }
        if shouldPlay {
            start()
        } else {
            voice?.stop()
            if let loop = player {
                loop.stop()
                loop.isEnabled = wanted
                started = false
            }
        }
    }

    /// Plays the latest recipe, making a new player when the current one plays another recipe.
    private func start() {
        if player == nil || playerRecipe != recipe {
            player?.stop()
            player = makePlayer(recipe)
            playerRecipe = recipe
            playersMade += 1
        }
        guard let loop = player else { return }
        loop.isEnabled = true
        started = loop.play()
    }
}
#endif
