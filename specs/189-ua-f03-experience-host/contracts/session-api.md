# Contract: session API (UA-F03)

## Pure part (module VisualCoreExperience, file `SessionLifecycle.swift`)

```swift
public enum SessionState: String, Sendable, Codable, CaseIterable { case idle, preparing, running, suspended, failed, message, closing }
public enum ScenePhaseInput: String, Sendable, Codable, CaseIterable { case active, inactive, background }
public enum SessionCloseStep: String, Sendable, Codable, CaseIterable {
    case stopClock, handOutSnapshot, beginDeactivation, destroyHost, readCounts, finishDeactivation, becomeIdle, cancelPreparation
    public static let order: [SessionCloseStep]            // the seven steps of a full close
    public static let cancelOrder: [SessionCloseStep]      // cancelPreparation, becomeIdle
}
public enum SessionStage: String, Sendable, Codable, CaseIterable { case prepare, restore, createHost, setup, draw, context, close }
public struct SessionFailure: Error, Sendable, Equatable, Codable {
    public let failure: ExperienceFailure
    public let stage: SessionStage
    public init(_ failure: ExperienceFailure, stage: SessionStage)
    public static let hostFailedCode = "session.host-failed"
    public static let contextLostCode = "session.context-lost"
    public static let sinkFailedCode = "session.sink-failed"
}
public struct SessionStageTimings: Sendable, Equatable, Codable {
    public var prepare: Double?, createHost: Double?, activate: Double?, firstFrame: Double?
    public init()
}
public enum SessionOpenResult: Sendable, Equatable { case running, suspended, failed(SessionFailure), cancelled, superseded }
public enum MemoryPressureRule {
    public static func limit(requested: Int?, budgetTotal: Int) -> Int          // requested, else half the total, at least 1
    public static func shouldClose(liveBytes: Int, limit: Int) -> Bool          // liveBytes > limit
}
public struct SessionLifecycle: Sendable, Equatable {
    public private(set) var state: SessionState                                 // starts .idle
    public private(set) var rejectedTransitions: Int
    public init()
    public static func isAllowed(from: SessionState, to: SessionState) -> Bool
    @discardableResult public mutating func transition(to next: SessionState) -> Bool
}
public struct SessionDiagnostics: Sendable, Equatable, Codable { … the fields of data-model.md section 6 …; public func encoded() throws -> Data }
```

## Main-actor part (module VisualCoreExperienceHost)

```swift
public struct ExperienceOpenRequest {
    public let id: ExperienceID
    public let make: @MainActor () -> any Experience
    public var seed: UInt64
    public var snapshot: ExperienceSnapshot?
    public var budget: ResourceBudget                       // default ResourceBudget()
    public var memoryPressureLimit: Int?                    // default nil: half of the budget's total
    public var timeLimit: Duration                          // default 10 s
    public init(id: ExperienceID, seed: UInt64, snapshot: ExperienceSnapshot? = nil, budget: ResourceBudget = ResourceBudget(),
                memoryPressureLimit: Int? = nil, timeLimit: Duration = .seconds(10), make: @escaping @MainActor () -> any Experience)
}

@MainActor @Observable
public final class ExperienceSession {
    public typealias SnapshotSink = @MainActor (ExperienceSnapshot) throws -> Void
    public init(snapshotSink: SnapshotSink? = nil)
    public private(set) var state: SessionState
    public private(set) var experience: (any Experience)?
    public private(set) var renderHost: RenderHost?
    public private(set) var failure: SessionFailure?        // shown by the failure view
    public private(set) var message: String?                // shown by the message view
    public private(set) var phase: ScenePhaseInput          // starts .active
    public var diagnostics: SessionDiagnostics { get }
    public var hostsAlive: Int { get }                      // render hosts created by this session and not destroyed

    @discardableResult public func open(_ request: ExperienceOpenRequest) async -> SessionOpenResult
    public func close()                                     // any state; nothing when idle
    @discardableResult public func retry() async -> SessionOpenResult   // only when failed
    public func back()                                      // failed or message → idle
    public func setScenePhase(_ phase: ScenePhaseInput)
    public func handleMemoryWarning()
    public func recreateContext()                           // forces a context recreation of the open host (tests, recovery)
}

public struct ExperienceHostView: View {
    public init(session: ExperienceSession)
}
```

Behavior:

| Call | What happens |
|---|---|
| `open` | new generation; closes what is open (full close or cancel); idle/failed/message → preparing; builds the experience; `prepare(seed:timeLimit:)`; a stale generation returns `.superseded` (after a `close()`: `.cancelled`) and releases what it built; a refused snapshot is recorded and ignored; creates the render host with the budget and registers the error observer; phase active: `activate()`, state running, first frame when a surface exists; phase not active: state suspended with the host paused; an error at any stage → `fail` and `.failed` |
| `close` | preparing: cancel, state idle, counted; running or suspended: the seven steps of `SessionCloseStep.order`, a leak or a sink error is recorded, state idle; failed or message: as `back()`; idle or closing: nothing |
| `fail` (internal) | records the failure and its stage, destroys the host when one exists (reading the counts), state failed |
| `retry` | failed → `open` with the last request |
| `back` | failed or message → idle; the failure and message are cleared from view state and stay in the diagnostics |
| `setScenePhase` | to background or inactive while running: `experience.suspend()`, snapshot to the sink, `host.pause()`, state suspended; to active while suspended: `host.resume()`, `experience.resume()`, state running; in other states only the phase is stored |
| `handleMemoryWarning` | with an experience in ready, active or suspended: `shedCaches()`; then the pressure rule on `host.resources.stats.totalBytes`; over the limit: snapshot, full close, state message |
| `recreateContext` | `host.recreateContext()`, counted; when the host then reports an unrecoverable error: `fail` with `session.context-lost` |
| deinit | removes the memory-warning observer; destroys a host that is still alive |

As built (recorded after T-U03-007 and T-U03-009):

- The render host receives a forwarding scene of the session, which passes setup, resize, render and teardown to
  the experience's scene unchanged and tells the session after each frame drawn without error. That is how the
  first-frame time is taken: at the first real frame while running, in seconds since activation.
- `deinit` only removes the memory-warning observer; the owner calls `close()` before it releases the session.
- Counters: an open that replaces a preparing open counts in `cancelledPreparations` and in `supersededOpens`; a
  memory closure counts in `closes` and in `memoryClosures`; a context loss reported by the host counts in
  `contextRecreations` like a forced recreation. `lastCloseCounts` is written only when a host was destroyed.
- A snapshot is taken at close and at suspension only when a sink exists; the close step is recorded either way.
- Further public members: `lastRestoreRefusal` and `lastSinkFailure` (both `ExperienceFailure?`), the view types
  `SessionPreparingView`, `SessionFailureView`, `SessionMessageView`, `SessionButtonStyle` (minimum 44 points) and
  the identifier constants `SessionViewID`. The controls below the canvas scroll within at most 280 points.

Identifiers of the host view's own controls: `session.cancel`, `session.retry`, `session.back`,
`session.failure`, `session.message`, `session.preparing`, `session.canvas`.

## Tool: `scripts/check_app_isolation.py`

```text
python3 scripts/check_app_isolation.py --app Apps/VisualCore [--require-sources]
python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative Packages/ExperiencesRound02 …
```

Output and exit codes: data-model.md section 7; exit 0 pass, 1 problems (or no sources with
`--require-sources`), 2 bad input. `--experiences` also refuses direct `gl…(` and `vcgl…(` calls. `--app` keeps
every existing behavior for existing folders.
