// SnapshotMigrationCheckTests — feature 191 T-U05-006 (UA-F05, US5; FR-U05-050, FR-U05-051; SC-U05-007): the
// migration check accepts the stored version-1 example of the sample core (schema 2) and names a missing example,
// a wrong digest, a text that is no snapshot, a snapshot of another experience, an example of the current version
// and a doubled example; a core with schema 1 needs no example.
import Foundation
import Testing
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreTestSupport

/// A core with schema 1: there is no earlier version.
private struct SchemaOneCore: ExperienceCore, Codable, Equatable {
    var value = 0
    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [] }
    static func prepare(seed: UInt64) async throws -> SchemaOneCore { SchemaOneCore(value: Int(seed % 7)) }
    mutating func update(step: Int) { value = (value + 1) % 1_000 }
    mutating func apply(_ action: ExperienceAction) -> ActionResult { .rejected(.unknownControl(action.control)) }
    mutating func reset() { value = 0 }
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) { builder.add(value) }
}

@Suite struct SnapshotMigrationCheckTests {
    private typealias Sample = SampleExperienceCore<NoFault>

    /// The stored example of version 1 with its recorded digest.
    private static var good: MigrationExample {
        MigrationExample(version: 1, snapshot: SampleExperience.snapshotV1(seed: 42),
                         expectedDigest: SampleExperience.snapshotV1Digest)
    }

    private static let wrongDigest = String(repeating: "0", count: 64)

    private func problems(_ examples: [MigrationExample], id: ExperienceID = SampleExperience.id) async -> [String] {
        await SnapshotMigrationCheck.problems(for: Sample.self, id: id, examples: examples)
    }

    @Test func theSampleHasSchemaTwo() {
        #expect(Sample.migrations.currentVersion == 2)
    }

    @Test func theStoredExampleOfVersionOneGivesNoProblem() async {
        let found = await problems([Self.good])
        #expect(found == [])
    }

    @Test func noExampleNamesTheMissingVersion() async {
        let found = await problems([])
        #expect(found == ["version 1: no stored example"])
    }

    @Test func aWrongExpectedDigestIsOneProblem() async {
        let example = MigrationExample(version: 1, snapshot: SampleExperience.snapshotV1(seed: 42),
                                       expectedDigest: Self.wrongDigest)
        let found = await problems([example])
        #expect(found.count == 1)
        #expect(found.first == "version 1: digest \(SampleExperience.snapshotV1Digest) differs from the expected "
                + Self.wrongDigest)
        #expect(found.first?.hasPrefix("version 1: digest ") == true)
    }

    @Test func aTextThatIsNoSnapshotIsOneProblem() async {
        let example = MigrationExample(version: 1, snapshot: Data("no".utf8),
                                       expectedDigest: SampleExperience.snapshotV1Digest)
        let found = await problems([example])
        #expect(found.count == 1)
        #expect(found.first?.hasPrefix("version 1: not a snapshot (") == true, "found: \(found)")
        #expect(found.first?.hasSuffix(")") == true)
    }

    @Test func aSnapshotOfAnotherExperienceIsOneProblem() async throws {
        let other = try ExperienceID("a98.another-sample")
        let found = await problems([Self.good], id: other)
        #expect(found == ["version 1: a snapshot of \(SampleExperience.id.rawValue)"])
    }

    @Test func anExampleThatClaimsTheCurrentVersionIsNotAnEarlierVersion() async {
        let example = MigrationExample(version: 2, snapshot: SampleExperience.snapshotV1(seed: 42),
                                       expectedDigest: SampleExperience.snapshotV1Digest)
        let found = await problems([example])
        #expect(found == ["version 1: no stored example", "version 2: not an earlier version (current is 2)"])
    }

    @Test func aVersionBelowOneIsNotAnEarlierVersion() async {
        let example = MigrationExample(version: 0, snapshot: SampleExperience.snapshotV1(seed: 42),
                                       expectedDigest: SampleExperience.snapshotV1Digest)
        let found = await problems([Self.good, example])
        #expect(found == ["version 0: not an earlier version (current is 2)"])
    }

    @Test func twoExamplesOfOneVersionAreReportedOnce() async {
        let two = await problems([Self.good, Self.good])
        #expect(two == ["version 1: more than one example"])
        let three = await problems([Self.good, Self.good, Self.good])
        #expect(three == ["version 1: more than one example"])
    }

    @Test func aCoreWithSchemaOneNeedsNoExample() async throws {
        let id = try ExperienceID("a97.schema-one")
        let none = await SnapshotMigrationCheck.problems(for: SchemaOneCore.self, id: id, examples: [])
        #expect(none == [])
        let one = await SnapshotMigrationCheck.problems(for: SchemaOneCore.self, id: id, examples: [Self.good])
        #expect(one == ["version 1: not an earlier version (current is 1)"])
    }

    @Test func examplesCompareByValue() {
        #expect(Self.good == Self.good)
        let other = MigrationExample(version: 1, snapshot: SampleExperience.snapshotV1(seed: 42),
                                     expectedDigest: Self.wrongDigest)
        #expect(Self.good != other)
        #expect(other.version == 1)
        #expect(other.expectedDigest == Self.wrongDigest)
        #expect(other.snapshot == SampleExperience.snapshotV1(seed: 42))
    }
}
