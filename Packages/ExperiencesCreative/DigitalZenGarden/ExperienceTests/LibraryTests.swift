// LibraryTests — feature 148 (A20-P04) T-A20-402 (FR-A20-401, FR-A20-402; SC-A20-401; clarifications Q1, Q5;
// contracts/library.md "Library"). The named gardens over a temporary storage: a save and open round trip is exact;
// the list, rename and delete; the 12-garden cap with its message; trimmed names of 1…40 characters; saving under a
// used name replaces that garden while renaming to one is refused with its message; damaged, newer-version, oversized
// and refused-document files are listed as unreadable with their codes, never opened and kept on disk; a failed write
// (the storage's byte quota) keeps the previous file; a newer index makes the library read only; opening through the
// presenter restores the document through the shell, so the undo history restarts and the digest equals the opened
// document's; deleting the open garden's saved copy leaves the open garden. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A temporary storage of the experience: its own folder and defaults suite.
@MainActor
struct GardenStoragePlace {
    /// The defaults suite and folder name.
    let suite: String
    /// The root folder.
    let root: URL
    /// The handle.
    let storage: ExperienceStorage

    /// A fresh place named `name`.
    init(_ name: String) throws {
        suite = "a20.library-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: GardenTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

/// A clock for announcement routes that moves one second per reading, so no announcement is held back.
@MainActor
final class GardenTicker {
    /// The current time in seconds.
    var now = 0.0

    /// The next reading.
    func tick() -> Double {
        now += 1
        return now
    }
}

/// Library helpers.
@MainActor
enum GardenLibraryTest {
    /// A garden with `strokes` strokes, two stones and the warm tone.
    static func document(strokes: Int = 3) -> GardenDocument {
        var history = GardenHistory()
        for index in 0..<strokes {
            let y = 0.2 + 0.05 * Double(index % 10)
            history.rake([Vec2(0.1, y), Vec2(0.5, y + 0.02), Vec2(0.9, y)])
        }
        history.placeStone(kind: "flat-slate", position: Vec2(0.3, 0.6), rotation: 0.4)
        history.placeStone(kind: "river-pebble", position: Vec2(0.7, 0.3))
        history.setTone("warm")
        return history.document
    }

    /// A route recording into `sink`, with VoiceOver running and a clock that moves one second per reading.
    static func route(_ sink: RecordingAnnouncementSink) -> ExperienceFeedback {
        let ticker = GardenTicker()
        return ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: sink,
                                  clock: { ticker.tick() }, voiceOverRunning: { true })
    }

    /// A prepared, active shell over `storage` whose announcements go to `sink`.
    static func shell(_ storage: ExperienceStorage,
                      sink: RecordingAnnouncementSink = RecordingAnnouncementSink()) async throws
        -> ExperienceShell<GardenPresenter> {
        let shell = DigitalZenGardenExperience.make(id: GardenTest.id, storage: storage)
        shell.presenter.feedback = route(sink)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The saved entry of `result`, recording an issue for a failure.
    static func saved(_ result: Result<GardenLibraryEntry, GardenLibraryFailure>,
                      sourceLocation: SourceLocation = #_sourceLocation) -> GardenLibraryEntry? {
        switch result {
        case .success(let entry): return entry
        case .failure(let failure):
            Issue.record("refused: \(failure.code)", sourceLocation: sourceLocation)
            return nil
        }
    }

    /// The failure of `result`; nil for a success.
    static func failure<T>(_ result: Result<T, GardenLibraryFailure>) -> GardenLibraryFailure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct LibraryTests {
    @Test func aSaveAndOpenRoundTripIsExact() throws {
        let place = try GardenStoragePlace("round-trip")
        defer { place.remove() }
        let library = GardenLibrary(storage: place.storage)
        #expect(library.entries.isEmpty && library.next == 1 && !library.isReadOnly)
        let document = GardenLibraryTest.document()
        let entry = try #require(GardenLibraryTest.saved(library.save(name: "Morning", document: document)))
        #expect(entry.file == "garden-1.json" && entry.name == "Morning" && entry.order == 1 && entry.isReadable)
        #expect(library.entries == [entry])
        #expect(place.storage.exists(GardenLibrary.indexFile))
        let opened = library.open(entry.file)
        guard case .success(let found) = opened else {
            Issue.record("open refused")
            return
        }
        #expect(found.document == document && found.entry == entry)
        // A second library over the same storage reads the same list and counter.
        let again = GardenLibrary(storage: place.storage)
        #expect(again.entries == library.entries && again.next == 2)
    }

    @Test func listRenameAndDelete() throws {
        let place = try GardenStoragePlace("rename")
        defer { place.remove() }
        let library = GardenLibrary(storage: place.storage)
        let first = try #require(GardenLibraryTest.saved(library.save(name: "Morning", document: .empty)))
        let second = try #require(GardenLibraryTest.saved(library.save(name: "Evening",
                                                                      document: GardenLibraryTest.document())))
        #expect(library.entries.map(\.name) == ["Evening", "Morning"])   // newest first
        let renamed = try #require(GardenLibraryTest.saved(library.rename(first.file, to: "  Dawn ")))
        #expect(renamed.name == "Dawn" && renamed.file == first.file && renamed.order == first.order)
        #expect(library.entries.map(\.name) == ["Evening", "Dawn"])
        let taken = GardenLibraryTest.failure(library.rename(first.file, to: "evening"))
        #expect(taken == .nameTaken("Evening"))
        #expect(taken?.message == "A garden is already called Evening.")
        #expect(library.entry(file: first.file)?.name == "Dawn")
        let deleted = library.delete(second.file)
        #expect(GardenLibraryTest.failure(deleted) == nil)
        #expect(library.entries.map(\.name) == ["Dawn"] && !place.storage.exists(second.file))
        #expect(GardenLibraryTest.failure(library.delete(second.file)) == .notFound)
        // The counter is not reused after a delete.
        let third = try #require(GardenLibraryTest.saved(library.save(name: "Noon", document: .empty)))
        #expect(third.file == "garden-3.json")
    }

