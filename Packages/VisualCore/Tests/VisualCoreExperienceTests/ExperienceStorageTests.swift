// ExperienceStorageTests — feature 191 T-U05-002 (UA-F05; FR-U05-001 to FR-U05-005; SC-U05-001; contract
// specs/191-ua-f05-session-persistence/contracts/persistence-api.md, behaviour contracts 1 and 2): the storage
// handle of one experience — isolation of two handles, the 20 escaping names, the listing, the bounds, an
// interrupted write, missing files, the removal of values and the stable error codes.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct ExperienceStorageTests {
    /// One temporary root folder and one defaults suite of a test; `cleanUp()` removes both.
    private struct Place {
        let root: URL
        let suite: String
        let defaults: UserDefaults

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
    }

    private struct Crash: Error {}

    private func makePlace() throws -> Place {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vc-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "vc.tests.storage." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        return Place(root: root, suite: suite, defaults: defaults)
    }

    private func firstID() throws -> ExperienceID { try ExperienceID("a01.generative-art-studio") }
    private func secondID() throws -> ExperienceID { try ExperienceID("a02.fluid-art-playground") }

    private func handle(_ id: ExperienceID, _ place: Place) -> ExperienceStorage {
        ExperienceStorage(id: id, root: place.root, defaults: place.defaults)
    }

    private func writeError(_ storage: ExperienceStorage, _ data: Data, _ name: String) -> StorageError? {
        do { try storage.write(data, to: name); return nil } catch { return error }
    }

    private func readError(_ storage: ExperienceStorage, _ name: String) -> StorageError? {
        do { _ = try storage.read(name); return nil } catch { return error }
    }

    private func removeError(_ storage: ExperienceStorage, _ name: String) -> StorageError? {
        do { try storage.remove(name); return nil } catch { return error }
    }

    private func setValueError(_ storage: ExperienceStorage, _ data: Data, _ key: String) -> StorageError? {
        do { try storage.setValue(data, for: key); return nil } catch { return error }
    }

    /// Every item below `root` (hidden ones included) as a relative path, sorted.
    private func tree(_ root: URL) -> [String] {
        guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [] }
        var paths: [String] = []
        while let path = walker.nextObject() as? String { paths.append(path) }
        return paths.sorted()
    }

    private func hiddenNames(in folder: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasPrefix(".") }.sorted()
    }

    // MARK: Isolation

    @Test func twoHandlesSeeOnlyTheirOwnFilesAndValues() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let first = handle(try firstID(), place), second = handle(try secondID(), place)

        try first.write(Data("one".utf8), to: "first.bin")
        try first.setValue(Data("v1".utf8), for: "first-key")
        try second.write(Data("two".utf8), to: "second.bin")
        try second.setValue(Data("v2".utf8), for: "second-key")

        #expect(first.list() == ["first.bin"])
        #expect(second.list() == ["second.bin"])
        let firstData = try first.read("first.bin"), secondData = try second.read("second.bin")
        #expect(firstData == Data("one".utf8))
        #expect(secondData == Data("two".utf8))
        #expect(readError(first, "second.bin") == .notFound("second.bin"))
        #expect(readError(second, "first.bin") == .notFound("first.bin"))
        #expect(first.exists("first.bin") && !first.exists("second.bin"))
        #expect(second.exists("second.bin") && !second.exists("first.bin"))

        #expect(first.valueKeys() == ["first-key"])
        #expect(second.valueKeys() == ["second-key"])
        #expect(first.value(for: "first-key") == Data("v1".utf8))
        #expect(second.value(for: "second-key") == Data("v2".utf8))
        #expect(first.value(for: "second-key") == nil)
        #expect(second.value(for: "first-key") == nil)

        // The same name in both namespaces holds two independent contents.
        try first.write(Data("mine".utf8), to: "shared.bin")
        try second.write(Data("yours".utf8), to: "shared.bin")
        try first.setValue(Data("a".utf8), for: "shared")
        try second.setValue(Data("b".utf8), for: "shared")
        let mine = try first.read("shared.bin"), yours = try second.read("shared.bin")
        #expect(mine == Data("mine".utf8))
        #expect(yours == Data("yours".utf8))
        #expect(first.value(for: "shared") == Data("a".utf8))
        #expect(second.value(for: "shared") == Data("b".utf8))

        #expect(first.folder.lastPathComponent == "a01.generative-art-studio")
        #expect(tree(place.root) == [
            "a01.generative-art-studio", "a01.generative-art-studio/first.bin", "a01.generative-art-studio/shared.bin",
            "a02.fluid-art-playground", "a02.fluid-art-playground/second.bin", "a02.fluid-art-playground/shared.bin",
        ])
    }

    @Test func theInitializerCreatesNothing() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        #expect(tree(place.root).isEmpty)
        #expect(storage.list().isEmpty)
        #expect(storage.valueKeys().isEmpty)
        #expect(tree(place.root).isEmpty)
    }

    // MARK: Names

    @Test func theTwentyEscapingNamesAreRefusedAndChangeNothing() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place), other = handle(try secondID(), place)
        try other.write(Data("theirs".utf8), to: "x")
        try other.setValue(Data("theirs".utf8), for: "x")

        let table: [(name: String, reserved: Bool)] = [
            ("..", false), ("../x", false), ("a/b", false), ("/abs", false), ("a\\b", false),
            ("", false), (String(repeating: "a", count: 129), false), (".hidden", false), ("a b", false),
            ("a:b", false), ("state.json", true), ("quarantine-1.json", true),
            ("../a02.fluid-art-playground/x", false), ("a%2Fb", false), ("a\nb", false), ("a\u{0}b", false),
            ("~/x", false), (".", false), ("dir/", false), ("a\u{2215}b", false),
        ]
        #expect(table.count == 20)

        let before = tree(place.root)
        let payload = Data("escape".utf8)
        for entry in table {
            let expected: StorageError = entry.reserved ? .reservedName(entry.name) : .invalidName(entry.name)
            #expect(writeError(storage, payload, entry.name) == expected, "write \(entry.name.debugDescription)")
            #expect(readError(storage, entry.name) == expected, "read \(entry.name.debugDescription)")
            #expect(removeError(storage, entry.name) == expected, "remove \(entry.name.debugDescription)")
            #expect(!storage.exists(entry.name), "exists \(entry.name.debugDescription)")
            #expect(ExperienceStorage.isValidName(entry.name) == entry.reserved)
            #expect(ExperienceStorage.isReservedName(entry.name) == entry.reserved)
            if !entry.reserved {
                // The two reserved file names are valid keys; every other entry is refused as a key too.
                #expect(setValueError(storage, payload, entry.name) == .invalidName(entry.name),
                        "setValue \(entry.name.debugDescription)")
                #expect(storage.value(for: entry.name) == nil)
                storage.removeValue(for: entry.name)
            }
        }

        // Nothing new anywhere below the root, nothing in the handle's own folder, no value, the neighbour intact.
        #expect(tree(place.root) == before)
        #expect(before == ["a02.fluid-art-playground", "a02.fluid-art-playground/x"])
        #expect(!FileManager.default.fileExists(atPath: storage.folder.path))
        #expect(storage.list().isEmpty)
        #expect(storage.valueKeys().isEmpty)
        let theirs = try other.read("x")
        #expect(theirs == Data("theirs".utf8))
        #expect(other.value(for: "x") == Data("theirs".utf8))
        #expect(other.valueKeys() == ["x"])
    }

    /// On a volume that ignores case `State.json` names the saved state: it is refused like `state.json`, and
    /// the saved state placed in the folder stays as it is.
    @Test func reservedNamesAreRefusedInAnyCase() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        try FileManager.default.createDirectory(at: storage.folder, withIntermediateDirectories: true)
        let state = storage.folder.appendingPathComponent("state.json")
        try Data("the saved state".utf8).write(to: state)
        for name in ["State.json", "STATE.JSON", "Quarantine-1.json", "QUARANTINE-22.JSON"] {
            #expect(writeError(storage, Data("x".utf8), name) == .reservedName(name))
            #expect(readError(storage, name) == .reservedName(name))
            #expect(removeError(storage, name) == .reservedName(name))
            #expect(!storage.exists(name))
        }
        let kept = try Data(contentsOf: state)
        #expect(kept == Data("the saved state".utf8))
        #expect(storage.list() == [])
    }

    @Test func nameRulesAtTheirEdges() {
        #expect(ExperienceStorage.isValidName(String(repeating: "a", count: 128)))
        #expect(ExperienceStorage.isValidName("A-z_0.9"))
        #expect(ExperienceStorage.isValidName("a.json"))
        #expect(!ExperienceStorage.isValidName("\u{430}"))  // a Cyrillic letter that looks like `a`
        #expect(!ExperienceStorage.isValidName("e\u{301}"))
        #expect(ExperienceStorage.isReservedName("state.json"))
        #expect(ExperienceStorage.isReservedName("quarantine-0.json"))
        #expect(ExperienceStorage.isReservedName("quarantine-123.json"))
        #expect(!ExperienceStorage.isReservedName("quarantine-.json"))
        #expect(!ExperienceStorage.isReservedName("quarantine-1a.json"))
        #expect(!ExperienceStorage.isReservedName("quarantine-1.txt"))
        // Case does not matter: on a volume that ignores case these are the files of the saved state.
        #expect(ExperienceStorage.isReservedName("State.json"))
        #expect(ExperienceStorage.isReservedName("STATE.JSON"))
        #expect(ExperienceStorage.isReservedName("Quarantine-2.JSON"))
        #expect(StorageQuota.maxNameLength == 128)
    }

    @Test func reservedFileNamesAreValidKeys() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        try storage.setValue(Data("s".utf8), for: "state.json")
        try storage.setValue(Data("q".utf8), for: "quarantine-1.json")
        #expect(storage.valueKeys() == ["quarantine-1.json", "state.json"])
        #expect(storage.value(for: "state.json") == Data("s".utf8))
        #expect(tree(place.root).isEmpty)
    }

    // MARK: Listing

    @Test func listHidesReservedAndHiddenFiles() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        try storage.write(Data("b".utf8), to: "b.bin")
        try storage.write(Data("a".utf8), to: "a.bin")
        try storage.write(Data("c".utf8), to: "C_3-x.dat")
        try Data("{}".utf8).write(to: storage.folder.appendingPathComponent("state.json"))
        try Data("{}".utf8).write(to: storage.folder.appendingPathComponent("quarantine-2.json"))
        try Data("partial".utf8).write(to: storage.folder.appendingPathComponent(".a.bin.tmp-ABC"))
        try FileManager.default.createDirectory(at: storage.folder.appendingPathComponent("subfolder"),
                                                withIntermediateDirectories: false)

        #expect(storage.list() == ["C_3-x.dat", "a.bin", "b.bin"])
        #expect(!storage.exists("state.json"))
        #expect(!storage.exists("quarantine-2.json"))
        #expect(!storage.exists(".a.bin.tmp-ABC"))
        #expect(!storage.exists("subfolder"))
        #expect(readError(storage, "state.json") == .reservedName("state.json"))
    }

    // MARK: Bounds

    @Test func fileCountBound() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        #expect(StorageQuota.maxFiles == 64)
        for index in 0..<64 { try storage.write(Data("\(index)".utf8), to: "file-\(index).bin") }
        #expect(storage.list().count == 64)

        #expect(writeError(storage, Data("x".utf8), "file-64.bin") == .quotaExceeded("files"))
        #expect(!storage.exists("file-64.bin"))
        #expect(storage.list().count == 64)

        try storage.write(Data("again".utf8), to: "file-7.bin")
        let rewritten = try storage.read("file-7.bin"), untouched = try storage.read("file-8.bin")
        #expect(rewritten == Data("again".utf8))
        #expect(untouched == Data("8".utf8))
        #expect(hiddenNames(in: storage.folder).isEmpty)

        try storage.remove("file-0.bin")
        try storage.write(Data("x".utf8), to: "file-64.bin")
        #expect(storage.list().count == 64)
    }

    @Test func byteBound() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        let mebibyte = 1024 * 1024
        #expect(StorageQuota.maxBytes == 16 * mebibyte)

        // A single file above the bound is refused before anything is created.
        #expect(writeError(storage, Data(count: 16 * mebibyte + 1), "huge.bin") == .tooLarge(16 * mebibyte + 1))
        #expect(tree(place.root).isEmpty)

        // The saved state does not count: it is placed directly, as the app writes it.
        try FileManager.default.createDirectory(at: storage.folder, withIntermediateDirectories: true)
        try Data(count: mebibyte).write(to: storage.folder.appendingPathComponent("state.json"))
        try Data(count: mebibyte).write(to: storage.folder.appendingPathComponent("quarantine-1.json"))

        for name in ["a.bin", "b.bin", "c.bin"] { try storage.write(Data(count: 5 * mebibyte), to: name) }
        try storage.write(Data(count: mebibyte), to: "d.bin")  // 16 MiB exactly
        #expect(storage.list() == ["a.bin", "b.bin", "c.bin", "d.bin"])

        #expect(writeError(storage, Data(count: 1), "e.bin") == .quotaExceeded("bytes"))
        #expect(!storage.exists("e.bin"))
        // Growing an existing file by one byte is refused too and leaves the earlier content.
        #expect(writeError(storage, Data(count: mebibyte + 1), "d.bin") == .quotaExceeded("bytes"))
        #expect(storage.list() == ["a.bin", "b.bin", "c.bin", "d.bin"])
        let a = try storage.read("a.bin"), d = try storage.read("d.bin")
        #expect(a == Data(count: 5 * mebibyte))
        #expect(d == Data(count: mebibyte))
        #expect(hiddenNames(in: storage.folder).isEmpty)

        // Replacing a file by a smaller one makes room.
        try storage.write(Data(count: mebibyte - 1), to: "d.bin")
        try storage.write(Data(count: 1), to: "e.bin")
        #expect(writeError(storage, Data(count: 1), "f.bin") == .quotaExceeded("bytes"))
    }

    @Test func valueBounds() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place), other = handle(try secondID(), place)
        #expect(StorageQuota.maxValues == 64)
        #expect(StorageQuota.maxValueBytes == 4_096)

        #expect(setValueError(storage, Data(count: 4_097), "big") == .tooLarge(4_097))
        #expect(storage.value(for: "big") == nil)
        try storage.setValue(Data(count: 4_096), for: "big")
        #expect(storage.value(for: "big") == Data(count: 4_096))
        storage.removeValue(for: "big")
        #expect(storage.value(for: "big") == nil)
        storage.removeValue(for: "big")  // no error without the value

        for index in 0..<64 { try storage.setValue(Data("\(index)".utf8), for: "key-\(index)") }
        #expect(storage.valueKeys().count == 64)
        #expect(setValueError(storage, Data("x".utf8), "key-64") == .quotaExceeded("values"))
        #expect(storage.value(for: "key-64") == nil)
        try storage.setValue(Data("again".utf8), for: "key-7")
        #expect(storage.value(for: "key-7") == Data("again".utf8))
        #expect(storage.value(for: "key-8") == Data("8".utf8))
        #expect(storage.valueKeys().count == 64)

        // The bound is per experience.
        try other.setValue(Data("x".utf8), for: "key-64")
        #expect(other.valueKeys() == ["key-64"])
    }

    // MARK: Atomic writes

    @Test func interruptedWriteKeepsTheEarlierFileAndOneTemporaryFile() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        var storage = handle(try firstID(), place)
        try storage.write(Data("old".utf8), to: "note.txt")

        storage.beforeReplace = { throw Crash() }
        storage.leaveTemporaryFileOnFailure = true
        let failure = writeError(storage, Data("new".utf8), "note.txt")
        guard case .writeFailed = failure else {
            Issue.record("expected .writeFailed, got \(String(describing: failure))")
            return
        }
        #expect(failure?.code == "storage.write-failed")
        let kept = try storage.read("note.txt")
        #expect(kept == Data("old".utf8))
        let hidden = hiddenNames(in: storage.folder)
        #expect(hidden.count == 1)
        #expect(hidden.first?.hasPrefix(".note.txt.tmp-") == true)
        #expect(storage.list() == ["note.txt"])

        // A later write goes through; the leftover stays hidden until the saved-state store removes it.
        storage.beforeReplace = nil
        try storage.write(Data("new".utf8), to: "note.txt")
        let replaced = try storage.read("note.txt")
        #expect(replaced == Data("new".utf8))
        #expect(storage.list() == ["note.txt"])
        #expect(hiddenNames(in: storage.folder) == hidden)
    }

    @Test func failedWriteRemovesItsTemporaryFileByDefault() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        var storage = handle(try firstID(), place)
        try storage.write(Data("old".utf8), to: "note.txt")

        storage.beforeReplace = { throw Crash() }
        #expect(!storage.leaveTemporaryFileOnFailure)
        let replaceFailure = writeError(storage, Data("new".utf8), "note.txt")
        let createFailure = writeError(storage, Data("new".utf8), "fresh.txt")
        #expect(replaceFailure?.code == "storage.write-failed")
        #expect(createFailure?.code == "storage.write-failed")
        let kept = try storage.read("note.txt")
        #expect(kept == Data("old".utf8))
        #expect(hiddenNames(in: storage.folder).isEmpty)
        #expect(storage.list() == ["note.txt"])
    }

    // MARK: Missing files

    @Test func missingFilesAreNotFound() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        // Without the folder.
        #expect(readError(storage, "none.bin") == .notFound("none.bin"))
        #expect(removeError(storage, "none.bin") == .notFound("none.bin"))
        #expect(!storage.exists("none.bin"))
        #expect(tree(place.root).isEmpty)

        // With the folder.
        try storage.write(Data("x".utf8), to: "here.bin")
        #expect(readError(storage, "none.bin") == .notFound("none.bin"))
        #expect(removeError(storage, "none.bin") == .notFound("none.bin"))
        #expect(storage.exists("here.bin"))
        try storage.remove("here.bin")
        #expect(!storage.exists("here.bin"))
        #expect(storage.list().isEmpty)
        #expect(readError(storage, "here.bin") == .notFound("here.bin"))
        #expect(removeError(storage, "here.bin") == .notFound("here.bin"))
    }

    // MARK: Removal of values

    @Test func removeValuesRemovesExactlyOneExperience() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let idOne = try firstID(), idTwo = try secondID()
        let first = handle(idOne, place), second = handle(idTwo, place)
        try first.setValue(Data("1".utf8), for: "beta")
        try first.setValue(Data("2".utf8), for: "alpha")
        try second.setValue(Data("3".utf8), for: "alpha")
        place.defaults.set(Data("shell".utf8), forKey: "vc.shell.preferences")

        let removed = ExperienceStorage.removeValues(of: idOne, in: place.defaults)
        #expect(removed == ["exp.a01.generative-art-studio.alpha", "exp.a01.generative-art-studio.beta"])
        #expect(first.valueKeys().isEmpty)
        #expect(first.value(for: "alpha") == nil)
        #expect(second.valueKeys() == ["alpha"])
        #expect(second.value(for: "alpha") == Data("3".utf8))
        #expect(place.defaults.data(forKey: "vc.shell.preferences") == Data("shell".utf8))

        let again = ExperienceStorage.removeValues(of: idOne, in: place.defaults)
        #expect(again.isEmpty)
    }

    @Test func removeAllValuesRemovesEveryExperienceKeyAndNothingElse() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let first = handle(try firstID(), place), second = handle(try secondID(), place)
        try first.setValue(Data("1".utf8), for: "alpha")
        try second.setValue(Data("2".utf8), for: "alpha")
        try second.setValue(Data("3".utf8), for: "beta")
        place.defaults.set(Data("shell".utf8), forKey: "vc.shell.preferences")
        place.defaults.set("kept", forKey: "experience.not-a-value")

        let removed = ExperienceStorage.removeAllValues(in: place.defaults)
        #expect(removed == [
            "exp.a01.generative-art-studio.alpha", "exp.a02.fluid-art-playground.alpha",
            "exp.a02.fluid-art-playground.beta",
        ])
        #expect(first.valueKeys().isEmpty)
        #expect(second.valueKeys().isEmpty)
        #expect(place.defaults.data(forKey: "vc.shell.preferences") == Data("shell".utf8))
        #expect(place.defaults.string(forKey: "experience.not-a-value") == "kept")
    }

    @Test func aStoredObjectThatIsNotDataIsNoValue() throws {
        let place = try makePlace()
        defer { place.cleanUp() }
        let storage = handle(try firstID(), place)
        place.defaults.set("text", forKey: "exp.a01.generative-art-studio.stray")
        #expect(storage.value(for: "stray") == nil)
        #expect(storage.valueKeys() == ["stray"])
    }

    // MARK: Texts

    @Test func defaultsPrefixText() throws {
        #expect(ExperienceStorage.defaultsPrefix(for: try firstID()) == "exp.a01.generative-art-studio.")
        #expect(ExperienceStorage.defaultsPrefix(for: try secondID()) == "exp.a02.fluid-art-playground.")
    }

    @Test func everyErrorHasItsStableCode() {
        let table: [(error: StorageError, code: String)] = [
            (.invalidName("a/b"), "storage.invalid-name"),
            (.reservedName("state.json"), "storage.reserved-name"),
            (.quotaExceeded("files"), "storage.quota-exceeded"),
            (.notFound("x"), "storage.not-found"),
            (.writeFailed("disk"), "storage.write-failed"),
            (.tooLarge(5), "storage.too-large"),
        ]
        #expect(table.count == 6)
        for entry in table { #expect(entry.error.code == entry.code) }
        #expect(StorageError.quotaExceeded("files") != StorageError.quotaExceeded("bytes"))
    }
}
