// ColorfallCanyonsSound — feature 346 (R02-G05-06) T-R02G0506-006 (FR-R02G0506-006; clarification Q4; research R7).
// When Colorfall Canyons's ambient loop plays, by the A21 rule (feature 156): exactly while the sound choice is on, the
// controls are on screen and the scene is active. The loop's recipe comes from `ColorfallCanyonsSoundRecipe` (the basins'
// colour mass and the stage); because a player fixes its recipe at creation, the loop is rebuilt only when a new recipe
// is offered at a level opening, a change of the basins or the stage, or the toggle turning on — never per frame.
// The sound choice off makes no player and touches no audio session. A `play()` that fails changes nothing else.
// Presentation only: no state, digest or snapshot sees it. Modelled on `HueCompassSound` (feature 336).
#if os(iOS)
import ColorfallCanyonsCore
import VisualCoreAudio
import VisualCoreAudioDSP

/// What Colorfall Canyons needs of a looping player (the tests' seam; ``AmbientLoopPlayer`` conforms).
@MainActor
protocol ColorfallCanyonsLoopPlaying: AnyObject {
    /// Whether `play()` plays anything.
    var isEnabled: Bool { get set }
    /// Whether the loop plays.
    var isPlaying: Bool { get }
    /// Starts the loop; false when it could not start.
    @discardableResult func play() -> Bool
    /// Stops the loop.
    func stop()
}

extension AmbientLoopPlayer: ColorfallCanyonsLoopPlaying {}

/// When Colorfall Canyons's loop plays (see the file header).
@MainActor
final class ColorfallCanyonsSound {
    /// Makes a player for a recipe when one must play.
    let makePlayer: (AmbientLoopRecipe) -> any ColorfallCanyonsLoopPlaying
    /// The current player; nil until the loop first had to play.
    private(set) var player: (any ColorfallCanyonsLoopPlaying)?
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
    init(recipe: AmbientLoopRecipe, makePlayer: ((AmbientLoopRecipe) -> any ColorfallCanyonsLoopPlaying)? = nil) {
        self.recipe = recipe
        self.makePlayer = makePlayer ?? { AmbientLoopPlayer(recipe: $0) }
    }

    /// Sets whether the person wants the sound; turning it on plays the latest recipe.
    func setWanted(_ on: Bool) { update { wanted = on } }

    /// Sets whether the controls view is on screen.
    func setOnScreen(_ on: Bool) { update { onScreen = on } }

    /// Sets whether the scene is active.
    func setActive(_ on: Bool) { update { active = on } }

    /// Offers the recipe of a level opening or an ended play: kept for the next start, and played at once (a new
    /// player) when the loop is playing and the recipe differs.
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
