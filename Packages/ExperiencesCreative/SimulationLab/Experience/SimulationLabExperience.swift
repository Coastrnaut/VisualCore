// SimulationLabExperience — feature 117 (A16-P01) T-A16-105 (FR-A16-130, FR-A16-131). The public face of the framework
// `SimulationLabExperience`: the experience's id and the factory the one app's registry calls (the same parameter list
// as Molecular Explorer's, so the registry entry mirrors it). The simulation travels in the host's saved session state;
// from feature 120 (A16-P04) `storage` holds the saved experiments (``SimulationPresetStore``), and Reduce Motion and
// Reduce Flashing set the presenter's speed caps (×1, and the automaton ×0.25 under Reduce Flashing).
//
// Reduce Motion (FR-A16-130): the simulation opens paused and the person starts it. The core's preparation knows only
// the seed, so the factory wraps the shell in ``SimulationExperience`` (as Physics Playground's `PlaygroundExperience`
// does), which forwards every call and, with Reduce Motion on, sends `sim.pause` through the shell when the experience
// first becomes active after a preparation or a reset (a recorded action, so the saved state and every replay show the
// pause). A restored state that is already paused is left as it is.
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Builds Simulation Lab as an experience of the one app.
public enum SimulationLabExperience {
    /// The catalog id `a16.simulation-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SimulationCore.experienceID)

    /// The experience registered as `id`: `storage` holds the saved experiments; with `reduceMotion` the simulation
    /// opens paused; both settings cap the speed.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        SimulationExperience(shell: make(id: id, storage: storage), reduceMotion: reduceMotion,
                             reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests); without `storage` there is no preset library.
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil) -> ExperienceShell<SimulationPresenter> {
        ExperienceShell(id: id, presenter: SimulationPresenter(experienceID: id, storage: storage))
    }
}

/// Simulation Lab's experience: the shell of its presenter with the Reduce Motion rule (see the file header).
@MainActor
final class SimulationExperience: Experience {
    /// The shell every call goes to.
    let shell: ExperienceShell<SimulationPresenter>
    /// Whether the simulation opens paused.
    let reduceMotion: Bool
    /// Whether the next activation pauses (set by a preparation or a reset under Reduce Motion).
    private(set) var pauseOnActivation = false

    /// Wraps `shell`; with `reduceMotion` the simulation opens paused. Both settings set the presenter's speed caps
    /// (feature 120): a faster speed is lowered to the cap on activation.
    init(shell: ExperienceShell<SimulationPresenter>, reduceMotion: Bool, reduceFlashing: Bool = false) {
        self.shell = shell
        self.reduceMotion = reduceMotion
        shell.presenter.reduceMotion = reduceMotion
        shell.presenter.reduceFlashing = reduceFlashing
    }

    /// The presenter of the shell.
    var presenter: SimulationPresenter { shell.presenter }

    /// The experience's identifier.
    var id: ExperienceID { shell.id }
    /// The current lifecycle state.
    var state: ExperienceLifecycleState { shell.state }
    /// The shell's scene.
    var scene: any RenderScene { shell.scene }
    /// The shell's port.
    var port: ExperienceActionPort { shell.port }
    /// The presenter's controls.
    var controls: AnyView { shell.controls }
    /// The presenter's description of the current state.
    var accessibilitySummary: String { shell.accessibilitySummary }
    /// The shell's diagnostics.
    var diagnostics: ExperienceDiagnostics { shell.diagnostics }
    /// The presenter's probes.
    var frameProbes: [FrameProbe] { shell.frameProbes }
    /// The core's quality profile (one level).
    var qualityProfile: QualityProfile { shell.qualityProfile }

    /// Prepares the shell; under Reduce Motion the next activation pauses.
    func prepare(seed: UInt64, timeLimit: Duration?) async throws(ExperienceError) {
        try await shell.prepare(seed: seed, timeLimit: timeLimit)
        pauseOnActivation = reduceMotion
    }

    /// Cancels the shell's preparation.
    func cancelPreparation() { shell.cancelPreparation() }

    /// ready → active; under Reduce Motion a running simulation is then paused once.
    func activate() throws(ExperienceError) {
        try shell.activate()
        pauseIfDue()
        lowerSpeedToCap()
    }

    /// Lowers a speed above the presenter's cap for the current family to the cap through `sim.speed`.
    private func lowerSpeedToCap() {
        guard let core = shell.engine.core else { return }
        let cap = presenter.speedCap(kind: core.kind)
        if core.speedIndex > cap { _ = shell.handle(control: "sim.speed", values: [Double(cap)]) }
    }

    /// active → suspended.
    func suspend() throws(ExperienceError) { try shell.suspend() }

    /// suspended → active.
    func resume() throws(ExperienceError) { try shell.resume() }

    /// Hands a canvas touch to the shell.
    func handlePointer(_ event: PointerEvent, viewSize: Vec2) { shell.handlePointer(event, viewSize: viewSize) }

    /// Carries out an action through the shell.
    @discardableResult func handle(control: String, values: [Double]) -> ActionResult {
        shell.handle(control: control, values: values)
    }

    /// The shell's snapshot.
    func snapshot() throws(ExperienceError) -> ExperienceSnapshot { try shell.snapshot() }

    /// Restores the shell's state (a restored running state is paused by a pending activation under Reduce Motion).
    func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError) { try shell.restore(snapshot) }

    /// Resets the shell; under Reduce Motion the fresh, running state is paused again (now when active, else at the
    /// next activation).
    func reset() throws(ExperienceError) {
        try shell.reset()
        pauseOnActivation = reduceMotion
        if shell.state == .active { pauseIfDue() }
    }

    /// Sets the shell's quality tier.
    func setQualityTier(_ tier: Int) throws(ExperienceError) { try shell.setQualityTier(tier) }

    /// Drops the shell's caches.
    func shedCaches() throws(ExperienceError) { try shell.shedCaches() }

    /// Starts leaving the experience.
    func beginDeactivation() throws(ExperienceError) { try shell.beginDeactivation() }

    /// Ends the leave.
    func finishDeactivation() throws(ExperienceError) { try shell.finishDeactivation() }

    #if DEBUG || VISUALCORE_AUTOMATION
    /// Runs an automation scenario on the shell.
    func runScenario(_ scenario: ExperienceScenario) -> ExperienceScenarioResult { shell.runScenario(scenario) }
    #endif

    /// Sends `sim.pause` once when a pause is due and the simulation runs.
    private func pauseIfDue() {
        guard pauseOnActivation else { return }
        pauseOnActivation = false
        if shell.engine.core?.isRunning == true {
            _ = shell.handle(control: "sim.pause")
        }
    }
}
