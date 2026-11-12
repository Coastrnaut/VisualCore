// SavedStateStoreTests — feature 191 T-U05-004 (UA-F05; FR-U05-012, FR-U05-013, FR-U05-015, FR-U05-030,
// FR-U05-032; SC-U05-004, SC-U05-005, SC-U05-009; data-model section 3): loading, saving, the unreadable files,
// quarantine with at most three copies, interrupted saves and their leftovers, and removal.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct SavedStateStoreTests {
    private static let digestHex = String(repeating: "ab", count: 32)
    private static let pastDate = Date(timeIntervalSince1970: 1_000_000_000)

    /// The error a test hook throws: the process "ends" before the replace.
    private struct Interrupted: Error {}

    // MARK: helpers

    private func sampleID() throws -> ExperienceID { try ExperienceID("a99.contract-sample") }

    private func otherID() throws -> ExperienceID { try ExperienceID("a98.other-sample") }

    private func make(_ id: ExperienceID, step: Int = 240, energy: Int = 3) throws -> ExperienceSnapshot {
        let digest = try #require(StateDigest(hex: Self.digestHex))
        return try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: 7, stepIndex: step, digest: digest,
                                      payload: Data(#"{"energy":\#(energy),"path":"a/b"}"#.utf8))
    }

    /// A new store on its own temporary root; the root itself is not created.
    private func makeStore() -> SavedStateStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedStateStoreTests-" + UUID().uuidString, isDirectory: true)
        return SavedStateStore(root: root)
    }

    private func cleanUp(_ store: SavedStateStore) {
        try? FileManager.default.removeItem(at: store.root)
    }

    /// Writes `data` as the state file of `id`, without the store.
    private func plant(_ data: Data, as id: ExperienceID, in store: SavedStateStore) throws {
        try FileManager.default.createDirectory(at: store.folder(for: id), withIntermediateDirectories: true)
        try data.write(to: store.stateURL(for: id))
    }

    /// The encoded form of a valid snapshot of `id` after `change` edited its fields.
    private func envelope(_ id: ExperienceID, _ change: (inout [String: Any]) -> Void) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: try make(id).encoded())
        var fields = try #require(object as? [String: Any])
        change(&fields)
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    /// The names in the folder of `id`, hidden ones included, sorted.
    private func names(_ id: ExperienceID, in store: SavedStateStore) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: store.folder(for: id).path)) ?? []).sorted()
    }

    private func hiddenNames(_ id: ExperienceID, in store: SavedStateStore) -> [String] {
        names(id, in: store).filter { $0.hasPrefix(".") }
    }

    /// The error `save` throws, or nil when it succeeds.
    private func saveError(_ store: SavedStateStore, _ snapshot: ExperienceSnapshot) -> StorageError? {
        do {
            try store.save(snapshot)
            return nil
        } catch {
            return error
        }
    }

    private func isWriteFailed(_ error: StorageError?) -> Bool {
        if case .writeFailed? = error { return true }
        return false
    }

    private func modificationDate(_ url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.modificationDate] as? Date)
    }

    // MARK: load and save

    @Test func constantsAndPaths() throws {
        let store = makeStore()
        let id = try sampleID()
        #expect(SavedStateStore.stateFileName == "state.json")
        #expect(SavedStateStore.maxQuarantined == 3)
        #expect(SavedStateStore.quarantinePrefix == "quarantine-")
        #expect(SavedStateProblem.unreadableFileCode == "state.unreadable-file")
        #expect(store.folder(for: id).path == store.root.appendingPathComponent("a99.contract-sample").path)
        #expect(store.stateURL(for: id).path == store.folder(for: id).appendingPathComponent("state.json").path)
        // Creating a store and asking for paths creates nothing.
        #expect(!FileManager.default.fileExists(atPath: store.root.path))
    }

    @Test func loadGivesNoneOnAnEmptyRootAndCreatesNothing() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let missingRoot = store.load(id)
        #expect(missingRoot == .none)
        #expect(!FileManager.default.fileExists(atPath: store.root.path))

        try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        let emptyRoot = store.load(id)
        #expect(emptyRoot == .none)
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: id).path))
    }

    @Test func saveThenLoadGivesTheEqualSnapshot() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let snapshot = try make(id)
        let written = try store.save(snapshot)
        #expect(written)
        let loaded = store.load(id)
        #expect(loaded == .state(snapshot))
        let bytes = try Data(contentsOf: store.stateURL(for: id))
        let expected = try snapshot.encoded()
        #expect(bytes == expected)
        #expect(names(id, in: store) == ["state.json"])
    }

    @Test func aSecondSaveOfTheSameSnapshotWritesNothing() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let snapshot = try make(id)
        let first = try store.save(snapshot)
        #expect(first)
        let file = store.stateURL(for: id)
        try FileManager.default.setAttributes([.modificationDate: Self.pastDate], ofItemAtPath: file.path)
        let dateBefore = try modificationDate(file)
        let bytesBefore = try Data(contentsOf: file)

        let second = try store.save(snapshot)
        #expect(!second)
        let dateAfter = try modificationDate(file)
        let bytesAfter = try Data(contentsOf: file)
        #expect(dateBefore == Self.pastDate)
        #expect(dateAfter == Self.pastDate)
        #expect(bytesAfter == bytesBefore)
        #expect(names(id, in: store) == ["state.json"])
    }

    @Test func aChangedSnapshotIsWrittenAndLoaded() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let first = try make(id, step: 240, energy: 3)
        let changed = try make(id, step: 243, energy: 4)
        #expect(first != changed)
        try store.save(first)
        let file = store.stateURL(for: id)
        try FileManager.default.setAttributes([.modificationDate: Self.pastDate], ofItemAtPath: file.path)

        let written = try store.save(changed)
        #expect(written)
        let loaded = store.load(id)
        #expect(loaded == .state(changed))
        let bytes = try Data(contentsOf: file)
        let expected = try changed.encoded()
        #expect(bytes == expected)
        let date = try modificationDate(file)
        #expect(date != Self.pastDate)
        // A good earlier state is replaced, not quarantined, and no temporary file stays.
        #expect(names(id, in: store) == ["state.json"])
    }

    // MARK: unreadable files

    @Test func unreadableFilesAreReportedAndLeftUntouched() throws {
        let id = try sampleID()
        let other = try otherID()
        let valid = try make(id).encoded()
        let table: [(name: String, data: Data, code: String)] = [
            ("cut off", valid.prefix(valid.count / 2), "snapshot.corrupt"),
            ("not JSON", Data("not json".utf8), "snapshot.corrupt"),
            ("wrong checksum", try envelope(id) { $0["checksum"] = String(repeating: "0f", count: 32) },
             "snapshot.checksum-mismatch"),
            ("another experience", try make(other).encoded(), "snapshot.wrong-experience"),
            ("unknown format", try envelope(id) { $0["format"] = 99 }, "snapshot.unknown-format"),
            ("too large", Data(repeating: UInt8(ascii: "x"), count: ExperienceSnapshot.maxBytes + 1),
             "snapshot.too-large"),
            ("empty", Data(), "snapshot.corrupt"),
        ]
        #expect(table.count >= 6)
        for entry in table {
            let store = makeStore()
            defer { cleanUp(store) }
            try plant(entry.data, as: id, in: store)
            let file = store.stateURL(for: id)
            try FileManager.default.setAttributes([.modificationDate: Self.pastDate], ofItemAtPath: file.path)

            let loaded = store.load(id)
            #expect(loaded == .unreadable(SavedStateProblem(code: entry.code, newer: false)), "\(entry.name)")
            guard case .unreadable(let problem) = loaded else {
                Issue.record("\(entry.name) is not reported as unreadable")
                continue
            }
            #expect(problem.code == entry.code, "\(entry.name)")
            #expect(!problem.newer, "\(entry.name)")

            let after = try Data(contentsOf: file)
            #expect(after == entry.data, "\(entry.name)")
            let date = try modificationDate(file)
            #expect(date == Self.pastDate, "\(entry.name)")
            #expect(names(id, in: store) == ["state.json"], "\(entry.name)")
        }
    }

    @Test func aStateThatCannotBeReadFromTheDiskHasItsOwnCode() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        // A folder where the file should be: it exists and cannot be read as a file.
        try FileManager.default.createDirectory(at: store.stateURL(for: id), withIntermediateDirectories: true)
        let loaded = store.load(id)
        #expect(loaded == .unreadable(SavedStateProblem(code: "state.unreadable-file", newer: false)))
        #expect(FileManager.default.fileExists(atPath: store.stateURL(for: id).path))
    }

    @Test func problemsCarryTheCodeAndTheNewerMark() throws {
        let newer = SavedStateProblem(failureCode: "snapshot.newer-schema")
        #expect(newer.code == "snapshot.newer-schema")
        #expect(newer.newer)
        let missing = SavedStateProblem(failureCode: "snapshot.missing-migration")
        #expect(missing.code == "snapshot.missing-migration")
        #expect(!missing.newer)
        let unreadable = SavedStateProblem(failureCode: SavedStateProblem.unreadableFileCode)
        #expect(unreadable.code == "state.unreadable-file")
        #expect(!unreadable.newer)

        let errors: [(SnapshotError, String)] = [
            (.wrongExperience(found: "a98.other-sample"), "snapshot.wrong-experience"),
            (.unknownFormat(99), "snapshot.unknown-format"),
            (.newerSchema(found: 3, current: 2), "snapshot.newer-schema"),
            (.missingMigration(from: 1), "snapshot.missing-migration"),
            (.corrupt(reason: "not JSON"), "snapshot.corrupt"),
            (.checksumMismatch, "snapshot.checksum-mismatch"),
            (.tooLarge(bytes: 1_048_577), "snapshot.too-large"),
            (.stateMismatch(expected: "a", found: "b"), "snapshot.state-mismatch"),
        ]
        for (error, code) in errors {
            let problem = SavedStateProblem(error: error)
            #expect(problem.code == code)
            #expect(problem.code == error.code)
            #expect(problem.newer == (code == "snapshot.newer-schema"))
            #expect(problem == SavedStateProblem(failureCode: code))
        }
        #expect(SavedStateProblem(code: "x", newer: true) != SavedStateProblem(code: "x", newer: false))
    }

    // MARK: quarantine

    @Test func saveOverAnUnreadableFileQuarantinesItFirst() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let unreadable = Data("not json".utf8)
        try plant(unreadable, as: id, in: store)
        let snapshot = try make(id)

        let written = try store.save(snapshot)
        #expect(written)
        #expect(store.quarantined(id) == ["quarantine-1.json"])
        let copy = try Data(contentsOf: store.folder(for: id).appendingPathComponent("quarantine-1.json"))
        #expect(copy == unreadable)
        let loaded = store.load(id)
        #expect(loaded == .state(snapshot))
        #expect(names(id, in: store) == ["quarantine-1.json", "state.json"])
    }

    @Test func saveOverAnotherExperiencesStateQuarantinesItFirst() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let foreign = try make(try otherID()).encoded()
        try plant(foreign, as: id, in: store)
        let snapshot = try make(id)
        try store.save(snapshot)
        #expect(store.quarantined(id) == ["quarantine-1.json"])
        let copy = try Data(contentsOf: store.folder(for: id).appendingPathComponent("quarantine-1.json"))
        #expect(copy == foreign)
        let loaded = store.load(id)
        #expect(loaded == .state(snapshot))
    }

    @Test func fiveQuarantinesInARowKeepTheLastThree() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let nothing = try store.quarantine(id)
        #expect(nothing == nil)
        #expect(store.quarantined(id) == [])
        #expect(!FileManager.default.fileExists(atPath: store.root.path))

        var returned: [String] = []
        for round in 1...5 {
            let bytes = Data("unreadable \(round)".utf8)
            try plant(bytes, as: id, in: store)
            let name = try store.quarantine(id)
            let given = try #require(name)
            returned.append(given)
            #expect(given == "quarantine-\(round).json")
            let copies = store.quarantined(id)
            #expect(copies.count <= SavedStateStore.maxQuarantined)
            #expect(copies.last == given)
            let copy = try Data(contentsOf: store.folder(for: id).appendingPathComponent(given))
            #expect(copy == bytes)
            #expect(!FileManager.default.fileExists(atPath: store.stateURL(for: id).path))
            let loaded = store.load(id)
            #expect(loaded == .none)
            if round == 3 {
                #expect(copies == ["quarantine-1.json", "quarantine-2.json", "quarantine-3.json"])
            }
            if round == 4 {
                #expect(copies == ["quarantine-2.json", "quarantine-3.json", "quarantine-4.json"])
            }
        }
        #expect(returned == (1...5).map { "quarantine-\($0).json" })
        #expect(store.quarantined(id) == ["quarantine-3.json", "quarantine-4.json", "quarantine-5.json"])
        #expect(names(id, in: store) == ["quarantine-3.json", "quarantine-4.json", "quarantine-5.json"])
        let last = try Data(contentsOf: store.folder(for: id).appendingPathComponent("quarantine-5.json"))
        #expect(last == Data("unreadable 5".utf8))

        let again = try store.quarantine(id)
        #expect(again == nil)
    }

    @Test func quarantinedCopiesOrderByNumberNotByText() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let folder = store.folder(for: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["quarantine-10.json", "quarantine-9.json", "quarantine-x.json", "quarantine-.json",
                     "quarantine-07.json", "quarantine-0.json", "quarantine-8.txt", "notes.json"] {
            try Data(name.utf8).write(to: folder.appendingPathComponent(name))
        }
        #expect(store.quarantined(id) == ["quarantine-9.json", "quarantine-10.json"])

        try plant(Data("not json".utf8), as: id, in: store)
        let name = try store.quarantine(id)
        #expect(name == "quarantine-11.json")
        #expect(store.quarantined(id) == ["quarantine-9.json", "quarantine-10.json", "quarantine-11.json"])

        try plant(Data("not json either".utf8), as: id, in: store)
        let next = try store.quarantine(id)
        #expect(next == "quarantine-12.json")
        #expect(store.quarantined(id) == ["quarantine-10.json", "quarantine-11.json", "quarantine-12.json"])
        // Files that are not quarantined copies are never removed.
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("notes.json").path))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("quarantine-x.json").path))
    }

    // MARK: interrupted saves

    @Test func aSaveInterruptedBeforeTheReplaceLeavesTheEarlierStateAndOneLeftover() throws {
        var store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let stateA = try make(id, step: 10, energy: 1)
        let stateB = try make(id, step: 20, energy: 2)
        try store.save(stateA)

        store.beforeReplace = { throw Interrupted() }
        store.leaveTemporaryFileOnFailure = true
        let error = saveError(store, stateB)
        #expect(isWriteFailed(error))

        let afterFailure = store.load(id)
        #expect(afterFailure == .state(stateA))
        let bytes = try Data(contentsOf: store.stateURL(for: id))
        let expected = try stateA.encoded()
        #expect(bytes == expected)
        let hidden = hiddenNames(id, in: store)
        #expect(hidden.count == 1)
        #expect(hidden.allSatisfy { $0.hasPrefix(".state.json.tmp-") })

        let removed = store.removeLeftovers()
        #expect(removed == 1)
        #expect(hiddenNames(id, in: store).isEmpty)
        #expect(names(id, in: store) == ["state.json"])
        let afterCleaning = store.load(id)
        #expect(afterCleaning == .state(stateA))
        let secondPass = store.removeLeftovers()
        #expect(secondPass == 0)

        // Without the hook the same save goes through.
        store.beforeReplace = nil
        let written = try store.save(stateB)
        #expect(written)
        let final = store.load(id)
        #expect(final == .state(stateB))
        #expect(names(id, in: store) == ["state.json"])
    }

    @Test func aFailedSaveLeavesNoTemporaryFileWithoutTheFlag() throws {
        var store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let stateA = try make(id, step: 10, energy: 1)
        let stateB = try make(id, step: 20, energy: 2)
        try store.save(stateA)

        store.beforeReplace = { throw Interrupted() }
        let error = saveError(store, stateB)
        #expect(isWriteFailed(error))
        #expect(hiddenNames(id, in: store).isEmpty)
        #expect(names(id, in: store) == ["state.json"])
        let loaded = store.load(id)
        #expect(loaded == .state(stateA))
        let removed = store.removeLeftovers()
        #expect(removed == 0)
    }

    @Test func aFirstSaveInterruptedBeforeTheReplaceLeavesNoState() throws {
        var store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        store.beforeReplace = { throw Interrupted() }
        store.leaveTemporaryFileOnFailure = true
        let error = saveError(store, try make(id))
        #expect(isWriteFailed(error))
        let loaded = store.load(id)
        #expect(loaded == .none)
        #expect(hiddenNames(id, in: store).count == 1)
        let removed = store.removeLeftovers()
        #expect(removed == 1)
        #expect(names(id, in: store).isEmpty)
    }

    @Test func aTemporaryFileThatWasNeverCompletedIsRemovedAndNeverRead() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        let other = try otherID()
        let stateA = try make(id)
        try store.save(stateA)
        // The write ended before the temporary file was complete: an empty hidden file next to the state.
        let incomplete = store.folder(for: id).appendingPathComponent(".state.json.tmp-x")
        try Data().write(to: incomplete)
        // A leftover in a folder that has no state at all, and files that are not leftovers.
        try FileManager.default.createDirectory(at: store.folder(for: other), withIntermediateDirectories: true)
        try Data("half".utf8).write(to: store.folder(for: other).appendingPathComponent(".state.json.tmp-y"))
        try Data("keep".utf8).write(to: store.folder(for: other).appendingPathComponent(".hidden"))
        try Data("keep".utf8).write(to: store.folder(for: other).appendingPathComponent("visible.tmp-z"))
        try Data("keep".utf8).write(to: store.root.appendingPathComponent(".root.tmp-w"))

        let beforeCleaning = store.load(id)
        #expect(beforeCleaning == .state(stateA))
        let otherBefore = store.load(other)
        #expect(otherBefore == .none)

        let removed = store.removeLeftovers()
        #expect(removed == 2)
        #expect(names(id, in: store) == ["state.json"])
        #expect(names(other, in: store) == [".hidden", "visible.tmp-z"])
        #expect(FileManager.default.fileExists(atPath: store.root.appendingPathComponent(".root.tmp-w").path))
        let afterCleaning = store.load(id)
        #expect(afterCleaning == .state(stateA))
    }

    @Test func removeLeftoversWithoutARootGivesZero() throws {
        let store = makeStore()
        let removed = store.removeLeftovers()
        #expect(removed == 0)
        #expect(!FileManager.default.fileExists(atPath: store.root.path))
    }

    // MARK: remove and isolation

    @Test func removeRemovesOnlyTheState() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let id = try sampleID()
        // Nothing stored: no error and nothing created.
        try store.remove(id)
        #expect(!FileManager.default.fileExists(atPath: store.root.path))

        try plant(Data("not json".utf8), as: id, in: store)
        try store.quarantine(id)
        try store.save(try make(id))
        try Data("mine".utf8).write(to: store.folder(for: id).appendingPathComponent("notes.txt"))
        #expect(names(id, in: store) == ["notes.txt", "quarantine-1.json", "state.json"])

        try store.remove(id)
        #expect(names(id, in: store) == ["notes.txt", "quarantine-1.json"])
        let loaded = store.load(id)
        #expect(loaded == .none)
        try store.remove(id)
        #expect(names(id, in: store) == ["notes.txt", "quarantine-1.json"])
    }

    @Test func twoExperiencesDoNotSeeEachOthersState() throws {
        let store = makeStore()
        defer { cleanUp(store) }
        let first = try sampleID()
        let second = try otherID()
        let firstState = try make(first, step: 5, energy: 1)
        try store.save(firstState)
        let secondBefore = store.load(second)
        #expect(secondBefore == .none)

        let secondState = try make(second, step: 9, energy: 2)
        try store.save(secondState)
        let firstLoaded = store.load(first)
        let secondLoaded = store.load(second)
        #expect(firstLoaded == .state(firstState))
        #expect(secondLoaded == .state(secondState))
        #expect(store.folder(for: first).path != store.folder(for: second).path)

        try plant(Data("not json".utf8), as: second, in: store)
        try store.quarantine(second)
        #expect(store.quarantined(first) == [])
        #expect(store.quarantined(second) == ["quarantine-1.json"])
        try store.remove(second)
        let firstAfter = store.load(first)
        #expect(firstAfter == .state(firstState))
    }
}
