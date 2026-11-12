# Contract: pure API of ExperienceKit (module VisualCoreExperience, plus StableHash in VisualCoreMath)

All types are value types and `Sendable`. Nothing here imports UIKit, SwiftUI or a graphics module. Signatures are
the ones `/speckit-implement` builds; a deviation is recorded in research.md and in the API baseline.

## VisualCoreMath

```swift
/// SHA-256 (FIPS 180-4) in pure Swift. For content hashes and digests; not for security decisions.
public enum StableHash {
    public static func sha256(_ bytes: [UInt8]) -> [UInt8]      // 32 bytes
    public static func sha256Hex(_ bytes: [UInt8]) -> String    // 64 lower-case hexadecimal digits
}
```

Moved from `VisualCoreShaderSource/SHA256.swift` (internal `SHA256`). `ShaderCacheKey.make` and
`ShaderCacheKey.sha256Hex` keep their signatures and results.

## Errors and codes (`ExperienceError.swift`)

```swift
public struct ExperienceFailure: Error, Sendable, Equatable, Codable {
    public let code: String       // 1…64 characters of a-z, 0-9, ".", "-"; anything else becomes "experience.unspecified"
    public let message: String    // at most 500 characters; longer text is cut
    public init(code: String, message: String)
}

public enum DigestError: Error, Sendable, Equatable {
    case nonFinite(field: Int)                                  // "digest.non-finite"
    public var code: String { get }
}

public enum SnapshotError: Error, Sendable, Equatable {
    case wrongExperience(found: String)                         // "snapshot.wrong-experience"
    case unknownFormat(Int)                                     // "snapshot.unknown-format"
    case newerSchema(found: Int, current: Int)                  // "snapshot.newer-schema"
    case missingMigration(from: Int)                            // "snapshot.missing-migration"
    case corrupt(reason: String)                                // "snapshot.corrupt"
    case checksumMismatch                                       // "snapshot.checksum-mismatch"
    case tooLarge(bytes: Int)                                   // "snapshot.too-large"
    case stateMismatch(expected: String, found: String)         // "snapshot.state-mismatch"
    public var code: String { get }
}

public enum ActionRejection: Error, Sendable, Equatable, Codable {
    case unknownControl(String)                                 // "action.unknown-control"
    case wrongValueCount(expected: Int, found: Int)             // "action.wrong-value-count"
    case nonFinite(index: Int)                                  // "action.non-finite"
    case outOfRange(index: Int)                                 // "action.out-of-range"
    case notActive(ExperienceLifecycleState)                    // "action.not-active"
    case wrongStep(expected: Int, found: Int)                   // "action.wrong-step"
    case rule(code: String)                                     // "action.rule.<code>"
    public var code: String { get }
}

public enum ActionResult: Sendable, Equatable, Codable {
    case accepted
    case rejected(ActionRejection)
    public var isAccepted: Bool { get }
    public var code: String { get }                             // "accepted" or the rejection code
}

public enum ExperienceError: Error, Sendable, Equatable {
    case illegalOperation(ExperienceOperation, in: ExperienceLifecycleState)   // "experience.illegal-operation"
    case notPrepared                                            // "experience.not-prepared"
    case cancelled                                              // "experience.cancelled"
    case preparationTimedOut                                    // "experience.preparation-timeout"
    case stalePreparation                                       // "experience.stale-preparation"
    case failed(ExperienceFailure)                              // the failure's own code
    case invalidTier(Int, tiers: Int)                           // "experience.invalid-tier"
    case gpuLeak(live: Int, leaked: Int)                        // "experience.gpu-leak"
    case snapshot(SnapshotError)                                // the snapshot error's code
    case digest(DigestError)                                    // the digest error's code
    public var code: String { get }
    public var failure: ExperienceFailure { get }               // code and a readable message
}
```

Codes are part of the API: they never change once released.

## Lifecycle (`ExperienceLifecycle.swift`)

