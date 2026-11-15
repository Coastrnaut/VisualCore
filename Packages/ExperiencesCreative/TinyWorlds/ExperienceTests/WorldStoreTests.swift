// WorldStoreTests — feature 091 (A12-P03) T-A12-303 (FR-A12-321, FR-A12-322, FR-A12-323; SC-A12-302, SC-A12-303,
// SC-A12-304; clarifications Q4 and Q5; acceptance scenarios US3-1 … US3-4). The saved worlds of Tiny Worlds, files and
// short sessions only (each test well under 10 s):
//   - the store: a save and read round trip is bit-identical in every prop transform and gives the same digest (the
//     file `world-<slot>.json` holds exactly the document's `encode()` bytes, the picture `world-<slot>.png` beside
//     it); damaged, truncated, newer and oversized files are refused with their reasons and left byte for byte; a write
//     the file system refuses midway (a read-only folder) and the temporary file a process left behind when it ended
//     mid-write both leave the previous file byte-identical; a full folder refuses a new slot; an oversized or missing
//     thumbnail stores no picture and removes the old one; empty and invalid slots; without storage the same rules
//     hold in memory;
//   - the presenter: saving draws a 160 × 120 PNG thumbnail of at most 64 KB through the session's still renderer and
//     the slot list shows it; opening the slot after the world changed restores the saved world exactly (state and
//     digest); a refused slot is reported, changes nothing and leaves its file as it was; without a still renderer the
//     world is saved without a picture and the slot says so.
// Feature 093 (A12-P05) T-A12-506 (FR-A12-504; SC-A12-504): each of the three packs saved at each detail tier reopens
// at another tier with the same state and digest, its thumbnail a 160 × 120 PNG of at most 64 KB (the tier is
// presentation only and never enters a saved world).
import Foundation
import UIKit
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreUI

@MainActor
final class WorldStoreTests: XCTestCase {
    private var temporary: TemporaryWorldsStorage!

