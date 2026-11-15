// ExperimentStoreTests — feature 085 (A11-P04) T-A11-403 (FR-A11-402, FR-A11-403; SC-A11-401, SC-A11-402;
// clarification 3; research D3; edge cases "Saving while grabbed or selected", "An empty slot", "A slot name", "Storage unavailable or
// full"). The saved experiments of Physics Playground, files and short sessions only (each test well under 10 s):
//   - the store: a save and read round trip is identical (the file is `experiment-<slot>.json` holding exactly the
//     document's `encoded()` bytes, without grab and selection); names are cut to 24 characters or become
//     "Experiment N"; an empty slot is refused with `empty-slot`; clearing removes the file; a slot outside 0…3 is
//     refused with `invalid-slot`; damaged, newer and invalid files are refused with their reasons and left byte for
//     byte as they were; storage refusals (a full folder, a directory in the file's place) are reported with the
//     storage error's code and change nothing; without storage the same rules hold in memory;
//   - the presenter: saving the edited experiment and opening it again restores the saved world as the world and the
//     starting world (origin the slot, the generator kept), and reset then returns to it; a refused slot changes
//     nothing and reports its reason; the slots' names and statuses are read when the presenter is made.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation

@MainActor
final class ExperimentStoreTests: XCTestCase {
    private var temporary: TemporaryPlaygroundStorage!

