// ExperienceShell — feature 188 T-U02-038 (FR-U02-050 to FR-U02-053, FR-U02-056, FR-U02-062, FR-U02-080; research
// R1, R7 and R8; contract specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). What the framework
// supplies around a presenter: the engine of the presenter's core, the scene for the existing render host, the port
// of the controls and the two-call deactivation with the GPU counts of the registry. The shell never creates,
// pauses or destroys a render host.
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreRendering

/// The failure code of a presenter's `setup` that threw.
private let setupFailedCode = "experience.setup-failed"
/// The failure code of a frame that could not be stepped or drawn.
private let drawFailedCode = "experience.draw-failed"

/// Starts a core's preparation off the main actor. Generic over the core alone, so that the detached task captures
/// only `Sendable` values: the seed, the time limit and the core's metatype.
private func detachedPreparation<Core: ExperienceCore>(
    of core: Core.Type, seed: UInt64, timeLimit: Duration?
) -> Task<Result<Core, ExperienceError>, Never> {
    Task.detached {
        await ExperienceEngine<Core>.prepare(seed: seed, timeLimit: timeLimit)
    }
}

/// Joins a pure experience core with its presenter: one experience, ready for a render host and a session host.
@MainActor
public final class ExperienceShell<Presenter: ExperiencePresenter>: Experience {
    /// The experience's identifier.
    public let id: ExperienceID
    /// The presenter that draws the core and builds the controls.
    public let presenter: Presenter
    /// The pure driver of the presenter's core: lifecycle, clock and state.
    public private(set) var engine: ExperienceEngine<Presenter.Core>
    /// The port the controls use; its handler is `handle(control:values:)`.
    public let port: ExperienceActionPort
    /// Whether the presenter's GPU objects exist: true after a successful `setup`, false after `teardown`.
    public private(set) var isSetUp = false

    private let sceneObject: ShellScene<Presenter>
    /// The registry of the last context that was set up. Held strongly, so that the counts can still be read
    /// after the owner destroyed and dropped the render host.
    private var registry: ResourceRegistry?
    private var preparationTask: Task<Result<Presenter.Core, ExperienceError>, Never>?

    /// Creates the shell of the experience `id` in the state registered. `maxStepsPerFrame` is clamped to 1…8.
    public init(id: ExperienceID, presenter: Presenter, maxStepsPerFrame: Int = 8) {
        self.id = id
        self.presenter = presenter
        engine = ExperienceEngine(id: id, maxStepsPerFrame: maxStepsPerFrame)
        let port = ExperienceActionPort(accessibilityPrefix: id.accessibilityPrefix) { _, _ in
            .rejected(.notActive(.registered))
        }
        self.port = port
        let scene = ShellScene(presenter: presenter)
        sceneObject = scene
        scene.shell = self
        port.handler = { [weak self] control, values in
            guard let self else { return .rejected(.notActive(.inactive)) }
            return self.handle(control: control, values: values)
        }
    }

    // MARK: Experience: values

    /// The current lifecycle state.
    public var state: ExperienceLifecycleState { engine.lifecycle.state }
    /// The scene to hand to a render host: `RenderHost(scene: shell.scene)`.
    public var scene: any RenderScene { sceneObject }
    /// The presenter's native controls, connected to `port`.
    public var controls: AnyView { presenter.makeControls(port) }
    /// The presenter's description of the current state; empty while there is no state.
    public var accessibilitySummary: String {
        guard let core = engine.core else { return "" }
        return presenter.describe(core)
    }
    /// The engine's diagnostics, with the registry's GPU counts once a graphics context was seen.
    public var diagnostics: ExperienceDiagnostics { engine.diagnostics(gpu: gpuCounts) }

    // MARK: Preparation

    /// Prepares the state from `seed`. The core's preparation runs in a detached task, off the main actor; the
    /// result is taken only when this preparation is still the current one.
    ///
    /// Throws `.stalePreparation` when the result was discarded (for example after `cancelPreparation()`),
    /// otherwise the error of a failed preparation. Cancelling the calling task cancels the preparation.
    public func prepare(seed: UInt64, timeLimit: Duration? = nil) async throws(ExperienceError) {
        let ticket = try engine.beginPreparation(seed: seed)
        port.setSummary("")
        preparationTask?.cancel()
        let task = detachedPreparation(of: Presenter.Core.self, seed: seed, timeLimit: timeLimit)
        preparationTask = task
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if preparationTask == task { preparationTask = nil }
        guard engine.completePreparation(ticket, with: result) else { throw .stalePreparation }
        if case .failure(let error) = result { throw error }
        refreshPort()
    }

    /// Cancels the running preparation and, when the state is preparing, ends in inactive at once.
    public func cancelPreparation() {
        preparationTask?.cancel()
        preparationTask = nil
        if engine.lifecycle.state == .preparing { try? engine.beginDeactivation() }
    }

    // MARK: Lifecycle

    /// ready → active. Time starts fresh.
    public func activate() throws(ExperienceError) {
        try engine.activate()
    }

    /// active → suspended: frames are still drawn, no step runs.
    public func suspend() throws(ExperienceError) {
        try engine.suspend()
    }

    /// suspended → active, without catching up on the time spent suspended.
    public func resume() throws(ExperienceError) {
        try engine.resume()
    }

