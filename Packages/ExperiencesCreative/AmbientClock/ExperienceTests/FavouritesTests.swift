// FavouritesTests — feature 133 (A18-P03) T-A18-306 (FR-A18-304, FR-A18-305; SC-A18-304; G-FAVOURITES; clarification
// Q4; contracts/themes.md "Favourites"). The saved theme presets of Ambient Clock (`AmbientFavourites`, the file
// `favourites.json` in the experience's `ExperienceStorage`) over a temporary folder and a private defaults suite,
// with a fixed clock and deterministic ids (synthetic UUIDs `00000000-0000-4000-8000-…`): save, reopen with a new
// library over the same storage (the same entries) and apply (the four theme actions reach the core); a 13th
// favourite is refused as `over-cap`, a name in use (without regard to case) as `duplicate-name`; an empty name
// becomes "Favourite N"; names are trimmed and cut to 60 characters; a damaged file gives an empty list and the
// problem `damaged` and is kept byte for byte until a save replaces it; a newer schema gives `newer-version`, a file
// above 65,536 bytes `too-large` and an invalid entry `invalid-entry`; removing the last favourite removes the file.
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Synthetic ids `00000000-0000-4000-8000-<n as 12 digits>`, one per call, starting at 1.
@MainActor
private final class SyntheticIDs {
    private var next = 1

    /// The id with number `n`.
    static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))!
    }

    /// The next id.
    func make() -> UUID {
        defer { next += 1 }
        return Self.id(next)
    }
}

/// A storage over a fresh temporary folder and a private defaults suite; `cleanUp()` removes both.
@MainActor
private struct FavouritesFixture {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let storage: ExperienceStorage
    let clock = FixedClock(AmbientFixtures.instant)
    let ids = SyntheticIDs()

    init(_ name: String) throws {
        suite = "a18.favourites-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: AmbientTest.id, root: root, defaults: defaults)
    }

    /// A library over the storage with the fixed clock and the synthetic ids.
    func library() -> AmbientFavourites {
        let ids = self.ids
        return AmbientFavourites(storage: storage, clock: clock, makeID: { ids.make() })
    }

    /// Removes the folder and the defaults suite.
    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suite)
    }
}

/// A preset that the tests know is valid.
private func preset(_ theme: Int, _ palette: Int, _ speed: Double, _ motion: Bool) throws -> ThemePreset {
    try ThemePreset(theme: theme, palette: palette, speed: speed, motion: motion)
}