```swift
public enum ExperienceLifecycleState: String, Sendable, Codable, CaseIterable {
    case registered, preparing, ready, active, suspended, deactivating, inactive, failed
}

public enum ExperienceOperation: String, Sendable, Codable, CaseIterable {
    case prepare, activate, update, action, snapshot, restore, reset, setQualityTier, shedCaches, suspend, resume, deactivate
}

public struct ExperienceLifecycleEvent: Sendable, Codable, Equatable {
    public let from: ExperienceLifecycleState
    public let to: ExperienceLifecycleState
    public let accepted: Bool
    public init(from: ExperienceLifecycleState, to: ExperienceLifecycleState, accepted: Bool)
}

public struct ExperienceLifecycle: Sendable, Equatable {
    public private(set) var state: ExperienceLifecycleState     // starts .registered
    public private(set) var lastError: ExperienceFailure?
    public private(set) var history: [ExperienceLifecycleEvent] // oldest first, at most historyLimit
    public private(set) var rejectedTransitions: Int
    public private(set) var rejectedOperations: Int
    public let historyLimit: Int                                // clamped to ≥ 1; default 64
    public init(historyLimit: Int = 64)

    public static func isAllowed(from: ExperienceLifecycleState, to: ExperienceLifecycleState) -> Bool
    public static func isLegal(_ operation: ExperienceOperation, in state: ExperienceLifecycleState) -> Bool

    @discardableResult public mutating func transition(to next: ExperienceLifecycleState) -> Bool
    @discardableResult public mutating func fail(_ failure: ExperienceFailure) -> Bool
    public mutating func permit(_ operation: ExperienceOperation) throws(ExperienceError)
}
```

- `isAllowed` is true for exactly the 20 pairs of data-model.md section 1.
- `transition(to: .failed)` stores a failure with the code `experience.unspecified`; `fail(_:)` stores the given
  one. Both are rejected in `failed`.
- An accepted transition preparing → ready clears `lastError`.
- `permit` throws `.illegalOperation(operation, in: state)` and adds one to `rejectedOperations` when the
  operation is not legal in the current state; otherwise it does nothing.

## Digest (`StateDigest.swift`)

```swift
public struct StateDigest: Hashable, Sendable, Codable, CustomStringConvertible {
    public let hex: String                                      // 64 lower-case hexadecimal digits
    public init?(hex: String)                                   // nil unless exactly that form
    public var description: String { get }                      // the hex text; Codable as one string
}

public struct DigestBuilder: Sendable {
    public init(domain: String)                                 // the domain text is the first field
    public private(set) var fieldCount: Int
    public mutating func add(_ value: Int)
    public mutating func add(_ value: UInt64)
    public mutating func add(_ value: Bool)
    public mutating func add(_ value: String)
    public mutating func add(_ bytes: [UInt8])
    public mutating func add(_ value: Double) throws(DigestError)   // refuses NaN and infinities; −0 counts as 0
    public mutating func add(count: Int)                        // announces a sequence of that many following fields
    public func finish() -> StateDigest
}
```

Byte layout: data-model.md section 3.

## Actions (`ExperienceAction.swift`)

```swift
public struct ExperienceControl: Sendable, Equatable {
    public static let maxValues = 8
    public let id: String
    public let ranges: [ClosedRange<Double>]                    // one per value; entries beyond maxValues are dropped
    public init(id: String, ranges: [ClosedRange<Double>] = [])
}

public struct ExperienceAction: Sendable, Equatable, Codable {
    public let control: String
    public let values: [Double]
    public let step: Int
    public init(control: String, values: [Double] = [], step: Int)
}

public struct ScriptedAction: Sendable, Equatable, Codable {    // an action without its step, for plans and scenarios
    public let control: String
    public let values: [Double]
    public init(_ control: String, _ values: [Double] = [])
}

public enum ExperienceInput {
    /// nil when the action is well formed for the declared controls. Checks in this order: control, value count,
    /// finiteness (first index), range (first index).
    public static func validate(control: String, values: [Double], controls: [ExperienceControl]) -> ActionRejection?
    /// The position as fractions of the view (0…1 on both axes); nil outside the view, for a view without area or
    /// for values that are not finite.
    public static func normalized(x: Double, y: Double, width: Double, height: Double) -> (x: Double, y: Double)?
}
```

