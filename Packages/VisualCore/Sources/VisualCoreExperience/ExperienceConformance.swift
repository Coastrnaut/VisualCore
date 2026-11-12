// ExperienceConformance — feature 188 T-U02-041 (FR-U02-070, FR-U02-071, FR-U02-073; data-model section 6; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md, section "Conformance"). The reusable proof that
// a core keeps the obligations of `ExperienceCore`: eight checks, run for every seed of a plan, reported as data.
// The helper imports no test framework, so a test target, a tool or the app's own diagnostics can call it.
import Foundation
import VisualCoreDiagnostics

/// The obligations of an `ExperienceCore` that `ExperienceConformance` checks.
public enum ConformanceCheck: String, Sendable, Codable, CaseIterable {
    /// Preparing the same seed twice gives the same digest, and the preparation does not fail.
    case seedDeterminism
    /// A snapshot that is encoded, decoded and restored gives the same digest, seed and step index.
    case snapshotRoundTrip
    /// A reset returns to the digest right after preparation, with step index 0.
    case resetEquivalence
    /// An action the core rejects leaves the digest as it was.
    case rejectionKeepsDigest
    /// Setting a quality tier leaves the digest as it was.
    case tierKeepsDigest
    /// Shedding caches leaves the digest as it was.
    case sheddingKeepsDigest
    /// Running the same script twice from the same state gives the same digest.
    case replayReproducesDigest
    /// The quality profile has as many levels as the core declares quality tiers (feature 192, UA-F06).
    case profileMatchesTiers
}

/// What a conformance run does: the seeds, the length of a segment and the actions.
///
/// A script is: for each action, run `stepsPerSegment` steps and handle the action; then run `stepsPerSegment`
/// steps once more. The stored values are kept as given; a run uses the `effective…` values.
public struct ConformancePlan: Sendable {
    /// The largest number of seeds a run uses.
    public static let maxSeeds = 64
    /// The largest number of steps per segment a run uses.
    public static let maxStepsPerSegment = 10_000
    /// The largest number of scripted actions a run uses.
    public static let maxActions = 1_000

    /// The seeds to prepare. The first 64 are used; an empty list means seed 0.
    public var seeds: [UInt64]
    /// The number of steps between two actions; used clamped to 0…10,000.
    public var stepsPerSegment: Int
    /// The actions of the script, each expected to be accepted. The first 1,000 are used.
    public var actions: [ScriptedAction]
    /// Actions that are expected to be rejected.
    public var rejected: [ScriptedAction]

    /// Creates a plan. Nothing is cut here; see `effectiveSeeds`, `effectiveStepsPerSegment` and `effectiveActions`.
    public init(seeds: [UInt64], stepsPerSegment: Int, actions: [ScriptedAction], rejected: [ScriptedAction]) {
        self.seeds = seeds
        self.stepsPerSegment = stepsPerSegment
        self.actions = actions
        self.rejected = rejected
    }

    /// The seeds a run uses: the first 64 of `seeds`, or seed 0 when the list is empty.
    public var effectiveSeeds: [UInt64] {
        seeds.isEmpty ? [0] : Array(seeds.prefix(Self.maxSeeds))
    }

    /// The steps per segment a run uses: `stepsPerSegment` brought into 0…10,000.
    public var effectiveStepsPerSegment: Int {
        min(max(stepsPerSegment, 0), Self.maxStepsPerSegment)
    }

    /// The scripted actions a run uses: the first 1,000 of `actions`.
    public var effectiveActions: [ScriptedAction] {
        Array(actions.prefix(Self.maxActions))
    }
}

/// The result of a conformance run: one entry per check.
public struct ConformanceReport: Sendable, Equatable, Codable {
    /// The result of one check over all seeds of the plan.
    public struct Entry: Sendable, Equatable, Codable {
        /// The check.
        public let check: ConformanceCheck
        /// Whether the check passed for every seed it ran for.
        public let passed: Bool
        /// For a failure: the first failing seed and what differed. For a pass: the number of seeds checked.
        public let detail: String
    }

    /// One entry per check, in the order of `ConformanceCheck.allCases`.
    public let entries: [Entry]

    /// Whether every check passed.
    public var passed: Bool { entries.allSatisfy(\.passed) }
    /// The checks that failed, in the order of `ConformanceCheck.allCases`.
    public var failed: [ConformanceCheck] { entries.filter { !$0.passed }.map(\.check) }
}

