// BenchCore — feature 174 (A24-P02) T-A24-207 (FR-A24-205; clarification Q3; data-model.md "BenchCore";
// contracts/experience.md "Core"). The state of Graphics Benchmark Lab as an experience: the selected built-in case
// (an index into `BenchmarkCase.builtIn`: quads, alu, particles) and two request counters the presenter acts on. The
// core never draws, never measures and reads no clock: a run, its samples and its summary live in the presenter's
// `RunRecorder` (the last summary is shown, not stored; storage is A24-P04).
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses them itself with the same reasons):
//   case.select [0…2]   selects the case at that index of `BenchmarkCase.builtIn`; a fraction is refused with
//                       `a24.not-whole`, an index that names no case with `a24.unknown-case`;
//   run.start []        counts one more start request (`startRequests`); the presenter starts a run when it sees the
//                       count rise;
//   run.stop []         counts one more stop request (`stopRequests`); the presenter stops a running run.
// The counters saturate at `Int.max`. A refused action changes nothing.
//
// Digest ("a24.graphics-benchmark-lab.v1"): the domain, then the selected case's index and id. The request counters
// are in the snapshot, not in the digest. Snapshot schema 1: the JSON object `{"selectedCase", "startRequests",
// "stopRequests"}` with sorted keys. Restoring a damaged payload throws `BenchRestoreRefusal.damaged`; a case index
// outside 0…2 or a negative counter throws `.outOfRange(_:)` naming the field. A restored snapshot never resumes a
// run (the presenter adopts the counters of the first state it draws). Outcome: `case-<id>` of the selected case
// (lead's choice, recorded here: the completion scenario needs an outcome, and the selected case is the one result an
// action gives). Quality: one tier, `level-0`.
import Foundation
import GraphicsBenchmarkLabCore
import VisualCoreExperience
import VisualCorePersistence

/// The rule ids of Graphics Benchmark Lab's refusals (feature 174).
public enum BenchRule {
    /// A case index that is not a whole number.
    public static let notWhole = "a24.not-whole"
    /// A case index that names no built-in case.
    public static let unknownCase = "a24.unknown-case"

    /// The two rule ids of clarification Q3.
    public static let all = [notWhole, unknownCase]
}

/// Why a saved Graphics Benchmark Lab state was refused on restore (feature 174). A refused restore changes nothing.
public enum BenchRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"selectedCase", "startRequests", "stopRequests"}` or a field has the
    /// wrong type.
    case damaged
    /// A field is outside its range; the value names it (`selectedCase`, `startRequests` or `stopRequests`).
    case outOfRange(String)
}

/// The state of Graphics Benchmark Lab (see the file header). Snapshot schema 1.
public struct BenchCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a24.graphics-benchmark-lab"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a24.graphics-benchmark-lab.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["case.select", "run.start", "run.stop"]
    /// The cases a person can choose, in the order of `case.select`.
    public static let cases: [BenchmarkCase] = BenchmarkCase.builtIn
    /// The accepted index of `case.select`.
    public static let caseRange: ClosedRange<Double> = 0...Double(BenchmarkCase.builtIn.count - 1)
    /// The prefix of the outcome code (`case-quads`, `case-alu`, `case-particles`).
    public static let outcomePrefix = "case-"

    /// The index of the selected case in ``cases``.
    public private(set) var selectedCase: Int
    /// How many `run.start` actions were accepted.
    public private(set) var startRequests: Int
    /// How many `run.stop` actions were accepted.
    public private(set) var stopRequests: Int

    /// The opening state: the first case (quads), no request.
    public init() {
        self.init(selectedCase: 0, startRequests: 0, stopRequests: 0)
    }

    /// A state with the values as given (nothing is checked; ``restore(payload:seed:)`` checks).
    public init(selectedCase: Int, startRequests: Int = 0, stopRequests: Int = 0) {
        self.selectedCase = selectedCase
        self.startRequests = startRequests
        self.stopRequests = stopRequests
    }

    /// The selected case; the first case when the index names none (only an unchecked `init` can make one).
    public var benchmarkCase: BenchmarkCase {
        Self.cases.indices.contains(selectedCase) ? Self.cases[selectedCase] : Self.cases[0]
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "case.select", ranges: [caseRange]),
        ExperienceControl(id: "run.start", ranges: []),
        ExperienceControl(id: "run.stop", ranges: []),
    ]

    /// The three controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> BenchCore {
        try Task.checkCancellation()
        return BenchCore()
    }

    /// A host step changes nothing: the state changes only by actions.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        switch action.control {
        case "case.select":
            guard let value = action.values.first else { return .accepted }
            guard value.isFinite, value == value.rounded() else { return .rejected(.rule(code: BenchRule.notWhole)) }
            let index = Int(value)
            guard Self.cases.indices.contains(index) else { return .rejected(.rule(code: BenchRule.unknownCase)) }
            selectedCase = index
        case "run.start":
            if startRequests < Int.max { startRequests += 1 }
        case "run.stop":
            if stopRequests < Int.max { stopRequests += 1 }
        default:
            break
        }
        return .accepted
    }

    /// Back to the opening state.
    public mutating func reset() {
        self = BenchCore()
    }

    /// `case-<id>` of the selected case.
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.outcomePrefix + benchmarkCase.id)
    }

    /// "a24.graphics-benchmark-lab.v1", then the selected case's index and id (not the request counters).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(selectedCase)
        builder.add(benchmarkCase.id)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The index of the selected case.
        var selectedCase: Int
        /// The accepted start requests.
        var startRequests: Int
        /// The accepted stop requests.
        var stopRequests: Int
    }

    /// The JSON object `{"selectedCase", "startRequests", "stopRequests"}` with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(selectedCase: selectedCase, startRequests: startRequests,
                                          stopRequests: stopRequests))
    }

    /// The core of `payload` (see the file header for the refusals). The seed changes nothing.
    public static func restore(payload: Data, seed: UInt64) throws -> BenchCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw BenchRestoreRefusal.damaged
        }
        guard cases.indices.contains(decoded.selectedCase) else {
            throw BenchRestoreRefusal.outOfRange("selectedCase")
        }
        guard decoded.startRequests >= 0 else { throw BenchRestoreRefusal.outOfRange("startRequests") }
        guard decoded.stopRequests >= 0 else { throw BenchRestoreRefusal.outOfRange("stopRequests") }
        return BenchCore(selectedCase: decoded.selectedCase, startRequests: decoded.startRequests,
                         stopRequests: decoded.stopRequests)
    }
}