## Snapshot (`ExperienceSnapshot.swift`)

```swift
public struct ExperienceSnapshot: Sendable, Equatable, Codable {
    public static let format = 1
    public static let maxBytes = 1_048_576
    public let experience: ExperienceID
    public let schemaVersion: Int
    public let seed: UInt64
    public let stepIndex: Int
    public let digest: StateDigest
    public let payload: String                                  // UTF-8 text of one JSON object
    public let checksum: String                                 // StableHash.sha256Hex of the payload's UTF-8 bytes

    public init(experience: ExperienceID, schemaVersion: Int, seed: UInt64, stepIndex: Int, digest: StateDigest,
                payload: Data) throws(SnapshotError)
    public init(data: Data) throws(SnapshotError)
    public func encoded() throws(SnapshotError) -> Data
}
```

Encoded form and validation order: data-model.md section 4. The `Codable` conformance writes the same fields and
validates like `init(data:)`, so a `DocumentStore<ExperienceSnapshot>` reports a damaged snapshot as a corrupt
file.

## Core (`ExperienceCore.swift`)

```swift
public protocol ExperienceCore: Sendable {
    static var migrations: MigrationChain { get }               // schema version = migrations.currentVersion
    static var controls: [ExperienceControl] { get }
    static var qualityTiers: Int { get }                        // default 1
    static var stepDuration: Double { get }                     // seconds; default 1/120; used clamped to 1/240…1/30

    static func prepare(seed: UInt64) async throws -> Self      // deterministic; checks Task cancellation
    mutating func update(step: Int)                             // one fixed step; no clock, no randomness beyond state
    mutating func apply(_ action: ExperienceAction) -> ActionResult   // sees only well-formed actions
    mutating func reset()                                       // the state of a fresh preparation with the same seed
    mutating func setQualityTier(_ tier: Int)                   // default: nothing; never changes the digest
    mutating func shedCaches()                                  // default: nothing; never changes the digest
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError)
    func snapshotPayload() throws -> Data                       // UTF-8 JSON object; default for Codable cores (sorted keys)
    static func restore(payload: Data, seed: UInt64) throws -> Self   // default for Codable cores
}
```

A core throws `ExperienceFailure` for its own failures; any other error becomes a failure with the code
`experience.preparation-failed`.

## Engine (`ExperienceEngine.swift`)

```swift
public struct PreparationTicket: Sendable, Equatable { public let generation: Int }

public struct ExperienceEngine<Core: ExperienceCore>: Sendable {
    public let id: ExperienceID
    public private(set) var lifecycle: ExperienceLifecycle
    public private(set) var core: Core?                         // nil before preparation and after deactivation
    public private(set) var seed: UInt64?
    public private(set) var stepIndex: Int
    public private(set) var qualityTier: Int
    public private(set) var clock: FixedStepClock
    public private(set) var acceptedActions: Int
    public private(set) var rejectedActions: Int
    public private(set) var discardedPreparations: Int
    public static var schemaVersion: Int { get }
    public static var stepDuration: Double { get }              // Core.stepDuration clamped
    public init(id: ExperienceID, maxStepsPerFrame: Int = 8)

    // preparation
    public mutating func beginPreparation(seed: UInt64) throws(ExperienceError) -> PreparationTicket
    public static func prepare(seed: UInt64, timeLimit: Duration? = nil) async -> Result<Core, ExperienceError>
    @discardableResult
    public mutating func completePreparation(_ ticket: PreparationTicket, with result: Result<Core, ExperienceError>) -> Bool
    public mutating func prepare(seed: UInt64, timeLimit: Duration? = nil) async throws(ExperienceError)   // the three above

    // lifecycle
    public mutating func activate() throws(ExperienceError)
    public mutating func suspend() throws(ExperienceError)
    public mutating func resume() throws(ExperienceError)       // discards accumulated time
    public mutating func beginDeactivation() throws(ExperienceError)   // in preparing: cancels and ends in inactive
    public mutating func finishDeactivation(gpu: GPUResourceCounts? = nil) throws(ExperienceError)
    public mutating func fail(_ failure: ExperienceFailure)

    // time and input
    @discardableResult public mutating func advance(frame delta: Double) throws(ExperienceError) -> Int
    public mutating func run(steps: Int) throws(ExperienceError)
    public mutating func handle(control: String, values: [Double] = []) -> ActionResult   // stamps the current step
    public mutating func handle(_ action: ExperienceAction) -> ActionResult

    // state
    public mutating func snapshot() throws(ExperienceError) -> ExperienceSnapshot
    public mutating func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError)
    public mutating func reset() throws(ExperienceError)
    public mutating func setQualityTier(_ tier: Int) throws(ExperienceError)
    public mutating func shedCaches() throws(ExperienceError)
    public func digest() throws(ExperienceError) -> StateDigest
    public func diagnostics(gpu: GPUResourceCounts? = nil) -> ExperienceDiagnostics
}
```