/// Runs the conformance checks of the experience contract against a core type.
public enum ExperienceConformance {
    /// Runs the eight checks for every seed of `plan` (after its limits) and reports one entry per check.
    ///
    /// The run never throws and never stops the process: a preparation that fails is reported by
    /// `seedDeterminism` with the error code, and the other checks are not run for that seed. An error inside a
    /// check fails that check with the error code in its detail.
    public static func run<Core: ExperienceCore>(_ core: Core.Type, id: ExperienceID,
                                                 plan: ConformancePlan) async -> ConformanceReport {
        let seeds = plan.effectiveSeeds
        let steps = plan.effectiveStepsPerSegment
        let actions = plan.effectiveActions
        var tallies: [ConformanceCheck: Tally] = [:]
        for seed in seeds {
            let outcomes = await check(Core.self, id: id, seed: seed, steps: steps, actions: actions,
                                       rejected: plan.rejected)
            for outcome in outcomes {
                tallies[outcome.check, default: Tally()].record(seed: seed, failure: outcome.failure)
            }
        }
        let entries = ConformanceCheck.allCases.map { check in
            let tally = tallies[check] ?? Tally()
            if let failure = tally.firstFailure {
                return ConformanceReport.Entry(check: check, passed: false, detail: failure)
            }
            return ConformanceReport.Entry(check: check, passed: true,
                                           detail: passDetail(checked: tally.checkedSeeds, of: seeds.count))
        }
        return ConformanceReport(entries: entries)
    }

    // MARK: - Bookkeeping

    /// The result of one check for one seed; `failure` is nil for a pass.
    private typealias Outcome = (check: ConformanceCheck, failure: String?)

    /// The results of one check over the seeds seen so far.
    private struct Tally {
        var checkedSeeds = 0
        var firstFailure: String?

        mutating func record(seed: UInt64, failure: String?) {
            checkedSeeds += 1
            if firstFailure == nil, let failure { firstFailure = "seed \(seed): \(failure)" }
        }
    }

    /// A difference found by a check, as text for the report.
    private struct Mismatch: Error {
        let detail: String
        init(_ detail: String) { self.detail = detail }
    }

    /// An engine that is prepared and active, or the reason why it is not.
    private enum Preparation<Core: ExperienceCore> {
        case ready(ExperienceEngine<Core>)
        case failed(String)
    }

    private static func passDetail(checked: Int, of total: Int) -> String {
        let all = total == 1 ? "1 seed" : "\(total) seeds"
        return checked == total ? all : "\(checked) of \(all); the others could not be prepared"
    }

    /// The text of an error: the stable code where the contract defines one.
    private static func describe(_ error: any Error) -> String {
        if let mismatch = error as? Mismatch { return mismatch.detail }
        if let known = error as? ExperienceError { return "error \(known.code)" }
        if let known = error as? SnapshotError { return "error \(known.code)" }
        if let known = error as? DigestError { return "error \(known.code)" }
        if let known = error as? ExperienceFailure { return "error \(known.code)" }
        return "error \(String(describing: error))"
    }

    // MARK: - One seed

    private static func prepared<Core: ExperienceCore>(_ core: Core.Type, id: ExperienceID,
                                                       seed: UInt64) async -> Preparation<Core> {
        var engine = ExperienceEngine<Core>(id: id)
        do {
            try await engine.prepare(seed: seed)
            try engine.activate()
        } catch {
            return .failed(describe(error))
        }
        return .ready(engine)
    }

    /// The digest of a core value, computed as the engine computes it.
    private static func digest<Core: ExperienceCore>(of core: Core, id: ExperienceID) throws(DigestError) -> StateDigest {
        var builder = DigestBuilder(domain: id.rawValue)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Runs the script: for each action a segment of steps and the action, then one more segment. `afterSegment`
    /// is called after each action and after the last segment.
    private static func script<Core: ExperienceCore>(
        on engine: inout ExperienceEngine<Core>, steps: Int, actions: [ScriptedAction],
        afterSegment: ((inout ExperienceEngine<Core>) throws -> Void)? = nil
    ) throws {
        for action in actions {
            try engine.run(steps: steps)
            engine.handle(control: action.control, values: action.values)
            try afterSegment?(&engine)
        }
        try engine.run(steps: steps)
        try afterSegment?(&engine)
    }

    /// Turns a throwing check into a failure text; nil when the check passed.
    private static func failure(of body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        } catch {
            return describe(error)
        }
    }

