// ExperienceEngine — feature 188 T-U02-016 and later increments (FR-U02-006, FR-U02-007, FR-U02-011 to FR-U02-017,
// FR-U02-021 to FR-U02-025; research R2; contract specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md).
// The pure driver of one experience core: it owns the lifecycle, the fixed-step clock and the core value, lets every
// operation through the lifecycle first, and so answers every call in every state. A value type: a copy of an engine
// is an independent run from the same state.
import Foundation
import VisualCoreMath
import VisualCorePersistence
import VisualCoreSimulation

/// Names one started preparation, so that a result that arrives late can be told from the current one.
public struct PreparationTicket: Sendable, Equatable {
    /// The number of the preparation this ticket belongs to.
    public let generation: Int
}

/// Drives one `ExperienceCore` through the experience lifecycle.
public struct ExperienceEngine<Core: ExperienceCore>: Sendable {
    /// The code used when a core throws something that is neither an `ExperienceFailure` nor an `ExperienceError`.
    public static var preparationFailedCode: String { "experience.preparation-failed" }

    /// The experience this engine runs.
    public let id: ExperienceID
    /// The lifecycle: state, last error, refusal counters and history.
    public private(set) var lifecycle = ExperienceLifecycle()
    /// The domain state; nil before the first preparation, while preparing and after deactivation.
    public private(set) var core: Core?
    /// The seed of the current or last preparation, or of the restored snapshot; nil before the first preparation.
    public private(set) var seed: UInt64?
    /// Steps run since preparation, reset or the restored snapshot's capture.
    public private(set) var stepIndex = 0
    /// The current quality tier (0 is the best).
    public private(set) var qualityTier = 0
    /// The fixed-step clock; its counters report dropped time and invalid frames.
    public private(set) var clock: FixedStepClock
    /// Actions carried out.
    public private(set) var acceptedActions = 0
    /// Actions rejected.
    public private(set) var rejectedActions = 0
    /// Preparation results that were discarded because they were no longer current.
    public private(set) var discardedPreparations = 0
    private var generation = 0

    /// The schema version of the experience's snapshot payload.
    public static var schemaVersion: Int { Core.migrations.currentVersion }
    /// The step length in use: the core's `stepDuration` brought into 1/240…1/30 s (1/120 s when it is not finite).
    public static var stepDuration: Double {
        let declared = Core.stepDuration
        guard declared.isFinite else { return 1.0 / 120 }
        return min(max(declared, 1.0 / 240), 1.0 / 30)
    }

    /// Creates an engine in the state registered. `maxStepsPerFrame` is clamped to 1…8 by the clock.
    public init(id: ExperienceID, maxStepsPerFrame: Int = 8) {
        self.id = id
        clock = FixedStepClock(step: Self.stepDuration, maxSteps: maxStepsPerFrame)
    }

    // MARK: Preparation

    /// Starts a preparation: moves to preparing, drops any earlier state and returns the ticket of this preparation.
    public mutating func beginPreparation(seed: UInt64) throws(ExperienceError) -> PreparationTicket {
        try lifecycle.permit(.prepare)
        lifecycle.transition(to: .preparing)
        generation += 1
        core = nil
        self.seed = seed
        stepIndex = 0
        return PreparationTicket(generation: generation)
    }

    /// Runs the core's preparation, anywhere, under an optional time limit. Never throws: the result says what
    /// happened. A cancelled task gives `.cancelled`, an exceeded limit `.preparationTimedOut`. The limit works
    /// because a core checks for cancellation between its units of work.
    public static func prepare(seed: UInt64, timeLimit: Duration? = nil) async -> Result<Core, ExperienceError> {
        do {
            let prepared: Core
            if let timeLimit {
                prepared = try await withThrowingTaskGroup(of: Core?.self) { group in
                    defer { group.cancelAll() }
                    group.addTask { try await Core.prepare(seed: seed) }
                    group.addTask {
                        try await Task.sleep(for: timeLimit)
                        return nil
                    }
                    guard let first = try await group.next() else { throw ExperienceError.cancelled }
                    guard let value = first else { throw ExperienceError.preparationTimedOut }
                    return value
                }
            } else {
                prepared = try await Core.prepare(seed: seed)
            }
            try Task.checkCancellation()
            return .success(prepared)
        } catch {
            return .failure(mapped(error))
        }
    }

    private static func mapped(_ error: any Error) -> ExperienceError {
        if error is CancellationError { return .cancelled }
        if let known = error as? ExperienceError { return known }
        if let failure = error as? ExperienceFailure { return .failed(failure) }
        return .failed(ExperienceFailure(code: preparationFailedCode, message: String(describing: error)))
    }

