// ExperimentSampleFileTests — feature 085 (A11-P04) T-A11-403 (FR-A11-403; SC-A11-402; clarification 3; research D3).
// The four committed experiment samples (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`), each copied as
// `experiment-0.json` into a temporary experience storage and read by an `ExperimentStore`: the valid sample (the exact
// bytes `ExperimentDocument.encoded()` writes for the pendulum preset saved to slot 0 as "Pendulum test") opens, also
// through the presenter, where it becomes the world and the starting world; the newer (file schema 2), damaged (not
// JSON) and truncated (the valid file cut in half) samples are refused with their reasons, the presenter's state is
// unchanged, and each file stays byte for byte as committed. Files and one short session only, well under 10 s.
//
// Feature 086 (A11-P05) T-A11-504 (FR-A11-502): the committed samples stay as A11-P04 wrote them (the world at world
// schema 3, bodies without `asleep` and `restTicks`); the valid sample is exactly today's encoding with the world
// written at world schema 3, and it still opens, its world migrated to world schema 4 with every body awake.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation

@MainActor
final class ExperimentSampleFileTests: XCTestCase {
    private var temporary: TemporaryPlaygroundStorage!

    override func setUp() async throws {
        temporary = TemporaryPlaygroundStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// The committed bytes of the bundled sample `name` (`Fixtures/<name>`).
    private func sample(_ name: String) throws -> Data {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil),
                                   "missing Fixtures folder")
        return try Data(contentsOf: folder.appendingPathComponent(name))
    }

    /// Writes `bytes` as the experience's `experiment-0.json`.
    private func install(_ bytes: Data) throws {
        try storage.write(bytes, to: ExperimentStore.fileName(slot: 0))
    }

    /// The pendulum preset as the valid sample saved it.
    private func pendulumDocument() -> ExperimentDocument {
        var random = SeededRandom(seed: 7)
        let world = Presets.make(.pendulum, random: &random, catalog: PlaygroundCore.catalog)
        return ExperimentDocument(name: "Pendulum test", origin: .preset(PresetID.pendulum.rawValue), world: world,
                                  slot: 0)
    }

    func testExactlyTheFourSamplesAreBundled() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), ["experiment-valid.json", "experiment-newer.json", "experiment-damaged.json",
                                    "experiment-truncated.json"])
    }

    func testTheValidSampleOpens() async throws {
        let bytes = try sample("experiment-valid.json")
        let expected = pendulumDocument()
        // The sample is today's encoding (sorted keys) with the world written at world schema 3 (A11-P04).
        var today = try XCTUnwrap(try JSONSerialization.jsonObject(with: expected.encoded()) as? [String: Any])
        var world = try XCTUnwrap(today["world"] as? [String: Any])
        world["schema"] = 3
        world["bodies"] = try XCTUnwrap(world["bodies"] as? [[String: Any]]).map { body in
            var body = body
            body["asleep"] = nil
            body["restTicks"] = nil
            return body
        }
        today["world"] = world
        let stored = try XCTUnwrap(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(stored as NSDictionary, today as NSDictionary, "the A11-P04 shape of the same document")
        XCTAssertEqual(expected.world.schema, PhysicsWorld.schemaVersion)
        try install(bytes)
        let store = ExperimentStore(storage: storage)
        XCTAssertEqual(try store.read(slot: 0).get(), expected)
        XCTAssertEqual(store.summaries(), ["Pendulum test", "", "", ""])

        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, store: store)
        XCTAssertEqual(shell.presenter.mirror.slotStatus[0], "Holds “Pendulum test”.")
        XCTAssertEqual(shell.presenter.openExperiment(slot: 0), "Opened “Pendulum test”.")
        let core = try PlaygroundTest.core(shell)
        XCTAssertEqual(core.world, expected.world)
        XCTAssertEqual(core.startingWorld, expected.world)
        XCTAssertEqual(core.origin, .slot(0))
        XCTAssertEqual(try storage.read(ExperimentStore.fileName(slot: 0)), bytes, "opening never rewrites the file")
        session.close()
    }

    func testTheRefusedSamplesAreRefusedAndLeftByteIdentical() async throws {
        let cases: [(name: String, refusal: DocumentRefusal, status: String)] = [
            ("experiment-newer.json", .newerVersion,
             "Not opened: The saved file comes from a newer version and was left as it is."),
            ("experiment-damaged.json", .damaged, "Not opened: The saved file is damaged and was left as it is."),
            ("experiment-truncated.json", .damaged, "Not opened: The saved file is damaged and was left as it is."),
        ]
        let valid = try sample("experiment-valid.json")
        let truncated = try sample("experiment-truncated.json")
        XCTAssertEqual(truncated, valid.prefix(valid.count / 2), "the valid file cut in half")
        for item in cases {
            let bytes = try sample(item.name)
            try install(bytes)
            let store = ExperimentStore(storage: storage)
            XCTAssertEqual(store.read(slot: 0).failure, .document(item.refusal), item.name)
            XCTAssertEqual(store.summaries(), ["", "", "", ""], item.name)
            let session = ExperienceSession()
            let shell = try await PlaygroundTest.open(session, store: store)
            let before = try PlaygroundTest.core(shell)
            XCTAssertEqual(shell.presenter.openExperiment(slot: 0), item.status, item.name)
            XCTAssertEqual(try PlaygroundTest.core(shell), before, "\(item.name): nothing changes")
            session.close()
            XCTAssertEqual(try storage.read(ExperimentStore.fileName(slot: 0)), bytes, "\(item.name): byte-identical")
            // A new store reads it again the same way.
            XCTAssertEqual(ExperimentStore(storage: storage).read(slot: 0).failure, .document(item.refusal))
            XCTAssertEqual(try storage.read(ExperimentStore.fileName(slot: 0)), bytes)
        }
    }
}