    private static func check<Core: ExperienceCore>(
        _ core: Core.Type, id: ExperienceID, seed: UInt64, steps: Int, actions: [ScriptedAction],
        rejected: [ScriptedAction]
    ) async -> [Outcome] {
        // E0: the one preparation every check of this seed starts from.
        let start: ExperienceEngine<Core>
        switch await prepared(Core.self, id: id, seed: seed) {
        case .failed(let reason):
            return [(.seedDeterminism, "the preparation failed: \(reason)")]
        case .ready(let engine):
            start = engine
        }
        let firstDigest: StateDigest
        let original: Core
        do {
            firstDigest = try start.digest()
            guard let value = start.core else { throw Mismatch("the prepared engine has no core") }
            original = value
        } catch {
            return [(.seedDeterminism, "the prepared state has no digest: \(describe(error))")]
        }

        var outcomes: [Outcome] = []

        // seedDeterminism
        switch await prepared(Core.self, id: id, seed: seed) {
        case .failed(let reason):
            outcomes.append((.seedDeterminism, "the second preparation failed: \(reason)"))
        case .ready(let second):
            outcomes.append((.seedDeterminism, failure {
                let found = try second.digest()
                guard found == firstDigest else {
                    throw Mismatch("two preparations gave the digests \(firstDigest.hex) and \(found.hex)")
                }
            }))
        }

        // snapshotRoundTrip: the restore goes into an engine that was prepared with another seed.
        switch await prepared(Core.self, id: id, seed: seed &+ 1) {
        case .failed(let reason):
            outcomes.append((.snapshotRoundTrip,
                             "the engine to restore into (seed \(seed &+ 1)) could not be prepared: \(reason)"))
        case .ready(let other):
            outcomes.append((.snapshotRoundTrip, failure {
                var engine = start
                try script(on: &engine, steps: steps, actions: actions) { engine in
                    try roundTrip(&engine, into: other)
                }
            }))
        }

        // resetEquivalence
        outcomes.append((.resetEquivalence, failure {
            var engine = start
            try script(on: &engine, steps: steps, actions: actions)
            try engine.reset()
            let found = try engine.digest()
            guard found == firstDigest else {
                throw Mismatch("the digest after reset is \(found.hex), after preparation it was \(firstDigest.hex)")
            }
            guard engine.stepIndex == 0 else {
                throw Mismatch("the step index after reset is \(engine.stepIndex), not 0")
            }
        }))

        // rejectionKeepsDigest: only actions the contract lets through reach a core.
        outcomes.append((.rejectionKeepsDigest, failure {
            for action in rejected {
                let refused = ExperienceInput.validate(control: action.control, values: action.values,
                                                       controls: Core.controls)
                if refused != nil { continue }
                var copy = original
                let result = copy.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
                guard !result.isAccepted else {
                    throw Mismatch("the core accepted the action \(action.control) \(action.values)")
                }
                let found = try digest(of: copy, id: id)
                guard found == firstDigest else {
                    throw Mismatch("the rejected action \(action.control) \(action.values) (\(result.code)) "
                                   + "changed the digest from \(firstDigest.hex) to \(found.hex)")
                }
            }
        }))

        // tierKeepsDigest
        outcomes.append((.tierKeepsDigest, failure {
            for tier in 0..<max(Core.qualityTiers, 1) {
                var copy = original
                copy.setQualityTier(tier)
                let found = try digest(of: copy, id: id)
                guard found == firstDigest else {
                    throw Mismatch("quality tier \(tier) changed the digest from \(firstDigest.hex) to \(found.hex)")
                }
            }
        }))

        // profileMatchesTiers
        outcomes.append((.profileMatchesTiers, failure {
            let problems = QualityDeclaration.problems(profile: Core.qualityProfile, tierCount: Core.qualityTiers,
                                                       catalogNames: nil)
            guard problems.isEmpty else { throw Mismatch(problems.joined(separator: "; ")) }
        }))

        // sheddingKeepsDigest
        outcomes.append((.sheddingKeepsDigest, failure {
            var copy = original
            copy.shedCaches()
            let found = try digest(of: copy, id: id)
            guard found == firstDigest else {
                throw Mismatch("shedding caches changed the digest from \(firstDigest.hex) to \(found.hex)")
            }
        }))

        // replayReproducesDigest
        outcomes.append((.replayReproducesDigest, failure {
            var first = start
            var second = start
            try script(on: &first, steps: steps, actions: actions)
            try script(on: &second, steps: steps, actions: actions)
            let one = try first.digest()
            let two = try second.digest()
            guard one == two else {
                throw Mismatch("two runs of the script gave the digests \(one.hex) and \(two.hex)")
            }
        }))

        return outcomes
    }

    /// Captures `engine` twice, encodes, decodes and restores into a copy of `other`, and compares.
    private static func roundTrip<Core: ExperienceCore>(_ engine: inout ExperienceEngine<Core>,
                                                        into other: ExperienceEngine<Core>) throws {
        let step = engine.stepIndex
        let first = try engine.snapshot()
        let second = try engine.snapshot()
        guard first == second else { throw Mismatch("two snapshots of the state at step \(step) differ") }
        let decoded = try ExperienceSnapshot(data: try first.encoded())
        var target = other
        do {
            try target.restore(decoded)
        } catch {
            throw Mismatch("the restore of the snapshot taken at step \(step) was refused: \(describe(error))")
        }
        let expected = try engine.digest()
        let found = try target.digest()
        guard found == expected else {
            throw Mismatch("the state restored at step \(step) has the digest \(found.hex), not \(expected.hex)")
        }
        guard target.seed == engine.seed else {
            throw Mismatch("the state restored at step \(step) has another seed")
        }
        guard target.stepIndex == step else {
            throw Mismatch("the state restored at step \(step) has the step index \(target.stepIndex)")
        }
    }
}