    /// Ends the preparation named by `ticket`. Returns false, and counts the result as discarded, when the ticket is
    /// not the current one or the engine is no longer preparing. A success leads to ready, `.cancelled` to inactive,
    /// any other error to failed.
    @discardableResult
    public mutating func completePreparation(_ ticket: PreparationTicket, with result: Result<Core, ExperienceError>) -> Bool {
        guard ticket.generation == generation, lifecycle.state == .preparing else {
            discardedPreparations += 1
            return false
        }
        switch result {
        case .success(var prepared):
            if qualityTier != 0 { prepared.setQualityTier(qualityTier) }
            core = prepared
            stepIndex = 0
            clock.resetAccumulator()
            lifecycle.transition(to: .ready)
        case .failure(.cancelled):
            lifecycle.transition(to: .deactivating)
            lifecycle.transition(to: .inactive)
        case .failure(let error):
            lifecycle.fail(error.failure)
        }
        return true
    }

    /// Begins, runs and completes a preparation. Throws the error of a failed preparation, and `.stalePreparation`
    /// when the result was discarded.
    public mutating func prepare(seed: UInt64, timeLimit: Duration? = nil) async throws(ExperienceError) {
        let ticket = try beginPreparation(seed: seed)
        let result = await Self.prepare(seed: seed, timeLimit: timeLimit)
        guard completePreparation(ticket, with: result) else { throw .stalePreparation }
        if case .failure(let error) = result { throw error }
    }

    // MARK: Lifecycle

    /// ready → active. Time starts fresh.
    public mutating func activate() throws(ExperienceError) {
        try lifecycle.permit(.activate)
        lifecycle.transition(to: .active)
        clock.resetAccumulator()
    }

    /// active → suspended. No step runs until `resume()`.
    public mutating func suspend() throws(ExperienceError) {
        try lifecycle.permit(.suspend)
        lifecycle.transition(to: .suspended)
    }

    /// suspended → active. Time accumulated before the suspension is discarded: there is no catch-up.
    public mutating func resume() throws(ExperienceError) {
        try lifecycle.permit(.resume)
        lifecycle.transition(to: .active)
        clock.resetAccumulator()
    }

    /// Starts leaving the experience. While preparing, this cancels the preparation and ends in inactive at once;
    /// otherwise it moves to deactivating, and `finishDeactivation(gpu:)` ends the leave.
    public mutating func beginDeactivation() throws(ExperienceError) {
        try lifecycle.permit(.deactivate)
        let wasPreparing = lifecycle.state == .preparing
        generation += 1
        lifecycle.transition(to: .deactivating)
        if wasPreparing { lifecycle.transition(to: .inactive) }
    }

    /// Ends the leave: drops the core and moves to inactive. Legal only while deactivating.
    public mutating func finishDeactivation(gpu: GPUResourceCounts? = nil) throws(ExperienceError) {
        let state = lifecycle.state
        guard state == .deactivating else {
            lifecycle.transition(to: .inactive)
            throw .illegalOperation(.deactivate, in: state)
        }
        core = nil
        lifecycle.transition(to: .inactive)
    }

    /// Records a failure from outside the engine (setup or drawing): any state but failed → failed. A preparation
    /// that is still running is no longer current.
    public mutating func fail(_ failure: ExperienceFailure) {
        generation += 1
        lifecycle.fail(failure)
    }

    // MARK: Time

    /// Adds a frame's elapsed time and runs the fixed steps it yields (0…8). Legal only while active. Time beyond
    /// the per-frame limit is counted as dropped by the clock; a negative or non-finite time runs no step.
    @discardableResult
    public mutating func advance(frame delta: Double) throws(ExperienceError) -> Int {
        try lifecycle.permit(.update)
        guard core != nil else { throw .notPrepared }
        let steps = clock.advance(by: delta)
        runSteps(steps)
        return steps
    }

    /// Runs exactly `steps` fixed steps without the clock (replays, tests, automation); a negative count is 0.
    public mutating func run(steps: Int) throws(ExperienceError) {
        try lifecycle.permit(.update)
        guard core != nil else { throw .notPrepared }
        runSteps(max(steps, 0))
    }

    private mutating func runSteps(_ count: Int) {
        guard count > 0, var current = core else { return }
        core = nil
        for _ in 0..<count {
            current.update(step: stepIndex)
            stepIndex += 1
        }
        core = current
    }

    // MARK: Input

    /// Carries out an action made now: it is stamped with the current step index.
    @discardableResult
    public mutating func handle(control: String, values: [Double] = []) -> ActionResult {
        handle(ExperienceAction(control: control, values: values, step: stepIndex))
    }

    /// Carries out `action` or rejects it with a typed reason. The contract checks, in this order: the lifecycle
    /// state, the step index, the control, the number of values, finiteness and ranges; only a well-formed action
    /// reaches the core. When the core rejects, the state it had before the call is put back, so a rejected action
    /// never changes the digest.
    @discardableResult
    public mutating func handle(_ action: ExperienceAction) -> ActionResult {
        let result = carryOut(action)
        if result.isAccepted { acceptedActions += 1 } else { rejectedActions += 1 }
        return result
    }

