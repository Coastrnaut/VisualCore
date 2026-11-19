// BenchmarkRun — feature 173 (A24-P01) T-A24-108 (FR-A24-105; clarification Q4; data-model.md "BenchmarkRun",
// "Run file"). A run record: the case it ran (id, version, fingerprint), its frame samples, the summary computed from
// them and how the run ended; and its file, a versioned JSON envelope `{"body", "kind", "version"}` of kind
// `a24.benchmark-run` (schema 1; 2 since A24-P03, below; at most 2,097,152 bytes) whose body is
// `{case, samples, summary, state}` with `case` = `{fingerprint, id, version}`. Sorted keys, so
// encode(decode(encode(r))) is byte-identical to encode(r).
// Choices recorded here: reading checks, in order, the size (`too-large`), the JSON object and its kind (`damaged`),
// the version (above the chain: `newer-version`; missing or below 1: `damaged`), the body through the
// `MigrationChain`, the decoding of the body (`damaged`), the case reference (an empty id or a fingerprint that is not
// a digest: `damaged`; a version below 1: `out-of-range` of `caseVersion`), the samples through
// ``SampleSet/validate(_:)`` (`too-many-samples`, `not-finite`, `out-of-range` with the field, `out-of-order`), then
// the stored summary against the one recomputed with ``Summary/make(_:)`` (a difference: `damaged`). JSON has no NaN
// or infinity token; a file that carries one as the string "NaN", "Infinity" or "-Infinity" where a number belongs is
// read as that value and refused as `not-finite`. Writing refuses the same runs with the same codes, then a result
// above the size cap. Pure Foundation; no UI, GPU or clock.
// Feature 175 (A24-P03) T-A24-307 (FR-A24-307; clarification Q5): schema 2 adds the body key `report` (a
// ``RunReport`` or JSON null), so the body is `{case, report, samples, state, summary}`; the chain's step 1 → 2 adds
// `report: null`, so a version 1 file opens with no report and a version 3 file is `newer-version`. A present report
// is checked after the case reference with ``RunReport/validate()``; an invalid field is `out-of-range` of
// `report.<field>`. The `report` key is required in a version 2 body (missing: `damaged`).
// Feature 176 (A24-P04) T-A24-402 (FR-A24-401; clarification Q1): schema 3 stores the whole case, so the body's
// `case` is `{config, fingerprint, id, plan, version, workload}` (only the workload's configuration fields present)
// and a saved run names exactly what was measured. Reading recomputes the fingerprint from the stored settings
// (``BenchmarkCase/fingerprint()``) and refuses a mismatch as `damaged`; an invalid stored case is `damaged` (id,
// workload fields), `out-of-range` of `caseVersion` or `case.<field>`, or `not-finite`. The chain's step 2 → 3 fills
// the settings from the built-in case with the same id and version whose fingerprint equals the stored one, and
// refuses any other version 2 file as `damaged`; a version 4 file is `newer-version`.
import Foundation
import VisualCoreExperience
import VisualCorePersistence

/// How a run ended.
public enum RunState: String, Codable, Sendable {
    /// The run went through warm-up, measurement and cool-down.
    case completed
    /// The person stopped the run before its plan ended.
    case stopped
    /// The system interrupted the run (the app left the foreground, a thermal or memory event).
    case interrupted
}

/// A run record: the case it ran (with every setting), its samples, their summary and how it ended.
public struct BenchmarkRun: Codable, Equatable, Sendable {
    /// The case run, with its id, version, workload, configuration and run plan.
    public var benchmarkCase: BenchmarkCase
    /// The hex of the case's fingerprint (``BenchmarkCase/fingerprint()``) as recorded with the run; a file whose
    /// stored fingerprint differs from the one recomputed from ``benchmarkCase`` is refused as damaged.
    public var caseFingerprint: String
    /// The run's frame samples, at most ``SampleLimits/maxSamples``.
    public var samples: [FrameSample]
    /// The summary of ``samples`` (``Summary/make(_:)``).
    public var summary: Summary
    /// How the run ended.
    public var state: RunState
    /// The conditions the run was measured under, or nil (a run written before schema 2, or recorded without one).
    public var report: RunReport?