    @Test func theLibraryHoldsTwelveGardens() throws {
        let place = try GardenStoragePlace("cap")
        defer { place.remove() }
        let library = GardenLibrary(storage: place.storage)
        for index in 1...GardenLibrary.maxGardens {
            _ = GardenLibraryTest.saved(library.save(name: "Garden \(index)", document: .empty))
        }
        #expect(library.entries.count == 12)
        let refused = GardenLibraryTest.failure(library.save(name: "Garden 13", document: .empty))
        #expect(refused == .full && refused?.message == "The library holds 12 gardens.")
        #expect(library.entries.count == 12 && !place.storage.exists("garden-13.json"))
        // Replacing an existing garden works at the cap.
        let replaced = try #require(GardenLibraryTest.saved(library.save(name: "Garden 3",
                                                                        document: GardenLibraryTest.document())))
        #expect(replaced.file == "garden-3.json" && library.entries.count == 12)
        #expect(library.entries.first == replaced)
    }

    @Test func namesAreTrimmedAndOneToFortyCharacters() throws {
        let place = try GardenStoragePlace("names")
        defer { place.remove() }
        let library = GardenLibrary(storage: place.storage)
        let trimmed = try #require(GardenLibraryTest.saved(library.save(name: "  Morning \n", document: .empty)))
        #expect(trimmed.name == "Morning")
        let forty = String(repeating: "a", count: 40)
        #expect(GardenLibraryTest.saved(library.save(name: forty, document: .empty))?.name == forty)
        for bad in ["", "   ", String(repeating: "b", count: 41)] {
            let refused = GardenLibraryTest.failure(library.save(name: bad, document: .empty))
            #expect(refused == .invalidName, "\(bad.count) characters")
            #expect(GardenLibraryTest.failure(library.rename(trimmed.file, to: bad)) == .invalidName)
        }
        #expect(library.entries.count == 2)
        // Saving under a used name (any case) replaces that garden in its file.
        let document = GardenLibraryTest.document()
        let replaced = try #require(GardenLibraryTest.saved(library.save(name: "MORNING", document: document)))
        #expect(replaced.file == trimmed.file && replaced.name == "MORNING" && library.entries.count == 2)
        guard case .success(let opened) = library.open(trimmed.file) else {
            Issue.record("open refused")
            return
        }
        #expect(opened.document == document)
    }

    @Test func refusedFilesAreListedWithTheirCodesNeverOpenedAndKept() throws {
        let place = try GardenStoragePlace("refusals")
        defer { place.remove() }
        let storage = place.storage
        try storage.write(Data("{\"kind\":\"a20.saved-garden\"".utf8), to: "garden-1.json")
        try storage.write(Data("{\"body\":{},\"kind\":\"a20.saved-garden\",\"version\":2}".utf8), to: "garden-2.json")
        var oversized = try GardenLibrary.encode(GardenLibrary.SavedGarden(name: "Big", order: 1, document: .empty))
        oversized.append(Data(repeating: 0x20, count: GardenLibrary.maxFileBytes))
        try storage.write(oversized, to: "garden-3.json")
        var unknownTone = GardenDocument.empty
        unknownTone.tone = "blue"
        try storage.write(try GardenLibrary.encode(GardenLibrary.SavedGarden(name: "Blue", order: 2,
                                                                            document: unknownTone)),
                          to: "garden-4.json")
        let library = GardenLibrary(storage: storage)
        let codes = library.entries.map { $0.refusal ?? "readable" }
        #expect(codes == ["damaged", "newer-version", "too-large", "unknown-tone"])
        for entry in library.entries {
            let refused = GardenLibraryTest.failure(library.open(entry.file))
            #expect(refused == .unreadable(entry.refusal ?? ""), "\(entry.file)")
            #expect(GardenLibraryTest.failure(library.rename(entry.file, to: "Fixed")) == .unreadable(entry.refusal ?? ""))
        }
        // A good garden still saves (after the highest file) and opens; the refused files stay on disk.
        let good = try #require(GardenLibraryTest.saved(library.save(name: "Morning", document: .empty)))
        #expect(good.file == "garden-5.json")
        #expect(GardenLibraryTest.failure(library.open(good.file)) == nil)
        for n in 1...4 { #expect(storage.exists(GardenLibrary.fileName(n)), "garden-\(n).json kept") }
        #expect(library.entries.count == 5 && library.readable == [good])
        // The person may delete an unreadable file.
        #expect(GardenLibraryTest.failure(library.delete("garden-1.json")) == nil)
        #expect(!storage.exists("garden-1.json") && library.entries.count == 4)
    }

    @Test func aFailedWriteKeepsThePreviousFile() throws {
        let place = try GardenStoragePlace("failed-write")
        defer { place.remove() }
        let storage = place.storage
        let library = GardenLibrary(storage: storage)
        let entry = try #require(GardenLibraryTest.saved(library.save(name: "Morning", document: .empty)))
        let before = try storage.read(entry.file)
        // Fill the storage up to a few bytes below its byte quota, so that a larger garden no longer fits.
        var used = 0
        for name in storage.list() { used += try storage.read(name).count }
        try storage.write(Data(count: StorageQuota.maxBytes - used - 8), to: "filler.bin")
        let refused = GardenLibraryTest.failure(library.save(name: "Morning", document: GardenLibraryTest.document()))
        #expect(refused == .storage("storage.quota-exceeded"))
        #expect(refused?.message == "The library could not be changed (storage.quota-exceeded).")
        #expect(try storage.read(entry.file) == before)
        guard case .success(let opened) = library.open(entry.file) else {
            Issue.record("open refused")
            return
        }
        #expect(opened.document == .empty)
        // A new garden that does not fit is refused too and leaves no file.
        let refusedNew = GardenLibraryTest.failure(library.save(name: "Evening", document: GardenLibraryTest.document()))
        #expect(refusedNew == .storage("storage.quota-exceeded") && !storage.exists("garden-2.json"))
        #expect(library.entries == [entry])
    }

    @Test func anOversizedGardenIsRefusedBeforeWriting() throws {
        let place = try GardenStoragePlace("oversized")
        defer { place.remove() }
        let library = GardenLibrary(storage: place.storage)
        let refused = GardenLibraryTest.failure(library.save(name: "Full", document: GardenLibraryTest.document(strokes: 400)))
        guard case .tooLarge(let bytes) = refused else {
            Issue.record("not refused as too large: \(String(describing: refused))")
            return
        }
        #expect(bytes > GardenLibrary.maxFileBytes && library.entries.isEmpty && place.storage.list().isEmpty)
    }

    @Test func aDamagedIndexIsRebuiltAndANewerIndexIsReadOnly() throws {
        let place = try GardenStoragePlace("index")
        defer { place.remove() }
        let storage = place.storage
        let library = GardenLibrary(storage: storage)
        let entry = try #require(GardenLibraryTest.saved(library.save(name: "Morning", document: .empty)))
        try storage.write(Data("not json".utf8), to: GardenLibrary.indexFile)
        let damaged = GardenLibrary(storage: storage)
        #expect(damaged.indexProblem == "damaged" && !damaged.isReadOnly && damaged.entries == [entry])
        let next = try #require(GardenLibraryTest.saved(damaged.save(name: "Evening", document: .empty)))
        #expect(next.file == "garden-2.json")
        #expect(GardenLibrary(storage: storage).indexProblem == nil)
        try storage.write(Data("{\"body\":{},\"kind\":\"a20.garden-library\",\"version\":2}".utf8),
                          to: GardenLibrary.indexFile)
        let newer = GardenLibrary(storage: storage)
        #expect(newer.isReadOnly && newer.indexProblem == "newer-version" && newer.entries.count == 2)
        #expect(GardenLibraryTest.failure(newer.save(name: "Noon", document: .empty)) == .readOnly)
        #expect(GardenLibraryTest.failure(newer.rename(entry.file, to: "Noon")) == .readOnly)
        #expect(GardenLibraryTest.failure(newer.delete(entry.file)) == .readOnly)
        #expect(GardenLibraryTest.failure(newer.open(entry.file)) == nil)
    }

    @Test func openingRestoresThroughTheShellAndRestartsTheHistory() async throws {
        let place = try GardenStoragePlace("open")
        defer { place.remove() }
        let shell = try await GardenLibraryTest.shell(place.storage)
        let presenter = shell.presenter
        GardenTest.rake(shell, from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.4))
        GardenTest.accept(shell, "stone.place", [1, 0.4, 0.6])
        GardenTest.accept(shell, "sand.tone", [2])
        let saved = try GardenTest.core(shell).document
        let entry = try #require(GardenLibraryTest.saved(presenter.saveGarden(named: "Morning")))
        // Change the garden, then open the saved one.
        GardenTest.rake(shell, from: Vec2(0.1, 0.1), to: Vec2(0.9, 0.9))
        GardenTest.accept(shell, "edit.undo")
        #expect(try GardenTest.core(shell).history.canRedo)
        #expect(GardenLibraryTest.failure(presenter.openGarden(entry.file)) == nil)
        let core = try GardenTest.core(shell)
        #expect(core.document == GardenCore(document: saved).document)
        #expect(!core.history.canUndo && !core.history.canRedo && core.selectedStone == nil)
        #expect(try GardenTest.digest(shell) == gardenDigest(GardenCore(document: saved)))
        #expect(presenter.mirror.strokeCount == 1 && !presenter.mirror.canUndo && presenter.openedName == "Morning")
        #expect(presenter.mirror.libraryMessage == "Opened Morning.")
        // Undo and redo work again from the opened garden.
        GardenTest.rake(shell, from: Vec2(0.2, 0.8), to: Vec2(0.7, 0.8))
        GardenTest.accept(shell, "edit.undo")
        #expect(try GardenTest.core(shell).document == core.document)
        // Deleting the saved copy leaves the open garden as it is.
        #expect(GardenLibraryTest.failure(presenter.deleteGarden(entry.file)) == nil)
        #expect(try GardenTest.core(shell).document == core.document)
        #expect(presenter.library?.entries.isEmpty == true)
    }

    @Test func withoutStorageTheLibraryIsUnavailable() async throws {
        let shell = try await GardenTest.shell()
        #expect(shell.presenter.library == nil)
        let refused = GardenLibraryTest.failure(shell.presenter.saveGarden(named: "Morning"))
        #expect(refused == .unavailable && shell.presenter.mirror.libraryMessage == "The library is not available.")
    }
}
