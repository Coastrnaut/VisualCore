// StoredFileSampleTests — feature 122 (A16-P06) T-A16-605 (FR-A16-611; SC-A16-602; clarification Q5). The committed
// sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in the app:
//   - `preset-*.json` installed in a temporary experience storage under `SimulationPresetStore.fileName(for:)` with
//     the synthetic ids …0a1 (valid), …0a2 (newer), …0a3 (damaged) and …0a4 (invalid) and read by
//     `SimulationPresetStore`: exactly the valid sample (the bundled Spots preset) is listed; the others are reported
//     as `newer-version`, `damaged` and `invalid`; after a reload every stored file is byte for byte the sample;
//   - `state-*.json` given to `SimulationCore.restore(payload:seed:)`: the valid sample (a paused cellular automaton
//     at step 3) restores; the newer and damaged samples are refused with `newer-version` and `damaged`; the sample
//     bytes are unchanged.
// `UPDATE_FIXTURES=1` (on the simulator `TEST_RUNNER_UPDATE_FIXTURES=1`) rewrites the valid, newer and invalid samples
// in the source folder from code (`ExperimentPreset.encoded()`, `SimulationState.encoded()`); commit the result.
// Short, no GPU, no prompt, no network.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience

@MainActor
final class StoredFileSampleTests: XCTestCase {
    /// The experience's temporary storage.
    private var temporary: TemporarySimulationStorage!

    /// The preset samples with their synthetic file ids and the reason each refused one is reported with.
    private static let presetSamples: [(name: String, id: String, problem: String?)] = [
        ("preset-valid.json", "00000000-0000-4000-8000-0000000000a1", nil),
        ("preset-newer.json", "00000000-0000-4000-8000-0000000000a2", "newer-version"),
        ("preset-damaged.json", "00000000-0000-4000-8000-0000000000a3", "damaged"),
        ("preset-invalid.json", "00000000-0000-4000-8000-0000000000a4", "invalid"),
    ]

    /// The step count of the valid state sample.
    private static let validStateSteps = 3

    override func setUp() async throws {
        temporary = TemporarySimulationStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
        temporary = nil
    }

    // MARK: Helpers

    /// The bundled `Fixtures` folder.
    private func fixtures() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil), "missing Fixtures folder")
    }

    /// The bytes of the bundled sample `name`.
    private func sample(_ name: String) throws -> Data {
        try Data(contentsOf: try fixtures().appendingPathComponent(name))
    }

    /// The storage file name of the preset sample with id `id`.
    private func fileName(_ id: String) throws -> String {
        SimulationPresetStore.fileName(for: try XCTUnwrap(UUID(uuidString: id)))
    }

    // MARK: Bundle and regeneration

    func testExactlyTheSevenSamplesAreBundled() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: try fixtures().path)
            .filter { !$0.hasPrefix(".") }
        var expected: Set<String> = []
        for kind in ["valid", "newer", "damaged", "invalid"] { expected.insert("preset-\(kind).json") }
        for kind in ["valid", "newer", "damaged"] { expected.insert("state-\(kind).json") }
        XCTAssertEqual(Set(names), expected)
    }

    /// With `UPDATE_FIXTURES=1` the valid, newer and invalid samples are written into the source folder from code.
    func testUpdateFixturesRewritesTheSamplesFromCode() throws {
        guard ProcessInfo.processInfo.environment["UPDATE_FIXTURES"] == "1" else { return }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
        let valid = ExperimentPreset.bundled[3]
        var newer = valid
        newer.schema = 2
        var invalid = valid
        invalid.spec.timeStep = 2.0
        try valid.encoded().write(to: folder.appendingPathComponent("preset-valid.json"))
        try newer.encoded().write(to: folder.appendingPathComponent("preset-newer.json"))
        try invalid.encoded().write(to: folder.appendingPathComponent("preset-invalid.json"))

        var model = try SimulationModel(spec: .standard(.automaton, preset: 0, seed: 1), running: false)
        for _ in 0..<Self.validStateSteps { XCTAssertTrue(model.singleStep()) }
        let state = model.state.encoded()
        try state.write(to: folder.appendingPathComponent("state-valid.json"))
        let text = try XCTUnwrap(String(data: state, encoding: .utf8))
        XCTAssertTrue(text.contains(#""schema":1,"spec""#))
        let newerState = text.replacingOccurrences(of: #""schema":1,"spec""#, with: #""schema":2,"spec""#)
        try Data(newerState.utf8).write(to: folder.appendingPathComponent("state-newer.json"))
    }

    // MARK: preset-*.json

    func testThePresetSamplesAreListedOrReportedAndUntouched() throws {
        var bytes: [String: Data] = [:]
        for entry in Self.presetSamples {
            let data = try sample(entry.name)
            bytes[entry.name] = data
            try temporary.storage.write(data, to: try fileName(entry.id))
        }
        guard case .success(let decoded) = ExperimentPreset.decode(try sample("preset-valid.json")) else {
            return XCTFail("the valid preset sample decodes")
        }
        XCTAssertEqual(decoded, ExperimentPreset.bundled[3], "the valid sample is the bundled Spots preset")

        let store = SimulationPresetStore(storage: temporary.storage)
        let validID = try XCTUnwrap(UUID(uuidString: Self.presetSamples[0].id))
        XCTAssertEqual(store.entries, [SimulationPresetEntry(id: validID, preset: ExperimentPreset.bundled[3])],
                       "exactly the valid sample is listed")
        var problems: [String] = []
        for entry in Self.presetSamples {
            guard let problem = entry.problem else { continue }
            problems.append("\(try fileName(entry.id)): \(problem)")
        }
        XCTAssertEqual(store.problems, problems, "newer-version, damaged and invalid, by file name")

        store.reload()
        XCTAssertEqual(store.entries.map(\.id), [validID])
        XCTAssertEqual(store.problems, problems)
        for entry in Self.presetSamples {
            XCTAssertEqual(try temporary.storage.read(try fileName(entry.id)), bytes[entry.name],
                           "\(entry.name) stays byte-identical")
        }
        XCTAssertEqual(temporary.storage.list().count, Self.presetSamples.count, "no file is added or removed")
    }

    // MARK: state-*.json

    func testTheValidStateSampleRestores() throws {
        let bytes = try sample("state-valid.json")
        let core = try SimulationCore.restore(payload: bytes, seed: 1)
        XCTAssertEqual(core.kind, .automaton)
        XCTAssertEqual(core.stepCount, Self.validStateSteps)
        XCTAssertFalse(core.isRunning, "the sample is paused")
        XCTAssertEqual(core.model.spec, .standard(.automaton, preset: 0, seed: 1))
        XCTAssertEqual(try sample("state-valid.json"), bytes, "the sample is unchanged")
    }

    func testTheRefusedStateSamplesAreRefusedWithTheirReasons() throws {
        let cases: [(String, SimulationStateRefusal)] = [
            ("state-newer.json", .newerVersion), ("state-damaged.json", .damaged),
        ]
        for (name, refusal) in cases {
            let bytes = try sample(name)
            XCTAssertThrowsError(try SimulationCore.restore(payload: bytes, seed: 1), name) { error in
                XCTAssertEqual(error as? SimulationRestoreError, .refused(refusal), name)
            }
            XCTAssertEqual(try sample(name), bytes, "\(name) is unchanged")
        }
    }
}
