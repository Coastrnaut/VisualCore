// LightMazeExperience — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121, FR-A13-122). The public face of the
// framework `LightMazeExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Tiny Worlds', so the registry entry mirrors it). The maze travels in the host's saved session state; the
// experience keeps no files of its own in this phase. There is no motion, so Reduce Motion changes nothing, and nothing
// flashes.
// Feature 097 (A13-P02) T-A13-204, T-A13-205 (FR-A13-201, FR-A13-204, FR-A13-212): the factory hands the presenter its
// shell (gestures read the live state through it) and, in tests, whether VoiceOver runs and where announcements go.
// It wraps the shell in `MazeExperience`, which forwards every call to it and forgets every touch when the experience
// is suspended or starts leaving: the host's `ExperiencePresenter` has no suspension callback, so the wrapper is where
// the presenter learns of it (as Neon Arcade's and Physics Playground's wrappers do).
// Feature 098 (A13-P03) T-A13-304 (FR-A13-320; clarification Q1): the launch's storage now holds the level progress
// (`progress.json` through a `ProgressStore` the presenter owns); tests pass a store of their own or keep progress in
// memory.
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

/// Builds Light Maze as an experience of the one app.
public enum LightMazeExperience {
    /// The catalog id `a13.light-maze`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MazeCore.experienceID)

    /// The experience registered as `id`. `storage` keeps the level progress (`progress.json`; the maze itself
    /// travels in the host's saved session state); `reduceMotion` and `reduceFlashing` keep the solved border static
    /// (feature 099: no brightening).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, progressStore: ProgressStore(storage: storage), reduceMotion: reduceMotion,
             reduceFlashing: reduceFlashing)
    }

    /// The experience with its shell and presenter exposed (tests): `progressStore` keeps the progress (nil: in
    /// memory); `voiceOverRunning` and `announcementSink` replace the system's answers when given; `soundSink` and
    /// `feedback` replace the success sound and haptic route (feature 099). The presenter is
    /// handed the shell, through which gestures read the live state.
    @MainActor
    static func make(id: ExperienceID, progressStore: ProgressStore? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil,
                     announcementSink: (any AnnouncementSink)? = nil, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, soundSink: (any MazeSoundSink)? = nil,
                     feedback: ExperienceFeedback? = nil) -> MazeExperience {
        let presenter = MazePresenter(experienceID: id, progressStore: progressStore,
                                      voiceOverRunning: voiceOverRunning, announcementSink: announcementSink,
                                      reduceMotion: reduceMotion, reduceFlashing: reduceFlashing,
                                      soundSink: soundSink, feedback: feedback)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.shell = shell
        return MazeExperience(shell: shell)
    }
}

/// Light Maze's experience: the shell of its presenter, forgetting every touch on suspension (see the file header).
@MainActor
final class MazeExperience: Experience {
    /// The shell every call goes to.
    let shell: ExperienceShell<MazePresenter>

    /// Wraps `shell`.
    init(shell: ExperienceShell<MazePresenter>) {
        self.shell = shell
    }

    /// The presenter of the shell.
    var presenter: MazePresenter { shell.presenter }

    var id: ExperienceID { shell.id }
    var state: ExperienceLifecycleState { shell.state }
    var scene: any RenderScene { shell.scene }
    var port: ExperienceActionPort { shell.port }
    var controls: AnyView { shell.controls }
    var accessibilitySummary: String { shell.accessibilitySummary }
    var diagnostics: ExperienceDiagnostics { shell.diagnostics }
    var frameProbes: [FrameProbe] { shell.frameProbes }
    var qualityProfile: QualityProfile { shell.qualityProfile }

    func prepare(seed: UInt64, timeLimit: Duration?) async throws(ExperienceError) {
        try await shell.prepare(seed: seed, timeLimit: timeLimit)
    }

    func cancelPreparation() { shell.cancelPreparation() }

    func activate() throws(ExperienceError) { try shell.activate() }

    /// active → suspended; every touch is forgotten (nothing is sent).
    func suspend() throws(ExperienceError) {
        try shell.suspend()
        presenter.suspended()
    }

    /// suspended → active; the gestures start from no touch.
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

    /// Starts leaving the experience; every touch is forgotten.
    func beginDeactivation() throws(ExperienceError) {
        presenter.suspended()
        try shell.beginDeactivation()
    }

    func finishDeactivation() throws(ExperienceError) { try shell.finishDeactivation() }

    #if DEBUG || VISUALCORE_AUTOMATION
    func runScenario(_ scenario: ExperienceScenario) -> ExperienceScenarioResult { shell.runScenario(scenario) }
    #endif
}
