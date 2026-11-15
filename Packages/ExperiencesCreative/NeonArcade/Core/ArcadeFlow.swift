// ArcadeFlow — feature 077 (A10-P03) T-A10-303 (FR-A10-310; clarification 2; research D3; data-model
// "ArcadeScreen"). The screens of a Neon Dodge game and the only moves between them, as a pure function the
// experience applies to its recorded screen:
// - title + start → playing (the run already held is played; a new experience holds a fresh run);
// - over + start → playing with a new run;
// - playing + pause 1 → paused; paused + pause 0 → playing;
// - paused or over + restart → playing with a new run.
// Every other combination is refused (nil); the experience reports it as `a10.wrong-screen`. Only the playing screen
// advances the run, and `GameRun.paused` mirrors the paused screen so the Phase 01/02 rules stay unchanged. The core
// module knows nothing of the experience layer: actions are plain values here.
import Foundation

/// The screen a Neon Dodge game shows.
public enum ArcadeScreen: String, Codable, CaseIterable, Sendable {
    /// The title screen: nothing falls until the person starts.
    case title
    /// The game is played and advances every step.
    case playing
    /// The game is paused; no step changes it.
    case paused
    /// The run is over; its score and wave are shown with a way to play again.
    case over

    /// True only for ``playing``: the one screen on which the run advances.
    public var advancesRun: Bool { self == .playing }

    /// The screen a saved run implies when no screen was recorded (snapshot migration 2 → 3, clarification 2):
    /// over → ``over``, paused → ``paused``, otherwise ``playing``.
    public static func derived(from run: GameRun) -> ArcadeScreen {
        if run.over { return .over }
        if run.paused { return .paused }
        return .playing
    }
}

/// One move a person can ask for.
public enum ArcadeFlowAction: Equatable, Sendable {
    /// `run.start`: from the title (or a game-over screen, with a new run).
    case start
    /// `run.pause [0…1]`: true pauses a playing game, false resumes a paused one.
    case pause(Bool)
    /// `run.restart`: from the paused or game-over screen, with a new run.
    case restart
}

/// The result of an allowed move.
public struct ArcadeTransition: Equatable, Sendable {
    /// The screen after the move.
    public var screen: ArcadeScreen
    /// True when the experience must replace the run with a fresh one (``GameRun/new()``) before playing it.
    public var newRun: Bool

    /// Creates a transition.
    public init(screen: ArcadeScreen, newRun: Bool) { self.screen = screen; self.newRun = newRun }
}

/// The screen rules of Neon Dodge (see the file header).
public enum ArcadeFlow {
    /// The screen a new experience opens on.
    public static let initialScreen = ArcadeScreen.title

    /// Applies `action` to `screen`: the new screen and whether a new run starts, or nil when the move is refused.
    public static func apply(_ action: ArcadeFlowAction, to screen: ArcadeScreen) -> ArcadeTransition? {
        switch (action, screen) {
        case (.start, .title): return ArcadeTransition(screen: .playing, newRun: false)
        case (.start, .over): return ArcadeTransition(screen: .playing, newRun: true)
        case (.pause(true), .playing): return ArcadeTransition(screen: .paused, newRun: false)
        case (.pause(false), .paused): return ArcadeTransition(screen: .playing, newRun: false)
        case (.restart, .paused), (.restart, .over): return ArcadeTransition(screen: .playing, newRun: true)
        default: return nil
        }
    }
}