    override func setUp() async throws {
        temporary = TemporaryWorldsStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// A customised island: five props (the last selected, one turned) and a moved light.
    private func customised() -> WorldState {
        var state = worldsStateWithProps(count: 5, light: WorldLight(azimuth: 123.456, elevation: 33.3, ambient: 0.21))
        XCTAssertNil(WorldEditing.rotate(degrees: 37.123456789, in: &state))
        return state
    }

    /// `data` with the JSON object edited by `change`.
    private func edited(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func testASaveAndReadRoundTripIsBitIdentical() throws {
        let store = WorldStore(storage: storage)
        let state = customised()
        XCTAssertEqual(state.props.count, 5)
        let document = WorldDocument(state: state)
        XCTAssertEqual(document.name, "Island, seed 1")
        XCTAssertEqual(WorldStore.fileName(slot: 2), "world-2.json")
        XCTAssertEqual(WorldStore.pictureName(slot: 2), "world-2.png")
        let picture = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
        XCTAssertEqual(try store.save(document, slot: 2, thumbnail: picture).get(), true)
        XCTAssertEqual(storage.list(), ["world-2.json", "world-2.png"])
        XCTAssertEqual(try storage.read("world-2.json"), try document.encode().get(), "exactly the encoded document")
        XCTAssertEqual(try storage.read("world-2.png"), picture)
        let read = try store.read(slot: 2).get()
        XCTAssertEqual(read, document)
        for (a, b) in zip(read.state.props, state.props) {
            for (u, v) in [(a.x, b.x), (a.y, b.y), (a.z, b.z), (a.rotation, b.rotation), (a.scale, b.scale)] {
                XCTAssertEqual(u.bitPattern, v.bitPattern, "every transform reads back bit-identical")
            }
            XCTAssertEqual(a.kind, b.kind)
        }
        XCTAssertEqual(read.state.light, state.light)
        XCTAssertEqual(read.state.selection, state.selection)
        XCTAssertEqual(try worldsDigest(worldsCore(read.state)), try worldsDigest(worldsCore(state)), "same digest")
        XCTAssertEqual(store.summaries(), [WorldSlotSummary(name: "", hasPicture: false),
                                           WorldSlotSummary(name: "", hasPicture: false),
                                           WorldSlotSummary(name: "Island, seed 1", hasPicture: true),
                                           WorldSlotSummary(name: "", hasPicture: false)])
        XCTAssertEqual(store.thumbnail(slot: 2), picture)
        XCTAssertEqual(store.writes, 1)

        // Saving again replaces the slot; without a picture the old one is removed.
        let other = WorldDocument(name: "Second", state: WorldState.initial)
        XCTAssertEqual(try store.save(other, slot: 2, thumbnail: nil).get(), false)
        XCTAssertEqual(try store.read(slot: 2).get(), other)
        XCTAssertEqual(storage.list(), ["world-2.json"], "no picture of an earlier world stays")
        XCTAssertEqual(store.summaries()[2], WorldSlotSummary(name: "Second", hasPicture: false))
    }

    func testRefusedFilesAreReportedAndLeftUntouched() throws {
        let store = WorldStore(storage: storage)
        let valid = try WorldDocument(state: customised()).encode().get()
        let newer = try edited(valid) { $0["schema"] = 3 }
        let newerState = try edited(valid) { object in
            var state = object["state"] as? [String: Any] ?? [:]
            state["schema"] = 3
            object["state"] = state
        }
        let badProp = try edited(valid) { object in
            var state = object["state"] as? [String: Any] ?? [:]
            var props = state["props"] as? [[String: Any]] ?? []
            props[0]["x"] = 9.0
            state["props"] = props
            object["state"] = state
        }
        var oversized = valid
        oversized.append(Data(repeating: 0x20, count: WorldDocument.maxBytes))
        let cases: [(bytes: Data, refusal: WorldDocumentRefusal)] = [
            (Data("not a world".utf8), .damaged),
            (valid.prefix(valid.count / 2), .damaged),
            (badProp, .damaged),
            (newer, .newerVersion),
            (newerState, .newerVersion),
            (oversized, .tooLarge),
        ]
        for item in cases {
            try storage.write(item.bytes, to: "world-1.json")
            XCTAssertEqual(store.read(slot: 1).failure, .document(item.refusal), "\(item.refusal)")
            XCTAssertEqual(store.read(slot: 1).failure?.code, item.refusal.rawValue)
            XCTAssertEqual(store.summaries()[1].name, "")
            XCTAssertEqual(try storage.read("world-1.json"), item.bytes, "\(item.refusal): left byte for byte")
        }
        XCTAssertEqual(store.writes, 0, "reading never writes")
        // A save replaces a refused file with a valid one.
        let document = try WorldDocument.decode(valid).get()
        XCTAssertNoThrow(try store.save(document, slot: 1, thumbnail: nil).get())
        XCTAssertEqual(try store.read(slot: 1).get(), document)
    }

    func testAnInterruptedWriteKeepsThePreviousFileByteIdentical() throws {
        let store = WorldStore(storage: storage)
        let first = WorldDocument(name: "First", state: customised())
        XCTAssertNoThrow(try store.save(first, slot: 0, thumbnail: Data([1, 2, 3])).get())
        let before = try storage.read("world-0.json")

        // A process that ended mid-write leaves its hidden temporary file: readers still see the previous file.
        let partial = Data(before.prefix(before.count / 3))
        try partial.write(to: temporary.folder.appendingPathComponent(".world-0.json.tmp-interrupted"))
        XCTAssertEqual(try storage.read("world-0.json"), before)
        XCTAssertEqual(try store.read(slot: 0).get(), first)
        XCTAssertEqual(storage.list(), ["world-0.json", "world-0.png"], "the temporary file is not a saved world")

        // The file system refuses the write midway (a read-only folder): the save is refused and nothing changes.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: temporary.folder.path)
        let second = WorldDocument(name: "Second", state: WorldState.initial)
        let refused = store.save(second, slot: 0, thumbnail: Data([9]))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.folder.path)
        XCTAssertEqual(refused.failure?.code, "storage.write-failed")
        XCTAssertEqual(try storage.read("world-0.json"), before, "the previous file is byte-identical")
        XCTAssertEqual(try storage.read("world-0.png"), Data([1, 2, 3]), "and so is its picture")
        XCTAssertEqual(try store.read(slot: 0).get(), first)

        // A full folder (64 files): a new slot is refused, the stored slot stays as it was.
        for index in 0..<(StorageQuota.maxFiles - 2) { try storage.write(Data([1]), to: "filler-\(index)") }
        XCTAssertEqual(store.save(first, slot: 3, thumbnail: nil).failure, .storage(.quotaExceeded("files")))
        XCTAssertFalse(storage.exists("world-3.json"))
        XCTAssertEqual(try storage.read("world-0.json"), before)
        XCTAssertEqual(store.writes, 1)
    }

    func testThumbnailsAboveTheCapAreNotStored() throws {
        let store = WorldStore(storage: storage)
        let document = WorldDocument(state: customised())
        XCTAssertEqual(try store.save(document, slot: 1, thumbnail: Data([7])).get(), true)
        let large = Data(repeating: 1, count: WorldStore.maxThumbnailBytes + 1)
        XCTAssertEqual(try store.save(document, slot: 1, thumbnail: large).get(), false, "saved without a picture")
        XCTAssertFalse(storage.exists("world-1.png"), "the old picture is removed")
        XCTAssertEqual(try store.read(slot: 1).get(), document, "the document is saved all the same")
        XCTAssertNil(store.thumbnail(slot: 1))
        // A picture file above the cap written by someone else is not shown.
        try storage.write(large, to: "world-1.png")
        XCTAssertNil(store.thumbnail(slot: 1))
        XCTAssertFalse(store.summaries()[1].hasPicture)
    }

    func testEmptyAndInvalidSlotsAndClearing() throws {
        let store = WorldStore(storage: storage)
        XCTAssertEqual(store.read(slot: 0).failure, .emptySlot)
        XCTAssertEqual(store.read(slot: 0).failure?.code, "empty-slot")
        XCTAssertEqual(store.clear(slot: 0).failure, .emptySlot)
        let document = WorldDocument(state: customised())
        for slot in [-1, 4] {
            XCTAssertEqual(store.save(document, slot: slot, thumbnail: nil).failure, .invalidSlot)
            XCTAssertEqual(store.read(slot: slot).failure, .invalidSlot)
            XCTAssertEqual(store.clear(slot: slot).failure, .invalidSlot)
            XCTAssertNil(store.thumbnail(slot: slot))
        }
        XCTAssertEqual(WorldStoreRefusal.invalidSlot.code, "invalid-slot")
        XCTAssertEqual(storage.list(), [])
        store.save(document, slot: 0, thumbnail: Data([5]))
        XCTAssertNoThrow(try store.clear(slot: 0).get())
        XCTAssertEqual(storage.list(), [], "both files are removed")
        XCTAssertEqual(store.read(slot: 0).failure, .emptySlot)

        // Without storage the same rules hold in memory.
        let memory = WorldStore(storage: nil)
        XCTAssertEqual(memory.read(slot: 3).failure, .emptySlot)
        XCTAssertEqual(try memory.save(document, slot: 3, thumbnail: Data([5])).get(), true)
        XCTAssertEqual(try memory.bytes(slot: 3).get(), try document.encode().get())
        XCTAssertEqual(try memory.read(slot: 3).get(), document)
        XCTAssertEqual(memory.summaries()[3], WorldSlotSummary(name: "Island, seed 1", hasPicture: true))
        XCTAssertNoThrow(try memory.clear(slot: 3).get())
        XCTAssertEqual(memory.clear(slot: 3).failure, .emptySlot)
        XCTAssertNil(memory.thumbnail(slot: 3))
    }

    // MARK: Presenter

    func testSavingDrawsAThumbnailAndOpeningRestoresTheWorldExactly() async throws {
        let session = ExperienceSession()
        let store = WorldStore(storage: storage)
        let shell = try await WorldsTest.open(session, store: store)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.slotStatus, ["Empty.", "Empty.", "Empty.", "Empty."])
        for (control, values) in [("prop.place", [0.0, 0, 0]), ("prop.place", [2.0, 1.5, 0.5]),
                                  ("prop.rotate", [45.0]), ("light.azimuth", [200.0]), ("light.ambient", [0.5])] {
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted, control)
        }
        try WorldsTest.frames(session, 1)
        let saved = try WorldsTest.core(shell)
        let digest = try shell.engine.digest()
        XCTAssertEqual(presenter.saveWorld(slot: 1, still: WorldsTest.stillRenderer(session)),
                       "Saved “Island, seed 1”.")
        XCTAssertEqual(try WorldsTest.core(shell), saved, "saving changes nothing")
        XCTAssertEqual(try shell.engine.digest(), digest)
        let png = try storage.read("world-1.png")
        XCTAssertLessThanOrEqual(png.count, WorldStore.maxThumbnailBytes)
        let image = try XCTUnwrap(UIImage(data: png)?.cgImage)
        XCTAssertEqual(image.width, 160)
        XCTAssertEqual(image.height, 120)
        XCTAssertEqual(presenter.mirror.slotPictures[1], png, "the slot list shows the thumbnail")
        XCTAssertEqual(presenter.mirror.slotNames[1], "Island, seed 1")
        XCTAssertEqual(try store.read(slot: 1).get().state, saved.state)

