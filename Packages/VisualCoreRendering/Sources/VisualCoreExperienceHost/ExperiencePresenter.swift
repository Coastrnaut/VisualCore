// ExperiencePresenter — feature 188 T-U02-038 (FR-U02-050 to FR-U02-053, FR-U02-056, FR-U02-062, FR-U02-080;
// research R1; contract specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). The main-actor part an
// author writes for an experience (GPU objects, drawing, controls, the state in words) and the face every
// experience shows to the session host.
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The main-actor part of an experience: it owns the GPU objects, draws the core and builds the controls.
///
/// A presenter never changes the state: `draw` receives the core as a value. It keeps no GPU object across
/// `teardown`, because `setup` runs again after a context loss, and it never reads pixels back to decide anything.
@MainActor
public protocol ExperiencePresenter: AnyObject {
    /// The pure core this presenter draws.
    associatedtype Core: ExperienceCore

    /// Creates the GPU objects through `context.resources`. Runs again after a context loss.
    func setup(_ context: RenderContext) throws
    /// Reacts to a new drawable size. Default: nothing.
    func resize(_ context: RenderContext)
    /// Draws `core` at the quality tier `tier` (0 is the best) into the framebuffer of `context`.
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws
    /// Releases every GPU object created since `setup`.
    func teardown(_ context: RenderContext)
    /// Drops caches that can be rebuilt. Default: nothing.
    func shedCaches()
    /// The state in words, for assistive technology.
    func describe(_ core: Core) -> String
    /// The native controls of the experience; they call `port.send`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView
    /// Points of the rendered frame whose colour class follows from `core` (feature 195, FR-U09-040): the
    /// verification runner reads the drawn frame and checks each one. Default: none; every experience that is
    /// verified declares at least one.
    func probes(_ core: Core) -> [FrameProbe]
    /// A touch on the canvas of the open, active experience (feature 193, FR-U07-019): `event.location` is in
    /// view points (origin top-left) and `viewSize` is the view's size in points. The presenter turns events into
    /// domain actions with positions normalized to 0…1 of the view and sends them through `port`; it never
    /// changes the state itself. Default: nothing.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort)
}

extension ExperiencePresenter {
    /// Does nothing: a presenter that does not depend on the drawable size needs no override.
    public func resize(_ context: RenderContext) {}
    /// Does nothing: a presenter without rebuildable caches needs no override.
    public func shedCaches() {}
    /// No probes.
    public func probes(_ core: Core) -> [FrameProbe] { [] }
    /// Ignores the event: an experience without canvas input needs no override.
    public func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {}
}

/// One experience as the session host sees it: lifecycle, scene, controls, state description and diagnostics.
@MainActor
public protocol Experience: AnyObject {
    /// The experience's identifier.
    var id: ExperienceID { get }
    /// The current lifecycle state.
    var state: ExperienceLifecycleState { get }
    /// The scene to hand to a render host. The experience never creates, pauses or destroys the host.
    var scene: any RenderScene { get }
    /// The port the controls use to reach the experience.
    var port: ExperienceActionPort { get }
    /// The native controls of the experience.
    var controls: AnyView { get }
    /// The current state in words; empty while there is no state.
    var accessibilitySummary: String { get }
    /// The diagnostics of the experience, with GPU counts once a graphics context was seen.
    var diagnostics: ExperienceDiagnostics { get }
    /// What each quality tier of the experience means in numbers (feature 192, UA-F06). Default: one level.
    var qualityProfile: QualityProfile { get }
    /// The frame probes of the current state (feature 195); empty without a state or without probes.
    var frameProbes: [FrameProbe] { get }

    /// Prepares the state from `seed` off the main actor, under an optional time limit; ends in ready.
    func prepare(seed: UInt64, timeLimit: Duration?) async throws(ExperienceError)
    /// Cancels a running preparation; without one it does nothing.
    func cancelPreparation()
    /// ready → active.
    func activate() throws(ExperienceError)
    /// active → suspended: frames are drawn, no step runs.
    func suspend() throws(ExperienceError)
    /// suspended → active, without catching up on the time spent suspended.
    func resume() throws(ExperienceError)
    /// Hands a canvas touch to the presenter while the experience is active; otherwise it is dropped
    /// (feature 193). `viewSize` is the canvas size in points.
    func handlePointer(_ event: PointerEvent, viewSize: Vec2)
    /// Carries out an action made now with the control `control`, or rejects it with a typed reason.
    @discardableResult func handle(control: String, values: [Double]) -> ActionResult
    /// Captures the state as a versioned envelope.
    func snapshot() throws(ExperienceError) -> ExperienceSnapshot
    /// Replaces the state by the one in `snapshot`; a refused restore changes nothing.
    func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError)
    /// Returns to the state of a fresh preparation with the current seed.
    func reset() throws(ExperienceError)
    /// Sets the quality tier (0 is the best); the state's digest does not change.
    func setQualityTier(_ tier: Int) throws(ExperienceError)
    /// Drops caches that can be rebuilt, in the core and in the presenter; the state's digest does not change.
    func shedCaches() throws(ExperienceError)
    /// Starts leaving the experience: from now on the scene draws nothing.
    func beginDeactivation() throws(ExperienceError)
    /// Ends the leave after the render host was destroyed or its scene replaced; throws `.gpuLeak` when a GPU
    /// object is still live or was leaked.
    func finishDeactivation() throws(ExperienceError)
    #if DEBUG || VISUALCORE_AUTOMATION
    /// Runs scripted entries (steps, then an action each) on the active experience through its own reducer and
    /// refreshes its controls. Only in builds made for testing or for automation.
    func runScenario(_ scenario: ExperienceScenario) -> ExperienceScenarioResult
    #endif
}

extension Experience {
    /// One level: an experience that declares no profile has nothing to step through.
    public var qualityProfile: QualityProfile { .single }
    /// No probes.
    public var frameProbes: [FrameProbe] { [] }
}