Rules:

- Every operation first calls `lifecycle.permit`; a refused operation does not touch the core.
- `beginPreparation` moves to preparing and returns a new generation. `completePreparation` returns false and adds
  one to `discardedPreparations` when the ticket's generation is not the current one or the state is not
  preparing. With a success it stores core and seed, sets the step index to 0, applies the current tier when it is
  not 0 and moves to ready. With `.cancelled` it moves to deactivating and then inactive. With any other error it
  moves to failed.
- The static `prepare` runs `Core.prepare` under the time limit. It returns `.cancelled` when the task was
  cancelled and `.preparationTimedOut` when the limit passed; the limit works because a core checks cancellation.
- `beginDeactivation` in preparing invalidates the ticket and ends in inactive at once. In ready, active, suspended
  and failed it moves to deactivating; `finishDeactivation` then drops the core and moves to inactive, or to
  failed with `.gpuLeak` when the given counts show a live or leaked object.
- `advance` runs 0…8 steps from the clock and returns their number; `run(steps:)` runs exactly `steps` (negative
  counts as 0). Both need active.
- `handle` answers `.rejected(.notActive(state))` outside active (also counted as a refused operation), then
  `.wrongStep` when the action's step is not the current step index, then the result of `ExperienceInput.validate`,
  then the core's answer. When the core rejects, the engine puts back the copy it took before the call.
- `snapshot` is legal in ready, active and suspended. `restore` checks, in this order: experience id, schema
  version, checksum, migration, decoding, and (at the current schema version) the digest; only then it replaces
  core, seed and step index. A refused restore changes nothing.
- `reset` calls `core.reset()`, sets the step index to 0 and discards accumulated time.
- `digest()` builds with the domain text `id.rawValue`.

## Diagnostics (`ExperienceDiagnostics.swift`)

```swift
public struct GPUResourceCounts: Sendable, Equatable, Codable {
    public let objects: Int
    public let bytes: Int
    public let leaked: Int
    public init(objects: Int, bytes: Int, leaked: Int)
}

public struct ExperienceDiagnostics: Sendable, Equatable, Codable {
    public let experience: ExperienceID
    public let state: ExperienceLifecycleState
    public let seed: UInt64?                // written as text
    public let stepIndex: Int
    public let qualityTier: Int
    public let gpu: GPUResourceCounts?      // nil without a render host
    public let lastError: ExperienceFailure?
    public let digest: StateDigest?         // nil without a prepared core
    public let rejectedTransitions: Int
    public let rejectedOperations: Int
    public let acceptedActions: Int
    public let rejectedActions: Int
    public let droppedTime: Double
    public let invalidFrames: Int
    public func encoded() throws -> Data    // sorted keys, for evidence files
}
```

