// PhysicsPlaygroundExperience — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121, FR-A11-122). The public face
// of the framework `PhysicsPlaygroundExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Neon Arcade's, so the registry entry mirrors it). The world travels in the host's saved
// session state; the experience keeps no files of its own in this phase. There is no decorative motion, so Reduce
// Motion changes nothing, and nothing flashes.
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-303; research D4; edge case "Two fingers or a cancelled gesture"): the
// factory wraps the shell in `PlaygroundExperience`, which forwards every call to it and, when the experience is
// suspended while a canvas drag holds a grab, first sends `edit.release` through the shell's port (a recorded action,
// so the saved state and every replay show the body let go), then forgets the gesture state; leaving the experience
// forgets it too. The host's `ExperiencePresenter` has no suspension callback, so the wrapper is where the presenter
// learns of it (as Neon Arcade's `ArcadeExperience` does).
//
// Feature 085 (A11-P04) T-A11-403 (FR-A11-403; research D3): the experience now keeps files of its own — the four saved
// experiments `experiment-0.json` … `experiment-3.json` of `ExperimentStore`, built from the launch's storage — and the
// factory hands the presenter its shell, through which an opened slot is restored. Without storage (tests) the saved
// experiments are kept in memory.
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Builds Physics Playground as an experience of the one app.
public enum PhysicsPlaygroundExperience {
    /// The catalog id `a11.physics-playground`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: PlaygroundCore.experienceID)

    /// The experience registered as `id`. `storage` holds the saved experiments (feature 085; the world itself
    /// travels in the host's saved session state); `reduceMotion` and `reduceFlashing` change nothing (no decorative
    /// motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        PlaygroundExperience(shell: make(id: id, store: ExperimentStore(storage: storage)))
    }

    /// The experience's shell with its presenter exposed (tests); `store` keeps the saved experiments (in memory
    /// when nil). The presenter is handed the shell, through which an opened slot is restored.
    @MainActor
    static func make(id: ExperienceID, store: ExperimentStore? = nil) -> ExperienceShell<PlaygroundPresenter> {
        let presenter = PlaygroundPresenter(experienceID: id, store: store ?? ExperimentStore(storage: nil))
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.shell = shell
        return shell
    }
}

/// Physics Playground's experience: the shell of its presenter with the suspension rule of feature 084 (see the file
/// header).
@MainActor
final class PlaygroundExperience: Experience {
    /// The shell every call goes to.
    let shell: ExperienceShell<PlaygroundPresenter>

    /// Wraps `shell`.
    init(shell: ExperienceShell<PlaygroundPresenter>) {
        self.shell = shell
    }

    /// The presenter of the shell.
    var presenter: PlaygroundPresenter { shell.presenter }

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

    /// active → suspended. While a canvas drag holds a grab, `edit.release` is sent through the port first; the
    /// gesture state is then forgotten.
    func suspend() throws(ExperienceError) {
        if shell.state == .active, presenter.gestures.isGrabbing {
            _ = shell.port.send("edit.release")
        }
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

    /// Starts leaving the experience; the gesture state is forgotten.
    func beginDeactivation() throws(ExperienceError) {
        presenter.suspended()
        try shell.beginDeactivation()
    }

    func finishDeactivation() throws(ExperienceError) { try shell.finishDeactivation() }

    #if DEBUG || VISUALCORE_AUTOMATION
    func runScenario(_ scenario: ExperienceScenario) -> ExperienceScenarioResult { shell.runScenario(scenario) }
    #endif
}