    /// The id of the case run (``BenchmarkCase/id`` of ``benchmarkCase``).
    public var caseID: String { benchmarkCase.id }
    /// The version of the case run (``BenchmarkCase/version`` of ``benchmarkCase``).
    public var caseVersion: Int { benchmarkCase.version }

    /// A run of `benchmarkCase` with the given recorded fingerprint and values (not checked; see
    /// ``RunDocument/encode(_:)``).
    public init(benchmarkCase: BenchmarkCase, caseFingerprint: String, samples: [FrameSample], summary: Summary,
                state: RunState, report: RunReport? = nil) {
        self.benchmarkCase = benchmarkCase
        self.caseFingerprint = caseFingerprint
        self.samples = samples
        self.summary = summary
        self.state = state
        self.report = report
    }

    /// A run of `benchmarkCase` whose recorded fingerprint is computed from the case; throws what
    /// ``BenchmarkCase/fingerprint()`` throws for an invalid case.
    public init(benchmarkCase: BenchmarkCase, samples: [FrameSample], summary: Summary, state: RunState,
                report: RunReport? = nil) throws(CaseError) {
        let fingerprint = try benchmarkCase.fingerprint()
        self.init(benchmarkCase: benchmarkCase, caseFingerprint: fingerprint.hex, samples: samples, summary: summary,
                  state: state, report: report)
    }

    /// The body's keys: the case, the report, the samples, the summary and the state.
    private enum CodingKeys: String, CodingKey {
        case benchmarkCase = "case"
        case report, samples, summary, state
    }

    /// The keys of the body's `case` object: the case's own keys and its fingerprint.
    private enum CaseKeys: String, CodingKey {
        case id, version, workload, config, plan, fingerprint
    }

    /// Decodes a run from the version 3 body `{case: {config, fingerprint, id, plan, version, workload}, report,
    /// samples, summary, state}`; `report` must be present, as a report or null.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.nestedContainer(keyedBy: CaseKeys.self, forKey: .benchmarkCase)
        benchmarkCase = BenchmarkCase(
            id: try stored.decode(String.self, forKey: .id),
            version: try stored.decode(Int.self, forKey: .version),
            workload: try stored.decode(Workload.self, forKey: .workload),
            config: try stored.decode(WorkloadConfig.self, forKey: .config),
            plan: try stored.decode(RunPlan.self, forKey: .plan))
        caseFingerprint = try stored.decode(String.self, forKey: .fingerprint)
        samples = try container.decode([FrameSample].self, forKey: .samples)
        summary = try container.decode(Summary.self, forKey: .summary)
        state = try container.decode(RunState.self, forKey: .state)
        guard container.contains(.report) else {
            throw DecodingError.keyNotFound(CodingKeys.report, DecodingError.Context(
                codingPath: container.codingPath, debugDescription: "a version 3 body holds a report or null"))
        }
        report = try container.decodeNil(forKey: .report) ? nil : container.decode(RunReport.self, forKey: .report)
    }

    /// Encodes the run as the version 3 body `{case: {config, fingerprint, id, plan, version, workload}, report,
    /// samples, summary, state}`, with `report` null when absent and only the workload's configuration fields
    /// present.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var stored = container.nestedContainer(keyedBy: CaseKeys.self, forKey: .benchmarkCase)
        try stored.encode(benchmarkCase.id, forKey: .id)
        try stored.encode(benchmarkCase.version, forKey: .version)
        try stored.encode(benchmarkCase.workload, forKey: .workload)
        try stored.encode(benchmarkCase.config, forKey: .config)
        try stored.encode(benchmarkCase.plan, forKey: .plan)
        try stored.encode(caseFingerprint, forKey: .fingerprint)
        try container.encode(samples, forKey: .samples)
        try container.encode(summary, forKey: .summary)
        try container.encode(state, forKey: .state)
        if let report {
            try container.encode(report, forKey: .report)
        } else {
            try container.encodeNil(forKey: .report)
        }
    }
}