## Conformance (`ExperienceConformance.swift`)

```swift
public enum ConformanceCheck: String, Sendable, Codable, CaseIterable {
    case seedDeterminism, snapshotRoundTrip, resetEquivalence, rejectionKeepsDigest, tierKeepsDigest,
         sheddingKeepsDigest, replayReproducesDigest
}

public struct ConformancePlan: Sendable {
    public var seeds: [UInt64]              // the first 64 are used; an empty list means [0]
    public var stepsPerSegment: Int         // clamped to 0…10,000
    public var actions: [ScriptedAction]    // expected to be accepted; one segment each; the first 1,000 are used
    public var rejected: [ScriptedAction]   // expected to be rejected
    public init(seeds: [UInt64], stepsPerSegment: Int, actions: [ScriptedAction], rejected: [ScriptedAction])
}

public struct ConformanceReport: Sendable, Equatable, Codable {
    public struct Entry: Sendable, Equatable, Codable {
        public let check: ConformanceCheck
        public let passed: Bool
        public let detail: String
    }
    public let entries: [Entry]             // one per check, in the order of ConformanceCheck.allCases
    public var passed: Bool { get }
    public var failed: [ConformanceCheck] { get }
}

public enum ExperienceConformance {
    public static func run<Core: ExperienceCore>(_ core: Core.Type, id: ExperienceID, plan: ConformancePlan) async -> ConformanceReport
}
```

What each check does: data-model.md section 6. The helper imports no test framework.

As built (T-U02-041): `ConformancePlan` also offers `maxSeeds` (64), `maxStepsPerSegment` (10,000), `maxActions`
(1,000) and the values in use, `effectiveSeeds`, `effectiveStepsPerSegment` and `effectiveActions`. When a seed
cannot be prepared, only the seed-determinism check is recorded as failed for it.

## Automation hooks (`ExperienceScenario.swift`, only under `DEBUG || VISUALCORE_AUTOMATION`)

```swift
public struct ExperienceScenario: Sendable, Equatable, Codable {
    public struct Entry: Sendable, Equatable, Codable {
        public let steps: Int
        public let action: ScriptedAction?
        public init(steps: Int, action: ScriptedAction? = nil)
    }
    public static let maxEntries = 10_000
    public static let maxSteps = 1_000_000
    public let seed: UInt64
    public let entries: [Entry]
    public init(seed: UInt64, entries: [Entry])
}

public struct ExperienceScenarioResult: Sendable, Equatable, Codable {
    public let digest: StateDigest?
    public let stepIndex: Int
    public let results: [String]            // one code per action, in order
    public let error: ExperienceFailure?
}

extension ExperienceEngine {
    public mutating func run(_ scenario: ExperienceScenario) -> ExperienceScenarioResult          // on an active engine
    public static func runScenario(_ scenario: ExperienceScenario, id: ExperienceID) async -> ExperienceScenarioResult
}
```

Entries beyond the limits are not run and the result carries the error code `experience.scenario-too-large`.

## Sample (module VisualCoreTestSupport, tests only)

```swift
public protocol SampleFault: Sendable { static var kind: SampleFaultKind { get } }
public enum SampleFaultKind: String, Sendable, CaseIterable {
    case none, unseededPreparation, lossySnapshot, wrongReset, mutatingRejection, tierChangesState,
         sheddingChangesState, clockInUpdate, slowPreparation, failingPreparation
}
public enum NoFault: SampleFault { … }      // and one marker type per kind
public struct SampleExperienceCore<Fault: SampleFault>: ExperienceCore, Codable, Equatable { … }
public enum SampleExperience {
    public static let id: ExperienceID      // a99.contract-sample
    public static let plan: ConformancePlan
    public static let goldenDigests: [(seed: UInt64, hex: String)]   // 8 entries
    public static func snapshotV1(seed: UInt64) -> Data              // a version-1 snapshot for the migration tests
}
```

Sample rules: data-model.md section 7.
