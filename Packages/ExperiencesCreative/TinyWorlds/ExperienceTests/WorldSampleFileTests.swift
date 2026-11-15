// WorldSampleFileTests — feature 094 (A12-P06) T-A12-605/606 (FR-A12-610–612; SC-A12-602; clarification Q5; research
// D3). The four committed saved-world samples (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`), each copied
// as `world-0.json` into a temporary experience storage and read by a `WorldStore`: the valid sample (the exact bytes
// `WorldStore` writes for the island pack saved to slot 0, "Island, seed 11") opens, also through the presenter, where
// it becomes the world with a stable digest; the newer (document schema 3), damaged (not JSON) and truncated (the valid
// file cut in half) samples are refused as `newer-version`, `damaged` and `damaged`, the world stays as it was, and
// each file stays byte for byte as committed. A lone `world-0.png` leaves slot 0 "Empty."; the valid sample without a
// picture reads "Holds “Island, seed 11”, no picture.". Files and one short session per test, well under 10 s.
import Foundation
import UIKit
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class WorldSampleFileTests: XCTestCase {
    private var temporary: TemporaryWorldsStorage!

    override func setUp() async throws {
        temporary = TemporaryWorldsStorage()
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

    /// Writes `bytes` as the experience's `world-0.json`.
    private func install(_ bytes: Data) throws {
        try storage.write(bytes, to: WorldStore.fileName(slot: 0))
    }

    /// The island pack as the valid sample saved it.
    private func islandDocument() throws -> WorldDocument {
        WorldDocument(state: try WorldPack.island.state().get())
    }

    func testExactlyTheFourSamplesAreBundled() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), ["world-valid.json", "world-newer.json", "world-damaged.json",
                                    "world-truncated.json"])
    }

    func testTheCommittedSamplesOpenOrAreRefused() async throws {
        let valid = try sample("world-valid.json")
        let expected = try islandDocument()
        XCTAssertEqual(expected.name, "Island, seed 11")
        XCTAssertEqual(valid, try expected.encode().get(), "exactly the bytes WorldStore writes for the island pack")
        XCTAssertEqual(try sample("world-truncated.json"), valid.prefix(valid.count / 2), "the valid file cut in half")

        let store = WorldStore(storage: storage)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WorldsTest.open(session, store: store)
        let before = try WorldsTest.core(shell)
        let cases: [(name: String, refusal: WorldDocumentRefusal, status: String)] = [
            ("world-newer.json", .newerVersion,
             "Not opened: The saved file comes from a newer version and was left as it is."),
            ("world-damaged.json", .damaged, "Not opened: The saved file is damaged and was left as it is."),
            ("world-truncated.json", .damaged, "Not opened: The saved file is damaged and was left as it is."),
        ]
        for item in cases {
            let bytes = try sample(item.name)
            try install(bytes)
            XCTAssertEqual(store.read(slot: 0).failure, .document(item.refusal), item.name)
            XCTAssertEqual(WorldDocument.decode(bytes).failure, item.refusal, item.name)
            XCTAssertEqual(shell.presenter.openWorld(slot: 0), item.status, item.name)
            XCTAssertEqual(try WorldsTest.core(shell), before, "\(item.name): the world stays")
            XCTAssertEqual(try storage.read(WorldStore.fileName(slot: 0)), bytes, "\(item.name): byte-identical")
        }

        try install(valid)
        let read = try store.read(slot: 0).get()
        XCTAssertEqual(read, expected)
        XCTAssertEqual(store.summaries()[0], WorldSlotSummary(name: "Island, seed 11", hasPicture: false))
        XCTAssertEqual(shell.presenter.openWorld(slot: 0), "Opened “Island, seed 11”.")
        XCTAssertEqual(try WorldsTest.core(shell).state, read.state, "the sample's state opens")
        let digest = try shell.engine.digest()
        try WorldsTest.frames(session, 2)
        XCTAssertEqual(try shell.engine.digest(), digest, "drawing changes nothing")
        XCTAssertEqual(shell.presenter.openWorld(slot: 0), "Opened “Island, seed 11”.")
        XCTAssertEqual(try shell.engine.digest(), digest, "the digest is stable")
        XCTAssertEqual(shell.presenter.lastPropsDrawn, 7)
        XCTAssertEqual(try storage.read(WorldStore.fileName(slot: 0)), valid, "opening never rewrites the file")
        XCTAssertEqual(storage.list(), [WorldStore.fileName(slot: 0)])
    }

    func testPictureAndWorldMismatchesReadSafely() async throws {
        // A lone picture: no document beside it.
        let picture = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        XCTAssertFalse(picture.isEmpty)
        try storage.write(picture, to: WorldStore.pictureName(slot: 0))
        let lone = ExperienceSession()
        let loneShell = try await WorldsTest.open(lone, store: WorldStore(storage: storage))
        XCTAssertEqual(loneShell.presenter.mirror.slotStatus[0], "Empty.")
        XCTAssertEqual(loneShell.presenter.mirror.slotNames[0], "")
        XCTAssertNil(loneShell.presenter.mirror.slotPictures[0], "a picture without its world is not shown")
        XCTAssertEqual(loneShell.presenter.openWorld(slot: 0), "Not opened: The slot is empty.")
        lone.close()
        XCTAssertEqual(try storage.read(WorldStore.pictureName(slot: 0)), picture, "the lone picture is left as it is")
        try storage.remove(WorldStore.pictureName(slot: 0))

        // The valid sample without its picture.
        let valid = try sample("world-valid.json")
        try install(valid)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WorldsTest.open(session, store: WorldStore(storage: storage))
        XCTAssertEqual(shell.presenter.mirror.slotStatus[0], "Holds “Island, seed 11”, no picture.")
        XCTAssertEqual(shell.presenter.mirror.slotNames[0], "Island, seed 11")
        XCTAssertNil(shell.presenter.mirror.slotPictures[0])
        XCTAssertEqual(try storage.read(WorldStore.fileName(slot: 0)), valid)
        XCTAssertEqual(storage.list(), [WorldStore.fileName(slot: 0)])
    }
}