        // Change everything, then open the slot.
        XCTAssertTrue(shell.handle(control: "world.preset", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [90, 10]).isAccepted)
        try WorldsTest.frames(session, 2)
        XCTAssertNotEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(presenter.openWorld(slot: 1), "Opened “Island, seed 1”.")
        let opened = try WorldsTest.core(shell)
        XCTAssertEqual(opened.state, saved.state, "the same terrain, props, light and view")
        XCTAssertEqual(try shell.engine.digest(), digest, "the reopened world has the same digest")
        XCTAssertEqual(opened.preparationSeed, saved.preparationSeed)
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastPropsDrawn, 2)
        XCTAssertEqual(presenter.mirror.props, saved.props)
        session.close()
    }

    func testSavedWorldsRoundTripAcrossTiersAndPacks() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, store: WorldStore(storage: storage))
        let presenter = shell.presenter
        for pack in 0..<3 {
            for saveTier in 0..<3 {
                let label = "pack \(pack), saved at tier \(saveTier)"
                XCTAssertTrue(shell.handle(control: "world.pack", values: [Double(pack)]).isAccepted, label)
                try shell.setQualityTier(saveTier)
                try WorldsTest.frames(session, 1)
                XCTAssertEqual(presenter.lastTier, saveTier, label)
                let saved = try WorldsTest.core(shell)
                let digest = try shell.engine.digest()
                let message = presenter.saveWorld(slot: pack, still: WorldsTest.stillRenderer(session))
                XCTAssertTrue(message.hasPrefix("Saved") && !message.contains("no picture"), "\(label): \(message)")
                let png = try storage.read(WorldStore.pictureName(slot: pack))
                XCTAssertLessThanOrEqual(png.count, WorldStore.maxThumbnailBytes, label)
                let image = try XCTUnwrap(UIImage(data: png)?.cgImage, label)
                XCTAssertEqual(image.width, 160, label)
                XCTAssertEqual(image.height, 120, label)

                // Another tier and another world, then open the slot.
                let openTier = (saveTier + 1) % 3
                try shell.setQualityTier(openTier)
                XCTAssertTrue(shell.handle(control: "world.preset", values: [Double((pack + 1) % 3)]).isAccepted, label)
                try WorldsTest.frames(session, 1)
                XCTAssertEqual(presenter.lastTier, openTier, label)
                XCTAssertNotEqual(try shell.engine.digest(), digest, "\(label): the world changed")
                let opened = presenter.openWorld(slot: pack)
                XCTAssertTrue(opened.hasPrefix("Opened"), "\(label): \(opened)")
                XCTAssertEqual(try WorldsTest.core(shell).state, saved.state, "\(label): the same document")
                XCTAssertEqual(try shell.engine.digest(), digest, "\(label): the same digest")
                try WorldsTest.frames(session, 1)
                XCTAssertEqual(presenter.lastTier, openTier, "\(label): opened at the other tier")
                XCTAssertEqual(try shell.engine.digest(), digest, "\(label): drawing changes nothing")
            }
        }
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testARefusedSlotChangesNothingAndReportsItsReason() async throws {
        let damaged = Data("{\"schema\": 2, \"name\": ".utf8)
        try storage.write(damaged, to: "world-2.json")
        let newer = try edited(try WorldDocument(state: WorldState.initial).encode().get()) { $0["schema"] = 3 }
        try storage.write(newer, to: "world-3.json")
        let valid = WorldDocument(name: "Kept", state: customised())
        try storage.write(try valid.encode().get(), to: "world-0.json")
        let session = ExperienceSession()
        let sink = RecordingAnnouncementSink()
        let shell = try await WorldsTest.open(session, announcements: sink, store: WorldStore(storage: storage))
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.slotNames, ["Kept", "", "", ""], "read when the presenter is made")
        XCTAssertEqual(presenter.mirror.slotStatus,
                       ["Holds “Kept”, no picture.", "Empty.", "The saved file is damaged and was left as it is.",
                        "The saved file comes from a newer version and was left as it is."])
        let before = try WorldsTest.core(shell)
        let digest = try shell.engine.digest()
        XCTAssertEqual(presenter.openWorld(slot: 2), "Not opened: The saved file is damaged and was left as it is.")
        XCTAssertEqual(presenter.openWorld(slot: 3),
                       "Not opened: The saved file comes from a newer version and was left as it is.")
        XCTAssertEqual(presenter.openWorld(slot: 1), "Not opened: The slot is empty.")
        XCTAssertEqual(sink.announced.last, "Not opened: The slot is empty.", "spoken while VoiceOver runs")
        XCTAssertEqual(presenter.clearWorld(slot: 1), "Not cleared: The slot is empty.")
        XCTAssertEqual(try WorldsTest.core(shell), before, "a refused slot changes nothing")
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(try storage.read("world-2.json"), damaged, "the file is left byte for byte")
        XCTAssertEqual(try storage.read("world-3.json"), newer)

        // Without a still renderer the world is saved without a picture, and the slot says so.
        XCTAssertEqual(presenter.saveWorld(slot: 1, still: nil), "Saved “Island, seed 1”, no picture.")
        XCTAssertFalse(storage.exists("world-1.png"))
        XCTAssertNil(presenter.mirror.slotPictures[1])
        presenter.refreshSlots()
        XCTAssertEqual(presenter.mirror.slotStatus[1], "Holds “Island, seed 1”, no picture.")
        XCTAssertEqual(presenter.openWorld(slot: 0), "Opened “Kept”.")
        XCTAssertEqual(try WorldsTest.core(shell).props, valid.state.props)
        XCTAssertEqual(presenter.clearWorld(slot: 0), "Cleared.")
        XCTAssertFalse(storage.exists("world-0.json"))
        XCTAssertEqual(presenter.mirror.slotNames, ["", "Island, seed 1", "", ""])
        XCTAssertEqual(presenter.saveWorld(slot: 5, still: nil), "There is no such slot.")
        session.close()
    }
}