/// Why a run file was refused or a run could not be written.
public enum RunRefusal: Error, Equatable, Sendable {
    /// Not the envelope, the wrong kind, a missing or ill-typed field, a version below 1 or without a migration step,
    /// a malformed case, a stored case fingerprint that differs from the recomputed one, or a stored summary that
    /// differs from the one recomputed from the samples.
    case damaged
    /// The file was written by a newer version (above ``RunDocument/schemaVersion``).
    case newerVersion
    /// The file or the encoding is above ``RunDocument/maxBytes``.
    case tooLarge
    /// A sample duration or the case's resolution scale is NaN or infinite.
    case notFinite
    /// The named field is outside its range (a sample duration, an absent interval after the first sample,
    /// `caseVersion` below 1, or a case setting `case.<field>` outside its cap).
    case outOfRange(field: String)
    /// A frame index or a phase goes back.
    case outOfOrder
    /// The run holds more than ``SampleLimits/maxSamples`` samples.
    case tooManySamples

    /// The stable code: `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`, `out-of-order` or
    /// `too-many-samples`.
    public var code: String {
        switch self {
        case .damaged: "damaged"
        case .newerVersion: "newer-version"
        case .tooLarge: "too-large"
        case .notFinite: "not-finite"
        case .outOfRange: "out-of-range"
        case .outOfOrder: "out-of-order"
        case .tooManySamples: "too-many-samples"
        }
    }

    /// The refusal of a sample set error.
    init(_ error: SampleError) {
        switch error {
        case .notFinite: self = .notFinite
        case let .outOfRange(_, field): self = .outOfRange(field: field)
        case .outOfOrder: self = .outOfOrder
        case .tooManySamples: self = .tooManySamples
        }
    }
}

/// Reads and writes run files (kind `a24.benchmark-run`, schema 3).
public enum RunDocument {
    /// The envelope kind of a run file.
    public static let kind = "a24.benchmark-run"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 3
    /// The largest run file accepted or written, in bytes.
    public static let maxBytes = 2_097_152
    /// The migrations to ``schemaVersion``: step 1 → 2 adds `report: null` to the body; step 2 → 3 fills the case's
    /// settings from the built-in case of the same id and version whose fingerprint equals the stored one, and
    /// throws (read as ``RunRefusal/damaged``) for any other case.
    public static let migrations = MigrationChain(currentVersion: schemaVersion, steps: [
        1: { body in
            var migrated = body
            migrated["report"] = NSNull()
            return migrated
        },
        2: { body in
            var migrated = body
            migrated["case"] = try builtInCaseObject(for: body["case"])
            return migrated
        },
    ])

    /// A version 2 case reference that names no built-in case with the same id, version and fingerprint.
    struct UnknownCaseReference: Error {}