    /// Starts leaving the experience: from now on the scene draws nothing. The owner of the render host then
    /// destroys the host or replaces its scene and calls `finishDeactivation()`.
    public func beginDeactivation() throws(ExperienceError) {
        preparationTask?.cancel()
        preparationTask = nil
        try engine.beginDeactivation()
    }

    /// Ends the leave with the registry's GPU counts (when a registry was seen): drops the state and moves to
    /// inactive, or throws `.gpuLeak` and moves to failed when an object is still live or was leaked.
    public func finishDeactivation() throws(ExperienceError) {
        defer { port.setSummary(accessibilitySummary) }
        try engine.finishDeactivation(gpu: gpuCounts)
    }

    // MARK: Input and state

    /// Carries out an action made now, or rejects it with a typed reason. After an accepted action the port's
    /// revision grows and its summary is refreshed.
    @discardableResult
    public func handle(control: String, values: [Double] = []) -> ActionResult {
        let result = engine.handle(control: control, values: values)
        if result.isAccepted { refreshPort() }
        return result
    }

    /// Captures the state as a versioned envelope. Legal while ready, active or suspended.
    public func snapshot() throws(ExperienceError) -> ExperienceSnapshot {
        try engine.snapshot()
    }

    /// Replaces the state by the one in `snapshot` and refreshes the port; a refused restore changes nothing.
    public func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError) {
        try engine.restore(snapshot)
        refreshPort()
    }

    /// Returns to the state of a fresh preparation with the current seed and refreshes the port.
    public func reset() throws(ExperienceError) {
        try engine.reset()
        refreshPort()
    }

    /// Sets the quality tier (0 is the best); the next frame is drawn with it.
    public func setQualityTier(_ tier: Int) throws(ExperienceError) {
        try engine.setQualityTier(tier)
        port.setSummary(accessibilitySummary)
    }

    /// Drops caches that can be rebuilt: first the core's, then the presenter's.
    public func shedCaches() throws(ExperienceError) {
        try engine.shedCaches()
        presenter.shedCaches()
    }

    #if DEBUG || VISUALCORE_AUTOMATION
    /// Runs an automation scenario on the engine and refreshes the port. Not part of release builds.
    public func run(_ scenario: ExperienceScenario) -> ExperienceScenarioResult {
        let result = engine.run(scenario)
        refreshPort()
        return result
    }
    #endif

    // MARK: Scene callbacks

    /// Scene `setup`: remembers the registry and lets the presenter create its GPU objects. An error moves the
    /// lifecycle to failed with the code `experience.setup-failed` and is rethrown.
    fileprivate func sceneSetup(_ context: RenderContext) throws {
        registry = context.resources
        do {
            try presenter.setup(context)
            isSetUp = true
        } catch {
            isSetUp = false
            engine.fail(ExperienceFailure(code: setupFailedCode, message: String(describing: error)))
            throw error
        }
    }

    /// Scene `render`: nothing without a state or outside ready, active and suspended; in active the engine runs
    /// the frame's steps first; then the presenter draws the core value. An error moves the lifecycle to failed
    /// with the code `experience.draw-failed` and is rethrown.
    fileprivate func sceneRender(_ context: RenderContext, frame: FrameInfo) throws {
        let state = engine.lifecycle.state
        guard state == .ready || state == .active || state == .suspended, engine.core != nil else { return }
        do {
            if state == .active, try engine.advance(frame: frame.delta) > 0 { refreshPort() }
            guard let core = engine.core else { return }
            try presenter.draw(core, tier: engine.qualityTier, context: context, frame: frame)
        } catch {
            engine.fail(ExperienceFailure(code: drawFailedCode, message: String(describing: error)))
            throw error
        }
    }

    /// Scene `teardown`, after the presenter released its objects: they no longer exist.
    fileprivate func sceneDidTeardown() {
        isSetUp = false
    }

    // MARK: Helpers

    /// The registry's counts: objects = sum of the live counts, bytes = total live bytes, leaked; nil before a
    /// context was seen.
    private var gpuCounts: GPUResourceCounts? {
        guard let registry else { return nil }
        let stats: ResourceLedger.Snapshot = registry.stats
        return GPUResourceCounts(objects: stats.liveCount.values.reduce(0, +), bytes: stats.totalBytes,
                                 leaked: stats.leaked)
    }

    /// Tells the port that the state changed: one more revision and the current description.
    private func refreshPort() {
        port.noteChange(summary: accessibilitySummary)
    }
}

/// The shell's scene. It holds the shell weakly (the shell owns it) and the presenter strongly, so that `resize`
/// and `teardown` reach the presenter in every state, even when the shell is already gone.
@MainActor
private final class ShellScene<Presenter: ExperiencePresenter>: RenderScene {
    weak var shell: ExperienceShell<Presenter>?
    private let presenter: Presenter

    init(presenter: Presenter) {
        self.presenter = presenter
    }

    func setup(_ context: RenderContext) throws {
        if let shell {
            try shell.sceneSetup(context)
        } else {
            try presenter.setup(context)
        }
    }

    func resize(_ context: RenderContext) {
        presenter.resize(context)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try shell?.sceneRender(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        presenter.teardown(context)
        shell?.sceneDidTeardown()
    }
}
