# Contract: main-actor API of ExperienceKit (module VisualCoreExperienceHost) and the symbol tool

Module `VisualCoreExperienceHost` in `Packages/VisualCoreRendering`. It imports `SwiftUI`, `Observation`,
`VisualCoreRendering`, `VisualCoreDiagnostics` and `VisualCoreExperience`. Everything here is `@MainActor`.

## Presenter: what an author writes

```swift
@MainActor
public protocol ExperiencePresenter: AnyObject {
    associatedtype Core: ExperienceCore
    func setup(_ context: RenderContext) throws                 // create GPU objects through context.resources
    func resize(_ context: RenderContext)                       // default: nothing
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws
    func teardown(_ context: RenderContext)                     // release every GPU object
    func shedCaches()                                           // default: nothing
    func describe(_ core: Core) -> String                       // the state in words, for assistive technology
    func makeControls(_ port: ExperienceActionPort) -> AnyView  // native controls; they call port.send
}
```

- `draw` receives the core as a value: it cannot change the state.
- `setup` runs again after a context loss; a presenter keeps no GPU object across `teardown`.
- A presenter never reads pixels back to decide anything.

## Port: how controls reach the experience

```swift
@MainActor @Observable
public final class ExperienceActionPort {
    public private(set) var revision: Int                       // grows after every change of the state
    public private(set) var summary: String                     // presenter.describe of the current state; "" without one
    public let accessibilityPrefix: String                      // ExperienceID.accessibilityPrefix
    @discardableResult public func send(_ control: String, _ values: [Double] = []) -> ActionResult
    @discardableResult public func send(_ control: String, at point: CGPoint, in size: CGSize) -> ActionResult
    public func identifier(_ name: String) -> String            // "<prefix>.<name>", for accessibility identifiers
}
```

`send(_:at:in:)` turns the point into normalized coordinates with `ExperienceInput.normalized`; a point outside
the view is answered with `.rejected(.outOfRange(index: 0))` and nothing reaches the experience.

## Experience: the face the session host sees

```swift
@MainActor
public protocol Experience: AnyObject {
    var id: ExperienceID { get }
    var state: ExperienceLifecycleState { get }
    var scene: any RenderScene { get }
    var port: ExperienceActionPort { get }
    var controls: AnyView { get }
    var accessibilitySummary: String { get }
    var diagnostics: ExperienceDiagnostics { get }

    func prepare(seed: UInt64, timeLimit: Duration?) async throws(ExperienceError)
    func cancelPreparation()
    func activate() throws(ExperienceError)
    func suspend() throws(ExperienceError)
    func resume() throws(ExperienceError)
    @discardableResult func handle(control: String, values: [Double]) -> ActionResult
    func snapshot() throws(ExperienceError) -> ExperienceSnapshot
    func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError)
    func reset() throws(ExperienceError)
    func setQualityTier(_ tier: Int) throws(ExperienceError)
    func shedCaches() throws(ExperienceError)
    func beginDeactivation() throws(ExperienceError)
    func finishDeactivation() throws(ExperienceError)
}
```

## Shell: what the framework supplies

```swift
@MainActor
public final class ExperienceShell<Presenter: ExperiencePresenter>: Experience {
    public init(id: ExperienceID, presenter: Presenter, maxStepsPerFrame: Int = 8)
    public let presenter: Presenter
    public private(set) var engine: ExperienceEngine<Presenter.Core>
    public var isSetUp: Bool { get }                            // GPU objects exist
    // … the members of Experience

    #if DEBUG || VISUALCORE_AUTOMATION
    public func run(_ scenario: ExperienceScenario) -> ExperienceScenarioResult
    #endif
}
```

Behavior:

| Call | What the shell does |
|---|---|
| `prepare` | `engine.beginPreparation`; runs `ExperienceEngine.prepare` in a detached task (off the main actor); `engine.completePreparation`; throws `.stalePreparation` when the result was discarded, otherwise the result's error. The caller's task cancellation and `cancelPreparation()` both cancel the detached task. |
| `cancelPreparation` | cancels the task and calls `engine.beginDeactivation()` when the state is preparing; otherwise nothing |
| scene `setup` | remembers the registry of the context, calls `presenter.setup`; an error moves the lifecycle to failed with the code `experience.setup-failed` and is rethrown |
| scene `render` | nothing when there is no core or the state is not ready, active or suspended; in active first `engine.advance(frame: frame.delta)`; then `presenter.draw(core, tier, context, frame)`; an error moves the lifecycle to failed with the code `experience.draw-failed` and is rethrown |
| scene `resize`, `teardown` | forwarded to the presenter; `teardown` is forwarded in every state |
| `handle`, `port.send` | `engine.handle(control:values:)`; after an accepted action `port.revision` grows and `port.summary` is refreshed |
| `snapshot`, `restore`, `reset`, `setQualityTier`, `suspend`, `resume`, `activate` | forwarded to the engine; `restore` and `reset` refresh the port |
| `shedCaches` | `engine.shedCaches()` and then `presenter.shedCaches()` |
| `beginDeactivation` | `engine.beginDeactivation()`; from now on the scene draws nothing |
| `finishDeactivation` | reads the registry counts (when a registry was seen) and calls `engine.finishDeactivation(gpu:)`; throws `.gpuLeak` when an object is still live or leaked |
| `diagnostics` | `engine.diagnostics(gpu:)` with the registry counts: objects = sum of live counts, bytes = total live bytes, leaked |
| `accessibilitySummary` | `presenter.describe(core)`, or an empty text without a core |

The owner of the render host (the session host of UA-F03, a test in this feature) creates
`RenderHost(scene: shell.scene)`, and between `beginDeactivation` and `finishDeactivation` destroys the host or
replaces its scene. The shell never creates, pauses or destroys a render host.

Thread ownership: the shell, the presenter, the port and the scene run on the main actor, which is the thread of
the graphics context (the render host asserts it). `Core.prepare` runs off the main actor; its result crosses to
the main actor as a `Sendable` value.

## Tool: `scripts/check_experience_symbols.py`

```text
python3 scripts/check_experience_symbols.py --module pure            # release build of VisualCoreExperience on the host
python3 scripts/check_experience_symbols.py --module pure --with-flag
python3 scripts/check_experience_symbols.py --module host            # release build of VisualCoreExperienceHost, generic simulator
python3 scripts/check_experience_symbols.py --module host --with-flag
```

- Builds the module for release into `Build/experience-symbols/<module>[-flag]` (ignored by git): the pure module
  with `swift build -c release --target VisualCoreExperience`, the host module with `xcodebuild build -scheme
  VisualCoreExperienceHost -configuration Release -destination 'generic/platform=iOS Simulator'`. With
  `--with-flag` the condition `VISUALCORE_AUTOMATION` is added.
- Lists the symbols of the module's object files with `xcrun nm` and counts those that contain
  `ExperienceScenario`.
- Without the flag: prints `PASS: <module>, release, 0 automation symbols in <n> object files` and exits 0; any
  symbol is listed and the exit code is 1. With the flag the result is inverted: at least one symbol is required.
- Exit 2 when the build fails or no object file is found. Standard library only; it never touches a device.
