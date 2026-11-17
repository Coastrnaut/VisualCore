// SkySound — feature 156 (A21-P05) T-A21-503 (FR-A21-501–504; contracts/sound.md; data-model.md "SkySound state").
// When Aurora's ambient loop plays. Three inputs: `wanted` (the person's sound choice), `onScreen` (the controls view
// appeared and has not disappeared) and `active` (the scene phase is active; true at start). The loop plays while
// `wanted && onScreen && active`: `play()` is called when that becomes true and `stop()` when it becomes false, so
// leaving Aurora, the background or an interruption stops it and coming back plays it again. A loop the player
// stopped itself is not restarted until one of the inputs becomes true again. The player is made only when it must
// play (the sound off makes none and touches no audio session); the volume is passed as a Float at once. A `play()`
// that returns false changes nothing else: the choice stays on and the sky is not touched. No drawing call reaches
// this type.
import AuroraCore
import VisualCoreAudio
import VisualCoreAudioDSP

/// What Aurora needs of a looping player (the tests' seam; ``AmbientLoopPlayer`` conforms).
@MainActor
protocol SkyLoopPlaying: AnyObject {
    /// Whether `play()` plays anything; off also stops the loop.
    var isEnabled: Bool { get set }
    /// The loop's volume, 0…1.
    var volume: Float { get set }
    /// Whether the loop plays.
    var isPlaying: Bool { get }
    /// Starts the loop; false when it could not start.
    @discardableResult func play() -> Bool
    /// Stops the loop.
    func stop()
}

extension AmbientLoopPlayer: SkyLoopPlaying {}

/// When Aurora's loop plays (see the file header).
@MainActor
final class SkySound {
    /// Makes the player when it first must play.
    let makePlayer: () -> any SkyLoopPlaying
    /// The player; nil until the loop first had to play.
    private(set) var player: (any SkyLoopPlaying)?
    /// Whether the person turned the sound on.
    private(set) var wanted = false
    /// Whether the controls view is on screen.
    private(set) var onScreen = false
    /// Whether the scene is active (true at start).
    private(set) var active = true
    /// The volume, 0…1.
    private(set) var volume = SkyPreferences.defaults.volume
    /// Whether the last `play()` succeeded; false before one and after a stop.
    private(set) var started = false

    /// Whether the loop should play: `wanted && onScreen && active`.
    var shouldPlay: Bool { wanted && onScreen && active }

    /// A policy making its player with `makePlayer` (nil: `AmbientLoopPlayer(recipe: .gentle)`).
    init(makePlayer: (() -> any SkyLoopPlaying)? = nil) {
        self.makePlayer = makePlayer ?? { AmbientLoopPlayer(recipe: .gentle) }
    }

    /// Sets the sound choice and volume without playing (the restored preferences, before anything is on screen).
    func seed(wanted: Bool, volume: Double) {
        self.volume = volume
        update { self.wanted = wanted }
    }

    /// Sets whether the person wants the sound.
    func setWanted(_ on: Bool) { update { wanted = on } }

    /// Sets whether the controls view is on screen.
    func setOnScreen(_ on: Bool) { update { onScreen = on } }

    /// Sets whether the scene is active.
    func setActive(_ on: Bool) { update { active = on } }

    /// Sets the volume and passes it to the player at once.
    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }

    /// Changes an input with `change`, then plays or stops when ``shouldPlay`` changed.
    private func update(_ change: () -> Void) {
        let before = shouldPlay
        change()
        guard shouldPlay != before else { return }
        if shouldPlay {
            let loop = player ?? makePlayer()
            player = loop
            loop.isEnabled = true
            loop.volume = Float(volume)
            started = loop.play()
        } else if let loop = player {
            loop.stop()
            loop.isEnabled = wanted
            started = false
        }
    }
}