    /// The version 3 `case` object of the version 2 reference `reference` (`{fingerprint, id, version}`): the
    /// built-in case with the same id and version, encoded, plus the stored fingerprint. Throws
    /// ``UnknownCaseReference`` when the reference is malformed, names no built-in case, or its fingerprint differs.
    static func builtInCaseObject(for reference: Any?) throws -> [String: Any] {
        guard let reference = reference as? [String: Any], let id = reference["id"] as? String,
              let version = reference["version"] as? Int, let fingerprint = reference["fingerprint"] as? String
        else { throw UnknownCaseReference() }
        var match: BenchmarkCase?
        for candidate in BenchmarkCase.builtIn where candidate.id == id && candidate.version == version {
            match = candidate
        }
        guard let match, let digest = try? match.fingerprint(), digest.hex == fingerprint else {
            throw UnknownCaseReference()
        }
        let encoded = try JSONEncoder().encode(match)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw UnknownCaseReference()
        }
        object["fingerprint"] = fingerprint
        return object
    }

    /// The strings that stand for non-finite numbers in a file, so that they are refused as
    /// ``RunRefusal/notFinite`` rather than as damage.
    private static let positiveInfinityText = "Infinity"
    private static let negativeInfinityText = "-Infinity"
    private static let nanText = "NaN"

    /// The written envelope.
    private struct Envelope: Encodable {
        var body: BenchmarkRun
        var kind: String
        var version: Int
    }

    /// The stored file of `run`: the JSON envelope with sorted keys, the same bytes for the same run. Throws a
    /// ``RunRefusal`` exactly as ``decode(_:migrations:)`` would refuse the result (``RunRefusal/tooLarge`` for a
    /// result above ``maxBytes``).
    public static func encode(_ run: BenchmarkRun) throws -> Data {
        if let refusal = check(run) { throw refusal }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(Envelope(body: run, kind: kind, version: schemaVersion))
        } catch {
            // Every sample was checked finite above; a non-finite summary value is the only encoding failure left,
            // and such a summary differs from the recomputed one.
            throw RunRefusal.damaged
        }
        guard data.count <= maxBytes else { throw RunRefusal.tooLarge }
        return data
    }

    /// Reads a run file. Checks, in order: the size (``RunRefusal/tooLarge``), the JSON object and its kind
    /// (``RunRefusal/damaged``), the version (above `migrations.currentVersion`: ``RunRefusal/newerVersion``; missing
    /// or below 1: ``RunRefusal/damaged``), the body through `migrations`, the decoding of the body
    /// (``RunRefusal/damaged``), then the run as ``encode(_:)`` checks it.
    public static func decode(_ data: Data,
                              migrations: MigrationChain = RunDocument.migrations)
        -> Result<BenchmarkRun, RunRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fileKind = object["kind"] as? String, fileKind == kind,
              let version = object["version"] as? Int else { return .failure(.damaged) }
        guard version <= migrations.currentVersion else { return .failure(.newerVersion) }
        guard version >= 1, let body = object["body"] as? [String: Any] else { return .failure(.damaged) }
        let migrated: [String: Any]
        do {
            migrated = try migrations.migrate(body, from: version)
        } catch MigrationError.newerVersion(_) {
            return .failure(.newerVersion)
        } catch {
            return .failure(.damaged)
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        guard let bodyData = try? JSONSerialization.data(withJSONObject: migrated),
              let run = try? decoder.decode(BenchmarkRun.self, from: bodyData) else { return .failure(.damaged) }
        if let refusal = check(run) { return .failure(refusal) }
        return .success(run)
    }

    /// The refusal of a run the file may not hold, or nil: a malformed case (a fingerprint that is not a digest, an
    /// empty or malformed id, fields of another workload: `damaged`; a version below 1: `out-of-range` of
    /// `caseVersion`; another setting outside its cap: `out-of-range` of `case.<field>`; a non-finite resolution
    /// scale: `not-finite`), a stored fingerprint that differs from the recomputed one (`damaged`), then an invalid
    /// report (`out-of-range` of `report.<field>`), then the samples, then a stored summary that differs from the
    /// recomputed one.
    static func check(_ run: BenchmarkRun) -> RunRefusal? {
        guard StateDigest(hex: run.caseFingerprint) != nil else { return .damaged }
        let recomputedFingerprint: StateDigest
        do {
            recomputedFingerprint = try run.benchmarkCase.fingerprint()
        } catch {
            switch error {
            case .outOfRange(field: "id"): return .damaged
            case .outOfRange(field: "version"): return .outOfRange(field: "caseVersion")
            case let .outOfRange(field): return .outOfRange(field: "case.\(field)")
            case .notFinite: return .notFinite
            case .wrongWorkloadFields: return .damaged
            }
        }
        guard recomputedFingerprint.hex == run.caseFingerprint else { return .damaged }
        if let report = run.report {
            do {
                try report.validate()
            } catch {
                switch error {
                case let .invalid(field): return .outOfRange(field: "report.\(field)")
                }
            }
        }
        do {
            try SampleSet.validate(run.samples)
        } catch {
            return RunRefusal(error)
        }
        let recomputed: Summary
        do {
            recomputed = try Summary.make(run.samples)
        } catch {
            return RunRefusal(error)
        }
        guard recomputed == run.summary else { return .damaged }
        return nil
    }
}