@MainActor
@Suite(.serialized) struct FavouritesTests {
    @Test func aSavedFavouriteIsReadAgainAndApplyRestoresItsPreset() async throws {
        let fixture = try FavouritesFixture("reopen")
        defer { fixture.cleanUp() }
        let library = fixture.library()
        #expect(library.entries.isEmpty && library.problems.isEmpty)
        #expect(!fixture.storage.exists(AmbientFavourites.fileName))
        let shapes = try preset(3, 2, 0.5, false)
        let saved = library.save(name: "  Night shapes  ", preset: shapes)
        let entry = try saved.get()
        #expect(entry.id == SyntheticIDs.id(1))
        #expect(entry.name == "Night shapes")
        #expect(entry.createdAt == AmbientFixtures.instant.timeIntervalSince1970)
        #expect(entry.preset == shapes)
        #expect(library.lastRefusal == nil)
        let waves = try preset(2, 1, 1.75, true)
        let second = library.save(name: "Waves", preset: waves)
        #expect(second.isSuccess)
        #expect(fixture.storage.exists(AmbientFavourites.fileName))
        // The file is the envelope, kind a18.favourites, schema 1.
        let data = try fixture.storage.read(AmbientFavourites.fileName)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["kind"] as? String == "a18.favourites")
        #expect(object["schemaVersion"] as? Int == 1)
        #expect((object["entries"] as? [Any])?.count == 2)
        // A new library over the same storage reads the same entries.
        let reopened = fixture.library()
        #expect(reopened.entries == library.entries)
        #expect(reopened.problems.isEmpty)
        // Applying sends the four theme actions; the core then holds the preset.
        let shell = try await AmbientTest.shell(clock: fixture.clock)
        let results = reopened.apply(id: entry.id, port: shell.port)
        #expect(results == [.accepted, .accepted, .accepted, .accepted])
        let core = try AmbientTest.core(shell)
        #expect(core.theme == 3 && core.palette == 2 && core.speed == 0.5 && !core.motion)
        let other = reopened.apply(id: SyntheticIDs.id(2), port: shell.port)
        #expect(other.count == 4)
        let after = try AmbientTest.core(shell)
        #expect(after.theme == 2 && after.palette == 1 && after.speed == 1.75 && after.motion)
        let none = reopened.apply(id: SyntheticIDs.id(99), port: shell.port)
        #expect(none.isEmpty)
    }

    @Test func aThirteenthFavouriteIsRefusedAsOverCap() throws {
        let fixture = try FavouritesFixture("cap")
        defer { fixture.cleanUp() }
        let library = fixture.library()
        let standard = ThemePreset.standard
        for n in 1...AmbientFavourites.cap {
            let saved = library.save(name: "F\(n)", preset: standard)
            #expect(saved.isSuccess, "favourite \(n)")
        }
        #expect(library.entries.count == 12)
        let before = try fixture.storage.read(AmbientFavourites.fileName)
        let refused = library.save(name: "F13", preset: standard)
        #expect(refused == .failure(.overCap))
        #expect(library.lastRefusal?.code == "over-cap")
        #expect(library.entries.count == 12)
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == before, "a refusal writes nothing")
        // The cap is checked before the name.
        let duplicateAtCap = library.save(name: "F1", preset: standard)
        #expect(duplicateAtCap == .failure(.overCap))
    }

    @Test func aNameInUseIsRefusedWithoutRegardToCase() throws {
        let fixture = try FavouritesFixture("duplicate")
        defer { fixture.cleanUp() }
        let library = fixture.library()
        let first = library.save(name: "Calm", preset: .standard)
        #expect(first.isSuccess)
        let before = try fixture.storage.read(AmbientFavourites.fileName)
        for name in ["Calm", "calm", " CALM "] {
            let refused = library.save(name: name, preset: .standard)
            #expect(refused.failureCode == "duplicate-name", "\(name)")
            #expect(library.lastRefusal?.code == "duplicate-name", "\(name)")
        }
        #expect(library.entries.count == 1)
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == before)
        let other = library.save(name: "Calmer", preset: .standard)
        #expect(other.isSuccess)
        #expect(library.lastRefusal == nil)
    }

    @Test func anEmptyNameBecomesFavouriteNAndNamesAreTrimmedAndCut() throws {
        let fixture = try FavouritesFixture("names")
        defer { fixture.cleanUp() }
        let library = fixture.library()
        let first = try library.save(name: "", preset: .standard).get()
        #expect(first.name == "Favourite 1")
        let second = try library.save(name: "   ", preset: .standard).get()
        #expect(second.name == "Favourite 2")
        // "Favourite 4" is taken, so the next empty name skips to 5.
        let taken = try library.save(name: "favourite 4", preset: .standard).get()
        #expect(taken.name == "favourite 4")
        let fourth = try library.save(name: "", preset: .standard).get()
        #expect(fourth.name == "Favourite 5")
        let long = String(repeating: "a", count: 70)
        let cut = try library.save(name: long, preset: .standard).get()
        #expect(cut.name.count == AmbientFavourites.maxNameLength)
        #expect(cut.name == String(repeating: "a", count: 60))
        let ids = library.entries.map(\.id)
        #expect(ids == [1, 2, 3, 4, 5].map { SyntheticIDs.id($0) })
    }

    @Test func aDamagedFileGivesAnEmptyListAndIsKeptUntilASave() throws {
        let fixture = try FavouritesFixture("damaged")
        defer { fixture.cleanUp() }
        let garbage = Data("not a favourites file {".utf8)
        try fixture.storage.write(garbage, to: AmbientFavourites.fileName)
        let library = fixture.library()
        #expect(library.entries.isEmpty)
        #expect(library.problems == [.damaged])
        #expect(library.problems.first?.code == "damaged")
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == garbage, "the file is kept as it is")
        library.reload()
        #expect(library.problems == [.damaged])
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == garbage)
        // A save replaces the file and clears the problem.
        let saved = library.save(name: "Fresh", preset: .standard)
        #expect(saved.isSuccess)
        #expect(library.problems.isEmpty)
        let reopened = fixture.library()
        #expect(reopened.entries.map(\.name) == ["Fresh"])
        #expect(reopened.problems.isEmpty)
    }

    @Test func aWrongKindIsDamaged() throws {
        let fixture = try FavouritesFixture("kind")
        defer { fixture.cleanUp() }
        let other = Data(#"{"entries":[],"kind":"a18.theme-preset","schemaVersion":1}"#.utf8)
        try fixture.storage.write(other, to: AmbientFavourites.fileName)
        let library = fixture.library()
        #expect(library.entries.isEmpty && library.problems == [.damaged])
    }

    @Test func aNewerSchemaIsNewerVersion() throws {
        let fixture = try FavouritesFixture("newer")
        defer { fixture.cleanUp() }
        let newer = Data(#"{"entries":[],"kind":"a18.favourites","schemaVersion":2}"#.utf8)
        try fixture.storage.write(newer, to: AmbientFavourites.fileName)
        let library = fixture.library()
        #expect(library.entries.isEmpty)
        #expect(library.problems == [.newerVersion(2)])
        #expect(library.problems.first?.code == "newer-version")
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == newer)
    }

    @Test func aFileAboveTheLimitIsTooLarge() throws {
        let fixture = try FavouritesFixture("large")
        defer { fixture.cleanUp() }
        var large = Data(#"{"entries":[],"kind":"a18.favourites","schemaVersion":1}"#.utf8)
        large.append(Data(repeating: 0x20, count: AmbientFavourites.maxBytes + 1 - large.count))
        #expect(large.count == 65_537)
        try fixture.storage.write(large, to: AmbientFavourites.fileName)
        let library = fixture.library()
        #expect(library.entries.isEmpty)
        #expect(library.problems == [.tooLarge(65_537)])
        #expect(library.problems.first?.code == "too-large")
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == large)
    }

    @Test func anInvalidEntryIsInvalidEntry() throws {
        let fixture = try FavouritesFixture("invalid")
        defer { fixture.cleanUp() }
        let entries = [
            #"{"createdAt":0,"id":"00000000-0000-4000-8000-000000000001","name":"A","#
                + #""preset":{"motion":true,"palette":0,"speed":1,"theme":9}}"#,
            #"{"createdAt":0,"id":"00000000-0000-4000-8000-000000000001","name":"","#
                + #""preset":{"motion":true,"palette":0,"speed":1,"theme":0}}"#,
            #"{"createdAt":0,"id":"00000000-0000-4000-8000-000000000001","name":"A","#
                + #""preset":{"motion":true,"palette":0,"speed":5,"theme":0}}"#,
        ]
        for (index, entry) in entries.enumerated() {
            let file = Data((#"{"entries":["# + entry + #"],"kind":"a18.favourites","schemaVersion":1}"#).utf8)
            try fixture.storage.write(file, to: AmbientFavourites.fileName)
            let library = fixture.library()
            #expect(library.entries.isEmpty, "entry \(index)")
            #expect(library.problems.first?.code == "invalid-entry", "entry \(index)")
            #expect(library.problems.count == 1, "entry \(index)")
        }
        // The same name twice, differing only in case.
        let twice = #"{"entries":[{"createdAt":0,"id":"00000000-0000-4000-8000-000000000001","name":"Calm","#
            + #""preset":{"motion":true,"palette":0,"speed":1,"theme":0}},{"createdAt":0,"#
            + #""id":"00000000-0000-4000-8000-000000000002","name":"calm","#
            + #""preset":{"motion":true,"palette":0,"speed":1,"theme":0}}],"kind":"a18.favourites","schemaVersion":1}"#
        try fixture.storage.write(Data(twice.utf8), to: AmbientFavourites.fileName)
        let library = fixture.library()
        #expect(library.entries.isEmpty)
        #expect(library.problems.first?.code == "invalid-entry")
    }

    @Test func removingTheLastFavouriteRemovesTheFile() throws {
        let fixture = try FavouritesFixture("remove")
        defer { fixture.cleanUp() }
        let library = fixture.library()
        let a = try library.save(name: "A", preset: .standard).get()
        let b = try library.save(name: "B", preset: .standard).get()
        let removedA = library.remove(id: a.id)
        #expect(removedA)
        #expect(library.entries.map(\.id) == [b.id])
        let reread = fixture.library()
        #expect(reread.entries.map(\.name) == ["B"])
        let missing = library.remove(id: SyntheticIDs.id(77))
        #expect(!missing)
        let removedB = library.remove(id: b.id)
        #expect(removedB)
        #expect(library.entries.isEmpty)
        #expect(!fixture.storage.exists(AmbientFavourites.fileName))
    }
}

private extension Result where Success == FavouriteEntry, Failure == FavouriteRefusal {
    /// Whether the save succeeded.
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// The refusal's code, or nil after a success.
    var failureCode: String? {
        if case .failure(let refusal) = self { return refusal.code }
        return nil
    }
}