    override func setUp() async throws {
        temporary = TemporaryPlaygroundStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// The pendulum preset with the bob selected and grabbed, paused at quarter speed after 30 ticks.
    private func editedPendulum() -> PhysicsWorld {
        var random = SeededRandom(seed: 7)
        var world = Presets.make(.pendulum, random: &random, catalog: PlaygroundCore.catalog)
        for _ in 0..<30 { _ = WorldSimulation.tick(&world, catalog: PlaygroundCore.catalog) }
        world.selectedId = 1
        world.grab = Grab(bodyId: 1, localAnchor: .zero, target: Vec2(6, 4))
        world.timeScaleIndex = 0
        world.paused = true
        return world
    }

    /// `data` with the JSON object edited by `change`.
    private func edited(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func testASaveAndReadRoundTripIsIdenticalWithoutGrabAndSelection() throws {
        let store = ExperimentStore(storage: storage)
        let world = editedPendulum()
        let document = ExperimentDocument(name: "Swing", origin: .preset(1), world: world, slot: 2)
        XCTAssertNil(document.world.grab)
        XCTAssertNil(document.world.selectedId)
        XCTAssertEqual(ExperimentStore.fileName(slot: 2), "experiment-2.json")
        XCTAssertNoThrow(try store.save(document, slot: 2).get())
        XCTAssertEqual(storage.list(), ["experiment-2.json"])
        XCTAssertEqual(try storage.read("experiment-2.json"), document.encoded(), "exactly the encoded document")
        let read = try store.read(slot: 2).get()
        XCTAssertEqual(read, document)
        XCTAssertEqual(read.world, ExperimentDocument.withoutEditing(world))
        XCTAssertEqual(read.world.tick, 30)
        XCTAssertTrue(read.world.paused)
        XCTAssertEqual(read.world.timeScaleIndex, 0)
        XCTAssertEqual(store.summaries(), ["", "", "Swing", ""])
        XCTAssertEqual(store.writes, 1)

        // Saving again replaces the slot.
        let other = ExperimentDocument(name: "Second", origin: .slot(2), world: world, slot: 2)
        XCTAssertNoThrow(try store.save(other, slot: 2).get())
        XCTAssertEqual(try store.read(slot: 2).get(), other)
        XCTAssertEqual(storage.list(), ["experiment-2.json"])
    }

    func testNamesAreCutOrDefaulted() throws {
        let store = ExperimentStore(storage: storage)
        let world = editedPendulum()
        store.save(ExperimentDocument(name: "   ", origin: .preset(1), world: world, slot: 2), slot: 2)
        XCTAssertEqual(try store.read(slot: 2).get().name, "Experiment 3")
        let long = String(repeating: "abcdefghij", count: 4)
        store.save(ExperimentDocument(name: long, origin: .preset(1), world: world, slot: 0), slot: 0)
        XCTAssertEqual(try store.read(slot: 0).get().name, String(long.prefix(24)))
    }

    func testAnEmptySlotIsRefusedAndClearingRemovesTheFile() throws {
        let store = ExperimentStore(storage: storage)
        XCTAssertEqual(store.read(slot: 0).failure, .emptySlot)
        XCTAssertEqual(store.read(slot: 0).failure?.code, "empty-slot")
        XCTAssertEqual(store.clear(slot: 0).failure, .emptySlot)
        let document = ExperimentDocument(name: "Swing", origin: .preset(1), world: editedPendulum(), slot: 0)
        store.save(document, slot: 0)
        XCTAssertTrue(storage.exists("experiment-0.json"))
        XCTAssertNoThrow(try store.clear(slot: 0).get())
        XCTAssertFalse(storage.exists("experiment-0.json"))
        XCTAssertEqual(store.read(slot: 0).failure, .emptySlot)
        XCTAssertEqual(store.summaries(), ["", "", "", ""])
    }

    func testASlotOutsideZeroToThreeIsRefused() {
        let store = ExperimentStore(storage: storage)
        let document = ExperimentDocument(name: "Swing", origin: .preset(1), world: editedPendulum(), slot: 0)
        for slot in [-1, 4] {
            XCTAssertEqual(store.save(document, slot: slot).failure, .invalidSlot)
            XCTAssertEqual(store.read(slot: slot).failure, .invalidSlot)
            XCTAssertEqual(store.clear(slot: slot).failure, .invalidSlot)
        }
        XCTAssertEqual(StoreRefusal.invalidSlot.code, "invalid-slot")
        XCTAssertEqual(storage.list(), [])
    }

    func testRefusedFilesAreReportedAndLeftUntouched() throws {
        let store = ExperimentStore(storage: storage)
        let valid = ExperimentDocument(name: "Swing", origin: .preset(1), world: editedPendulum(), slot: 1).encoded()
        let newer = try edited(valid) { $0["schema"] = 2 }
        let invalid = try edited(valid) { object in
            var world = object["world"] as? [String: Any] ?? [:]
            world["timeScaleIndex"] = 7
            object["world"] = world
        }
        let cases: [(bytes: Data, refusal: DocumentRefusal, code: String)] = [
            (Data("not an experiment".utf8), .damaged, "damaged"),
            (valid.prefix(valid.count / 2), .damaged, "damaged"),
            (newer, .newerVersion, "newer-version"),
            (invalid, .invalidWorld, "invalid-world"),
        ]
        for item in cases {
            try storage.write(item.bytes, to: "experiment-1.json")
            XCTAssertEqual(store.read(slot: 1).failure, .document(item.refusal))
            XCTAssertEqual(store.read(slot: 1).failure?.code, item.code)
            XCTAssertEqual(store.summaries()[1], "")
            XCTAssertEqual(try storage.read("experiment-1.json"), item.bytes, "\(item.code): left byte for byte")
        }
        XCTAssertEqual(store.writes, 0, "reading never writes")
        // A save replaces a refused file with a valid one.
        let document = try ExperimentDocument.decode(valid).get()
        XCTAssertNoThrow(try store.save(document, slot: 1).get())
        XCTAssertEqual(try store.read(slot: 1).get(), document)
    }

    func testStorageRefusalsAreReportedAndChangeNothing() throws {
        let store = ExperimentStore(storage: storage)
        let first = ExperimentDocument(name: "First", origin: .preset(1), world: editedPendulum(), slot: 0)
        store.save(first, slot: 0)
        // A directory in the place of slot 3's file: the write is refused.
        try FileManager.default.createDirectory(at: temporary.folder.appendingPathComponent("experiment-3.json"),
                                                withIntermediateDirectories: true)
        let refused = store.save(first, slot: 3)
        XCTAssertEqual(refused.failure?.code, "storage.write-failed")
        XCTAssertEqual(store.read(slot: 3).failure, .emptySlot, "the directory is not a saved experiment")
        // A full folder (64 files): a new slot is refused, the stored slot stays as it was.
        for index in 0..<(StorageQuota.maxFiles - 1) { try storage.write(Data([1]), to: "filler-\(index)") }
        XCTAssertEqual(store.save(first, slot: 1).failure, .storage(.quotaExceeded("files")))
        XCTAssertEqual(store.save(first, slot: 1).failure?.code, "storage.quota-exceeded")
        XCTAssertFalse(storage.exists("experiment-1.json"))
        XCTAssertEqual(try store.read(slot: 0).get(), first)
        XCTAssertEqual(store.writes, 1)
    }

    func testWithoutStorageTheDocumentsAreKeptInMemory() throws {
        let store = ExperimentStore(storage: nil)
        XCTAssertNil(store.storage)
        let document = ExperimentDocument(name: "Swing", origin: .preset(1), world: editedPendulum(), slot: 3)
        XCTAssertEqual(store.read(slot: 3).failure, .emptySlot)
        XCTAssertNoThrow(try store.save(document, slot: 3).get())
        XCTAssertEqual(try store.bytes(slot: 3).get(), document.encoded())
        XCTAssertEqual(try store.read(slot: 3).get(), document)
        XCTAssertEqual(store.summaries(), ["", "", "", "Swing"])
        XCTAssertNoThrow(try store.clear(slot: 3).get())
        XCTAssertEqual(store.clear(slot: 3).failure, .emptySlot)
        XCTAssertEqual(store.read(slot: 3).failure, .emptySlot)
        XCTAssertEqual(store.save(document, slot: 4).failure, .invalidSlot)
        XCTAssertEqual(store.writes, 1)
    }

    // MARK: Presenter

    func testSavingAndOpeningASlotThenResetReturnsToIt() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, store: ExperimentStore(storage: storage))
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "experiment.preset", values: [1]).isAccepted)
        try PlaygroundTest.frames(session, 15)
        XCTAssertTrue(shell.handle(control: "world.drop", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.select", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.grab", values: [2, 5, 7]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.timeScale", values: [1]).isAccepted)
        let saved = try PlaygroundTest.core(shell)
        XCTAssertEqual(presenter.saveExperiment(slot: 1, name: "  My swing  "), "Saved “My swing”.")
        XCTAssertEqual(presenter.mirror.slotStatus[1], "Saved “My swing”.")
        XCTAssertEqual(presenter.mirror.slotNames, ["", "My swing", "", ""])
        XCTAssertEqual(try PlaygroundTest.core(shell), saved, "saving changes nothing")
        let stored = try presenter.store.read(slot: 1).get()
        XCTAssertEqual(stored.origin, .preset(1))
        XCTAssertEqual(stored.world, ExperimentDocument.withoutEditing(saved.world))

        // Change everything, then open the slot.
        XCTAssertTrue(shell.handle(control: "experiment.preset", values: [3]).isAccepted)
        try PlaygroundTest.frames(session, 5)
        let before = try PlaygroundTest.core(shell)
        XCTAssertEqual(presenter.openExperiment(slot: 1), "Opened “My swing”.")
        let opened = try PlaygroundTest.core(shell)
        XCTAssertEqual(opened.world, stored.world)
        XCTAssertEqual(opened.startingWorld, stored.world)
        XCTAssertEqual(opened.origin, .slot(1))
        XCTAssertEqual(opened.generator, before.generator, "the generator keeps going")
        XCTAssertEqual(opened.preparationSeed, before.preparationSeed)
        XCTAssertNil(opened.tutorial)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("Experiment: “My swing” from slot 2."),
                      shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.experiment, "Experiment: “My swing” from slot 2.")
        XCTAssertNil(presenter.mirror.presetIndex)

        // Run, edit and slow down; reset returns to the opened document, running at normal speed.
        try PlaygroundTest.frames(session, 10)
        XCTAssertTrue(shell.handle(control: "world.drop", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.timeScale", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.reset").isAccepted)
        var expected = stored.world
        expected.paused = false
        expected.timeScaleIndex = PhysicsWorld.normalTimeScaleIndex
        let reset = try PlaygroundTest.core(shell)
        XCTAssertEqual(reset.world, expected)
        XCTAssertEqual(reset.origin, .slot(1))
        session.close()
    }

    func testARefusedSlotChangesNothingAndReportsItsReason() async throws {
        let damaged = Data("{\"schema\": 1, \"name\": ".utf8)
        try storage.write(damaged, to: "experiment-2.json")
        let valid = ExperimentDocument(name: "Swing", origin: .preset(1), world: editedPendulum(), slot: 0)
        try storage.write(valid.encoded(), to: "experiment-0.json")
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, store: ExperimentStore(storage: storage))
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.slotNames, ["Swing", "", "", ""], "read when the presenter is made")
        XCTAssertEqual(presenter.mirror.slotStatus,
                       ["Holds “Swing”.", "Empty.", "The saved file is damaged and was left as it is.", "Empty."])
        let before = try PlaygroundTest.core(shell)
        XCTAssertEqual(presenter.openExperiment(slot: 2),
                       "Not opened: The saved file is damaged and was left as it is.")
        XCTAssertEqual(presenter.openExperiment(slot: 3), "Not opened: The slot is empty.")
        XCTAssertEqual(presenter.clearExperiment(slot: 3), "Not cleared: The slot is empty.")
        XCTAssertEqual(try PlaygroundTest.core(shell), before, "a refused slot changes nothing")
        XCTAssertEqual(try storage.read("experiment-2.json"), damaged, "the file is left byte for byte")

        // A refused write is reported and changes nothing.
        try FileManager.default.createDirectory(at: temporary.folder.appendingPathComponent("experiment-1.json"),
                                                withIntermediateDirectories: true)
        XCTAssertEqual(presenter.saveExperiment(slot: 1, name: "X"),
                       "Not saved: The storage refused it (storage.write-failed).")
        XCTAssertEqual(presenter.mirror.slotNames[1], "")
        XCTAssertEqual(presenter.clearExperiment(slot: 0), "Cleared.")
        XCTAssertFalse(storage.exists("experiment-0.json"))
        XCTAssertEqual(presenter.mirror.slotNames, ["", "", "", ""])
        XCTAssertEqual(presenter.saveExperiment(slot: 5, name: "X"), "There is no such slot.")
        session.close()
    }
}

extension Result {
    /// The failure, nil for a success.
    var failure: Failure? {
        if case .failure(let failure) = self { return failure }
        return nil
    }
}
