// EchoCartographerSound — feature 406 (R02-G11-06) T-R02G1106-005 (FR-R02G1106-006; SC-R02G1106-004; clarification Q4).
// When Echo Cartographer's ambient loop plays, by the A21 rule (feature 156): exactly while the sound choice is on, the
// controls are on screen and the scene is active. The loop's recipe comes from `EchoCartographerSoundRecipe` (the
// energy left, the beacons located and the stage); because a player fixes its recipe at creation, the loop is rebuilt
// only when a new recipe is offered at a level opening, an action, undo or redo that changes the located count, the
// root step or the stage, or the toggle turning on, never per frame. The sound choice off makes no player and touches no
// audio session. A `play()` that fails changes nothing else. Presentation only: no state, digest or snapshot sees it.
// Modelled on `BackwardsAuroraSound` (feature 396).
#if os(iOS)
import EchoCartographerCore
import VisualCoreAudio
import VisualCoreAudioDSP

/// What Echo Cartographer needs of a looping player (the tests' seam; ``AmbientLoopPlayer`` conforms).
@MainActor
protocol EchoCartographerLoopPlaying: AnyObject {
    /// Whether `play()` plays anything.
    var isEnabled: Bool { get set }
    /// Whether the loop plays.
    var isPlaying: Bool { get }
    /// Starts the loop; false when it could not start.
    @discardableResult func play() -> Bool
    /// Stops the loop.
    func stop()
}

extension AmbientLoopPlayer: EchoCartographerLoopPlaying {}

/// When Echo Cartographer's loop plays (see the file header).
@MainActor
final class EchoCartographerSound {
    /// Makes a player for a recipe when one must play.
    let makePlayer: (AmbientLoopRecipe) -> any EchoCartographerLoopPlaying
    /// The current player; nil until the loop first had to play.
    private(set) var player: (any EchoCartographerLoopPlaying)?
    /// The recipe the current player plays.
    private(set) var playerRecipe: AmbientLoopRecipe?
    /// The recipe to play next (the latest one offered).
    private(set) var recipe: AmbientLoopRecipe
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

    /// Whether the loop should play: `wanted && onScreen && active`.
    var shouldPlay: Bool { wanted && onScreen && active }

    /// A policy starting from `recipe`, making players with `makePlayer` (nil: `AmbientLoopPlayer(recipe:)`).
    init(recipe: AmbientLoopRecipe, makePlayer: ((AmbientLoopRecipe) -> any EchoCartographerLoopPlaying)? = nil) {
        self.recipe = recipe
        self.makePlayer = makePlayer ?? { AmbientLoopPlayer(recipe: $0) }
    }

    /// Sets whether the person wants the sound; turning it on plays the latest recipe.
    func setWanted(_ on: Bool) { update { wanted = on } }

    /// Sets whether the controls view is on screen.
    func setOnScreen(_ on: Bool) { update { onScreen = on } }

    /// Sets whether the scene is active.
    func setActive(_ on: Bool) { update { active = on } }

    /// Offers the recipe of a level opening or a change of the located count, the root step or the stage: kept for the next start,
    /// and played at once (a new player) when the loop is playing and the recipe differs.
    func offer(_ next: AmbientLoopRecipe) {
        recipe = next
        guard shouldPlay, next != playerRecipe else { return }
        player?.stop()
        player = nil
        start()
    }

    /// Changes an input with `change`, then plays or stops when ``shouldPlay`` changed.
    private func update(_ change: () -> Void) {
        let before = shouldPlay
        change()
        guard shouldPlay != before else { return }
        if shouldPlay {
            start()
        } else if let loop = player {
            loop.stop()
            loop.isEnabled = wanted
            started = false
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
