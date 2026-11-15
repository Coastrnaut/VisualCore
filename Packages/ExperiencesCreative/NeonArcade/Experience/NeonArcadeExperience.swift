// NeonArcadeExperience — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121, FR-A10-122). The public face of the
// framework `NeonArcadeExperience`: the experience's id and the factory the one app's registry calls. The run travels
// in the host's saved session state; the experience keeps no files of its own in this phase. Reduce Motion halves the
// glow pulse and the background drift (presentation only).
// Feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-320, FR-A10-321; edge cases "leaving the app while playing",
// "an audio interruption or backgrounding"): Reduce Motion also makes screen changes immediate, and reduced flashing
// replaces a hit's full-field tint by its ring alone. The factory wraps the shell in `ArcadeExperience`, which forwards
// every call to it and, when the experience is suspended while the game is playing, first sends `run.pause [1]`
// through the shell's port (a recorded action, so the saved state and every replay show the paused screen and nothing
// advanced: backgrounding pauses the game and never fast-forwards it) and then stops every sound. The host's
// `ExperiencePresenter` has no suspension callback, so the wrapper is where the experience learns of it.
// Feature 078 (A10-P04) T-A10-403 (FR-A10-411; clarification 2): the launch storage reaches the presenter as its
// `HighScoreStore` (the file `high-scores.json` in the experience's own folder; the app's reset of the experience's
// data removes it). The run itself still travels in the host's saved session state.
import SwiftUI
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Builds Neon Arcade as an experience of the one app.
public enum NeonArcadeExperience {
    /// The catalog id `a10.neon-arcade`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ArcadeCore.experienceID)

    /// The experience registered as `id`. `storage` holds the high-score table (feature 078; the run travels in the
    /// host's saved session state); `reduceMotion` halves the glow pulse and the background drift and makes screen
    /// changes immediate; `reduceFlashing` keeps only the ring of a hit (no full-field tint).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing,
             highScores: HighScoreStore(storage: storage))
    }

    /// The experience with its shell and presenter exposed (tests inject the sound sink, the haptic and announcement
    /// route and the high-score store; without one the table is kept in memory only).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     soundSink: (any ArcadeSoundSink)? = nil, feedback: ExperienceFeedback? = nil,
                     highScores: HighScoreStore? = nil) -> ArcadeExperience {
        ArcadeExperience(shell: ExperienceShell(id: id, presenter: ArcadePresenter(
            experienceID: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing, soundSink: soundSink,
            feedback: feedback, highScores: highScores)))
    }
}

/// Neon Arcade's experience: the shell of its presenter with the suspension rule of feature 077 (see the file header).
/// The quality profile is the protocol's default single level, which equals the shell's (one tier).
@MainActor
final class ArcadeExperience: Experience {
    /// The shell every call goes to.
    let shell: ExperienceShell<ArcadePresenter>

    /// Wraps `shell`.
    init(shell: ExperienceShell<ArcadePresenter>) {
        self.shell = shell
    }

    /// The presenter of the shell.
    var presenter: ArcadePresenter { shell.presenter }

    var id: ExperienceID { shell.id }
    var state: ExperienceLifecycleState { shell.state }
    var scene: any RenderScene { shell.scene }
    var port: ExperienceActionPort { shell.port }
    var controls: AnyView { shell.controls }
    var accessibilitySummary: String { shell.accessibilitySummary }
    var diagnostics: ExperienceDiagnostics { shell.diagnostics }
    var frameProbes: [FrameProbe] { shell.frameProbes }

    func prepare(seed: UInt64, timeLimit: Duration?) async throws(ExperienceError) {
        try await shell.prepare(seed: seed, timeLimit: timeLimit)
    }

    func cancelPreparation() { shell.cancelPreparation() }

    func activate() throws(ExperienceError) { try shell.activate() }

    /// active → suspended. While the game is playing, `run.pause [1]` is sent through the port first; every sound
    /// stops.
    func suspend() throws(ExperienceError) {
        if shell.state == .active, shell.engine.core?.screen == .playing {
            _ = shell.port.send("run.pause", [1])
        }
        try shell.suspend()
        presenter.suspended()
    }

    /// suspended → active; the game stays on the screen it had (a game paused by the suspension stays paused).
    func resume() throws(ExperienceError) { try shell.resume() }

    func handlePointer(_ event: PointerEvent, viewSize: Vec2) { shell.handlePointer(event, viewSize: viewSize) }

    @discardableResult func handle(control: String, values: [Double]) -> ActionResult {
        shell.handle(control: control, values: values)
    }

    func snapshot() throws(ExperienceError) -> ExperienceSnapshot { try shell.snapshot() }

    func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError) { try shell.restore(snapshot) }

    func reset() throws(ExperienceError) { try shell.reset() }

    func setQualityTier(_ tier: Int) throws(ExperienceError) { try shell.setQualityTier(tier) }

    func shedCaches() throws(ExperienceError) { try shell.shedCaches() }

    /// Starts leaving the experience; every sound stops.
    func beginDeactivation() throws(ExperienceError) {
        presenter.suspended()
        try shell.beginDeactivation()
    }

    func finishDeactivation() throws(ExperienceError) { try shell.finishDeactivation() }

    #if DEBUG || VISUALCORE_AUTOMATION
    func runScenario(_ scenario: ExperienceScenario) -> ExperienceScenarioResult { shell.runScenario(scenario) }
    #endif
}