    private mutating func carryOut(_ action: ExperienceAction) -> ActionResult {
        do {
            try lifecycle.permit(.action)
        } catch {
            return .rejected(.notActive(lifecycle.state))
        }
        guard let before = core else { return .rejected(.notActive(lifecycle.state)) }
        guard action.step == stepIndex else {
            return .rejected(.wrongStep(expected: stepIndex, found: action.step))
        }
        if let rejection = ExperienceInput.validate(control: action.control, values: action.values, controls: Core.controls) {
            return .rejected(rejection)
        }
        var current = before
        let result = current.apply(action)
        core = result.isAccepted ? current : before
        return result
    }

    // MARK: State

    /// The digest of the current domain state, with the experience id as domain.
    public func digest() throws(ExperienceError) -> StateDigest {
        guard let core else { throw .notPrepared }
        return try digest(of: core)
    }

    private func digest(of core: Core) throws(ExperienceError) -> StateDigest {
        var builder = DigestBuilder(domain: id.rawValue)
        do {
            try core.writeDigest(into: &builder)
        } catch {
            throw .digest(error)
        }
        return builder.finish()
    }

    /// Captures the state as a versioned envelope. Legal while ready, active or suspended.
    public mutating func snapshot() throws(ExperienceError) -> ExperienceSnapshot {
        try lifecycle.permit(.snapshot)
        guard let core, let seed else { throw .notPrepared }
        let payload: Data
        do {
            payload = try core.snapshotPayload()
        } catch {
            throw .snapshot(.corrupt(reason: "the payload could not be written: \(error)"))
        }
        let digest = try digest(of: core)
        do {
            return try ExperienceSnapshot(experience: id, schemaVersion: Self.schemaVersion, seed: seed,
                                          stepIndex: stepIndex, digest: digest, payload: payload)
        } catch {
            throw .snapshot(error)
        }
    }

    /// Replaces the state by the one in `snapshot`. Checks, in this order: experience id, schema version,
    /// checksum, migration, decoding and, at the current schema version, the digest. A refused restore changes
    /// nothing. Legal while ready, active or suspended.
    public mutating func restore(_ snapshot: ExperienceSnapshot) throws(ExperienceError) {
        try lifecycle.permit(.restore)
        guard snapshot.experience == id else {
            throw .snapshot(.wrongExperience(found: snapshot.experience.rawValue))
        }
        let current = Self.schemaVersion
        guard snapshot.schemaVersion <= current else {
            throw .snapshot(.newerSchema(found: snapshot.schemaVersion, current: current))
        }
        let bytes = Array(snapshot.payload.utf8)
        guard StableHash.sha256Hex(bytes) == snapshot.checksum else { throw .snapshot(.checksumMismatch) }
        var payload = Data(bytes)
        if snapshot.schemaVersion < current {
            payload = try Self.migrated(payload, from: snapshot.schemaVersion)
        }
        var candidate: Core
        do {
            candidate = try Core.restore(payload: payload, seed: snapshot.seed)
        } catch {
            throw .snapshot(.corrupt(reason: "the payload does not decode: \(error)"))
        }
        if snapshot.schemaVersion == current {
            let found = try digest(of: candidate)
            guard found == snapshot.digest else {
                throw .snapshot(.stateMismatch(expected: snapshot.digest.hex, found: found.hex))
            }
        } else {
            _ = try digest(of: candidate)
        }
        if qualityTier != 0 { candidate.setQualityTier(qualityTier) }
        core = candidate
        seed = snapshot.seed
        stepIndex = snapshot.stepIndex
        clock.resetAccumulator()
    }

    private static func migrated(_ payload: Data, from version: Int) throws(ExperienceError) -> Data {
        guard let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else {
            throw .snapshot(.corrupt(reason: "the payload is not a JSON object"))
        }
        do {
            let upgraded = try Core.migrations.migrate(object, from: version)
            guard JSONSerialization.isValidJSONObject(upgraded) else {
                throw ExperienceError.snapshot(.corrupt(reason: "a migration step produced a value that is not JSON"))
            }
            return try JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys])
        } catch let error as ExperienceError {
            throw error
        } catch MigrationError.missingStep(let missing) {
            throw .snapshot(.missingMigration(from: missing))
        } catch {
            throw .snapshot(.corrupt(reason: "the migration failed: \(error)"))
        }
    }

    /// Returns to the state of a fresh preparation with the current seed; the step index is 0 again. Legal while
    /// ready, active or suspended.
    public mutating func reset() throws(ExperienceError) {
        try lifecycle.permit(.reset)
        guard var current = core else { throw .notPrepared }
        core = nil
        current.reset()
        core = current
        stepIndex = 0
        clock.resetAccumulator()
    }
}
