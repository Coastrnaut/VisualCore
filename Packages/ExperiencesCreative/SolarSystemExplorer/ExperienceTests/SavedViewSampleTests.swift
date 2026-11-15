// SavedViewSampleTests — feature 108 (A14-P06) T-A14-605 (FR-A14-610; SC-A14-602; clarification Q5). The four committed
// sample saved views under `ExperienceTests/Fixtures` are installed as `view.json` in a temporary storage and read
// through `ViewStore`: the valid sample (exactly the bytes `SavedView.encoded()` writes) loads; the newer, damaged and
// oversized samples are refused with their reasons; every file is byte for byte the same afterwards. Short, no GPU.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience

final class SavedViewSampleTests: XCTestCase {
    private var temporary: TemporarySolarStorage!

    override func setUp() {
        temporary = TemporarySolarStorage()
    }

    override func tearDown() {
        temporary.remove()
    }

    private func sample(_ name: String) throws -> Data {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil),
                                   "missing Fixtures folder")
        return try Data(contentsOf: folder.appendingPathComponent(name))
    }

    func testExactlyTheFourSamplesAreBundled() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), ["view-valid.json", "view-newer.json", "view-damaged.json", "view-oversized.json"])
    }

    func testTheValidSampleLoads() throws {
        let bytes = try sample("view-valid.json")
        let expected = try XCTUnwrap(SavedView(selection: 3, dayOffset: 365, rateIndex: 1, yawSteps: 2,
                                               pitchDegrees: 45, zoomSteps: 3, scaleMode: 1))
        XCTAssertEqual(bytes, expected.encoded(), "exactly the bytes SavedView.encoded() writes")
        try temporary.storage.write(bytes, to: SavedView.fileName)
        let store = ViewStore(storage: temporary.storage)
        guard case .success(let view) = store.load() else { return XCTFail("the valid sample is refused") }
        XCTAssertEqual(view, expected)
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), bytes, "loading never rewrites view.json")
    }

    func testTheRefusedSamplesAreRefusedAndUntouched() throws {
        let cases: [(String, SavedViewRefusal)] = [
            ("view-newer.json", .newerVersion), ("view-damaged.json", .damaged), ("view-oversized.json", .oversized),
        ]
        for (name, refusal) in cases {
            let bytes = try sample(name)
            try temporary.storage.write(bytes, to: SavedView.fileName)
            let store = ViewStore(storage: temporary.storage)
            guard case .failure(.refused(let reason)) = store.load() else {
                XCTFail("\(name) is not refused")
                continue
            }
            XCTAssertEqual(reason, refusal, name)
            XCTAssertEqual(try temporary.storage.read(SavedView.fileName), bytes, "\(name) stays byte-identical")
        }
        XCTAssertGreaterThan(try sample("view-oversized.json").count, SavedView.maxBytes)
    }

    func testNoSavedViewIsMissing() {
        let store = ViewStore(storage: temporary.storage)
        guard case .failure(.missing) = store.load() else { return XCTFail("an empty storage is not missing") }
    }
}
