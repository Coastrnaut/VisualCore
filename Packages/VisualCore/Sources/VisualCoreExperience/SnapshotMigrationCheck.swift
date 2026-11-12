// SnapshotMigrationCheck — feature 191 T-U05-007 (UA-F05; FR-U05-050, FR-U05-051; research R6). The reusable proof
// that an experience still opens the saved states of every earlier schema version: one stored example per earlier
// version, restored through the engine and compared with the digest that was recorded for it. The check imports no
// test framework, so a test target, a tool or the app's own diagnostics can call it.
import Foundation

/// A stored saved state of an earlier schema version, with the digest its restore must give.
public struct MigrationExample: Sendable, Equatable {
    /// The schema version the example was written with: 1 or more, below the current schema of the experience.
    public let version: Int
    /// The stored text: an encoded `ExperienceSnapshot`.
    public let snapshot: Data
    /// The digest of the state after the restore, as 64 lower-case hexadecimal digits.
    public let expectedDigest: String

    /// Creates an example. Nothing is checked here; `SnapshotMigrationCheck.problems(for:id:examples:)` checks it.
    public init(version: Int, snapshot: Data, expectedDigest: String) {
        self.version = version
        self.snapshot = snapshot
        self.expectedDigest = expectedDigest
    }
}

/// Checks that a core restores a stored example of every earlier schema version to the expected state.
public enum SnapshotMigrationCheck {
    /// The problems of `examples` for the core `core` registered as `id`; empty when everything holds.
    ///
    /// With `current` the core's `migrations.currentVersion`, the texts come in this order:
    ///
    /// 1. For every version from 1 below `current`, rising, that no example names: `version N: no stored example`.
    /// 2. For every example, in the order given, the first rule it breaks ends that example, except rule (e):
    ///    (a) its version is below 1 or not below `current`: `version N: not an earlier version (current is C)`;
    ///    (b) its text is not a snapshot: `version N: not a snapshot (code)`;
    ///    (c) the snapshot belongs to another experience: `version N: a snapshot of other.id`;
    ///    (d) the snapshot's schema is not the example's version: `version N: the snapshot has schema S`;
    ///    (e) another example before it has the same version: `version N: more than one example`, once per
    ///        version, and the example is still restored;
    ///    (f) the preparation of an engine with the snapshot's seed fails: `version N: preparation failed (code)`;
    ///    (g) the restore is refused: `version N: restore refused (code)`;
    ///    (h) the digest after the restore differs: `version N: digest FOUND differs from the expected EXPECTED`.
    ///
    /// The engine is prepared as `ExperienceConformance` prepares one: created for `id`, prepared with the seed
    /// and activated. The check never throws and never stops the process.
    public static func problems<Core: ExperienceCore>(for core: Core.Type, id: ExperienceID,
                                                      examples: [MigrationExample]) async -> [String] {
        let current = Core.migrations.currentVersion
        var problems: [String] = []

        let named = Set(examples.map(\.version))
        if current > 1 {
            for version in 1..<current where !named.contains(version) {
                problems.append("version \(version): no stored example")
            }
        }

        var seen: Set<Int> = []
        var reportedDuplicates: Set<Int> = []
        for example in examples {
            let version = example.version
            guard version >= 1, version < current else {
                problems.append("version \(version): not an earlier version (current is \(current))")
                continue
            }
            let snapshot: ExperienceSnapshot
            do {
                snapshot = try ExperienceSnapshot(data: example.snapshot)
            } catch {
                problems.append("version \(version): not a snapshot (\(code(of: error)))")
                continue
            }
            guard snapshot.experience == id else {
                problems.append("version \(version): a snapshot of \(snapshot.experience.rawValue)")
                continue
            }
            guard snapshot.schemaVersion == version else {
                problems.append("version \(version): the snapshot has schema \(snapshot.schemaVersion)")
                continue
            }
            if !seen.insert(version).inserted, reportedDuplicates.insert(version).inserted {
                problems.append("version \(version): more than one example")
            }
            if let problem = await restoreProblem(Core.self, id: id, snapshot: snapshot,
                                                  expectedDigest: example.expectedDigest) {
                problems.append("version \(version): \(problem)")
            }
        }
        return problems
    }

    /// Prepares an engine with the snapshot's seed, restores the snapshot and compares the digest. Returns the
    /// problem without its version prefix, or nil when the restore gives the expected digest.
    private static func restoreProblem<Core: ExperienceCore>(_ core: Core.Type, id: ExperienceID,
                                                             snapshot: ExperienceSnapshot,
                                                             expectedDigest: String) async -> String? {
        var engine = ExperienceEngine<Core>(id: id)
        do {
            try await engine.prepare(seed: snapshot.seed)
            try engine.activate()
        } catch {
            return "preparation failed (\(code(of: error)))"
        }
        let found: String
        do {
            try engine.restore(snapshot)
            found = try engine.digest().hex
        } catch {
            return "restore refused (\(code(of: error)))"
        }
        guard found == expectedDigest else {
            return "digest \(found) differs from the expected \(expectedDigest)"
        }
        return nil
    }

    /// The stable code of an error where the contract defines one, else its description.
    private static func code(of error: any Error) -> String {
        if let known = error as? ExperienceError { return known.code }
        if let known = error as? SnapshotError { return known.code }
        if let known = error as? DigestError { return known.code }
        if let known = error as? ExperienceFailure { return known.code }
        return String(describing: error)
    }
}
