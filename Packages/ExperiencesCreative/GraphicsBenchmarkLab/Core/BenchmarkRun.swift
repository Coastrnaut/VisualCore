// BenchmarkRun — feature 173 (A24-P01) T-A24-108 (FR-A24-105; clarification Q4; data-model.md "BenchmarkRun",
// "Run file"). A run record: the case it ran (id, version, fingerprint), its frame samples, the summary computed from
// them and how the run ended; and its file, a versioned JSON envelope `{"body", "kind", "version"}` of kind
// `a24.benchmark-run` (schema 1, at most 2,097,152 bytes) whose body is `{case, samples, summary, state}` with
// `case` = `{fingerprint, id, version}`. Sorted keys, so encode(decode(encode(r))) is byte-identical to encode(r).
// Choices recorded here: reading checks, in order, the size (`too-large`), the JSON object and its kind (`damaged`),
// the version (above the chain: `newer-version`; missing or below 1: `damaged`), the body through the
// `MigrationChain`, the decoding of the body (`damaged`), the case reference (an empty id or a fingerprint that is not
// a digest: `damaged`; a version below 1: `out-of-range` of `caseVersion`), the samples through
// ``SampleSet/validate(_:)`` (`too-many-samples`, `not-finite`, `out-of-range` with the field, `out-of-order`), then
// the stored summary against the one recomputed with ``Summary/make(_:)`` (a difference: `damaged`). JSON has no NaN
// or infinity token; a file that carries one as the string "NaN", "Infinity" or "-Infinity" where a number belongs is
// read as that value and refused as `not-finite`. Writing refuses the same runs with the same codes, then a result
// above the size cap. Pure Foundation; no UI, GPU or clock.
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

/// A run record: the case it ran, its samples, their summary and how it ended.
public struct BenchmarkRun: Codable, Equatable, Sendable {
    /// The id of the case run.
    public var caseID: String
    /// The version of the case run.
    public var caseVersion: Int
    /// The hex of the case's fingerprint (``BenchmarkCase/fingerprint()``).
    public var caseFingerprint: String
    /// The run's frame samples, at most ``SampleLimits/maxSamples``.
    public var samples: [FrameSample]
    /// The summary of ``samples`` (``Summary/make(_:)``).
    public var summary: Summary
    /// How the run ended.
    public var state: RunState

    /// A run with the given values (not checked; see ``RunDocument/encode(_:)``).
    public init(caseID: String, caseVersion: Int, caseFingerprint: String, samples: [FrameSample], summary: Summary,
                state: RunState) {
        self.caseID = caseID
        self.caseVersion = caseVersion
        self.caseFingerprint = caseFingerprint
        self.samples = samples
        self.summary = summary
        self.state = state
    }

    /// The body's keys: the case reference, the samples, the summary and the state.
    private enum CodingKeys: String, CodingKey {
        case caseReference = "case"
        case samples, summary, state
    }

    /// The keys of the case reference.
    private enum CaseKeys: String, CodingKey {
        case id, version, fingerprint
    }

    /// Decodes a run from the body `{case: {fingerprint, id, version}, samples, summary, state}`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reference = try container.nestedContainer(keyedBy: CaseKeys.self, forKey: .caseReference)
        caseID = try reference.decode(String.self, forKey: .id)
        caseVersion = try reference.decode(Int.self, forKey: .version)
        caseFingerprint = try reference.decode(String.self, forKey: .fingerprint)
        samples = try container.decode([FrameSample].self, forKey: .samples)
        summary = try container.decode(Summary.self, forKey: .summary)
        state = try container.decode(RunState.self, forKey: .state)
    }

    /// Encodes the run as the body `{case: {fingerprint, id, version}, samples, summary, state}`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var reference = container.nestedContainer(keyedBy: CaseKeys.self, forKey: .caseReference)
        try reference.encode(caseID, forKey: .id)
        try reference.encode(caseVersion, forKey: .version)
        try reference.encode(caseFingerprint, forKey: .fingerprint)
        try container.encode(samples, forKey: .samples)
        try container.encode(summary, forKey: .summary)
        try container.encode(state, forKey: .state)
    }
}

/// Why a run file was refused or a run could not be written.
public enum RunRefusal: Error, Equatable, Sendable {
    /// Not the envelope, the wrong kind, a missing or ill-typed field, a version below 1 or without a migration step,
    /// a malformed case reference, or a stored summary that differs from the one recomputed from the samples.
    case damaged
    /// The file was written by a newer version (above ``RunDocument/schemaVersion``).
    case newerVersion
    /// The file or the encoding is above ``RunDocument/maxBytes``.
    case tooLarge
    /// A sample duration is NaN or infinite.
    case notFinite
    /// The named field is outside its range (a sample duration, an absent interval after the first sample, or
    /// `caseVersion` below 1).
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

/// Reads and writes run files (kind `a24.benchmark-run`, schema 1).
public enum RunDocument {
    /// The envelope kind of a run file.
    public static let kind = "a24.benchmark-run"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest run file accepted or written, in bytes.
    public static let maxBytes = 2_097_152

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
                              migrations: MigrationChain = MigrationChain(currentVersion: 1))
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

    /// The refusal of a run the file may not hold, or nil: a malformed case reference, then the samples, then a
    /// stored summary that differs from the recomputed one.
    static func check(_ run: BenchmarkRun) -> RunRefusal? {
        guard run.caseID.isEmpty == false, StateDigest(hex: run.caseFingerprint) != nil else { return .damaged }
        guard run.caseVersion >= 1 else { return .outOfRange(field: "caseVersion") }
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
