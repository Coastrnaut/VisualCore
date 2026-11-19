// LookLibraryTests — feature 182 (A25-P03) T-A25-303 (FR-A25-302, FR-A25-303; clarification Q2; User Story 2;
// Edge Cases "A name another preset has", "The preset cap reached"). The preset library over a temporary storage
// (`PresetStoragePlace`, removed after), after Visual Programming Lab's `LibraryTests` and `LibraryRefusalTests`:
// save and open round trip (equal chain, same fingerprint); rename; remove; a 25th save, an empty or 41-character name
// and a duplicate name (ignoring case) are refused and change nothing; damaged, newer, oversized and invalid-chain
// files are listed as unreadable and stay byte-identical after listing and opening; a newer index makes the library
// read only; a damaged index is rebuilt only by the next change; a full storage quota refuses a save with "There is
// not enough space to save this preset." and writes nothing. Synthetic names only; short runs, no clock, no sleep.
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerExperience

/// A temporary experience storage: its own folder and defaults suite, removed afterwards.
struct PresetStoragePlace {
    /// The defaults suite and folder name.
    let suite: String
    /// The root folder.
    let root: URL
    /// The handle.
    let storage: ExperienceStorage

    /// A fresh place named `name`.
    @MainActor
    init(_ name: String) throws {
        suite = "a25.preset-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: ComposerTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    /// Every file of the storage with its bytes.
    func contents() throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in storage.list() { files[name] = try storage.read(name) }
        return files
    }
}

/// Preset library helpers.
enum PresetTest {
    /// A chain of three nodes with fractional values and a skipped node.
    static var mixed: EffectChain {
        EffectChain(nodes: [
            EffectNode(id: 3, effect: .grade, enabled: true,
                       values: ["exposure": -0.375, "contrast": 1.2345678901234, "saturation": 0.1]),
            EffectNode(id: 1, effect: .blur, enabled: false, values: ["radius": 5]),
            EffectNode(id: 7, effect: .vignette, enabled: true,
                       values: ["amount": 0.3333333333333333, "radius": 0.2, "softness": 1]),
        ])
    }

    /// A one-node chain.
    static let single = EffectChain(nodes: [EffectNode(id: 1, effect: .posterize)])

    /// The value of a success; records an issue for a failure.
    static func value<T>(_ result: Result<T, LookLibraryFailure>,
                         sourceLocation: SourceLocation = #_sourceLocation) -> T? {
        switch result {
        case .success(let value): return value
        case .failure(let failure):
            Issue.record("refused: \(failure.code)", sourceLocation: sourceLocation)
            return nil
        }
    }

    /// The failure of `result`; nil for a success.
    static func failure<T>(_ result: Result<T, LookLibraryFailure>) -> LookLibraryFailure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct LookLibraryTests {
    @Test func saveOpenRenameAndRemoveRoundTrip() throws {
        let place = try PresetStoragePlace("round-trip")
        defer { place.remove() }
        let library = LookLibrary(storage: place.storage)
        #expect(library.entries.isEmpty && library.next == 1 && !library.isReadOnly)
        let chain = PresetTest.mixed
        let entry = try #require(PresetTest.value(library.save(name: "  Warm edge ", chain: chain)))
        #expect(entry.file == "preset-1.json" && entry.name == "Warm edge" && entry.order == 1 && entry.isReadable)
        #expect(entry.stem == "preset-1" && entry.number == 1)
        #expect(place.storage.exists(LookLibrary.indexFile))
        let opened = try #require(PresetTest.value(library.open(file: entry.file)))
        #expect(opened == chain && opened.fingerprint() == chain.fingerprint())
        #expect(ChainDocument.encode(opened) == ChainDocument.encode(chain))
        // The file is the envelope with the chain file's object embedded.
        let object = try #require(try JSONSerialization.jsonObject(with: place.storage.read(entry.file))
            as? [String: Any])
        #expect(object["kind"] as? String == "a25.preset" && object["version"] as? Int == 1)
        let body = try #require(object["body"] as? [String: Any])
        #expect(Set(body.keys) == ["chain", "name", "order"])
        #expect((body["chain"] as? [String: Any])?["kind"] as? String == ChainDocument.kind)
        // A second library over the same storage reads the same list and counter.
        let again = LookLibrary(storage: place.storage)
        #expect(again.entries == library.entries && again.next == 2)
        // A second preset is listed first (newest).
        let twin = try #require(PresetTest.value(library.save(name: "Posterized", chain: PresetTest.single)))
        #expect(twin.file == "preset-2.json" && twin.order == 2)
        #expect(library.entries.map(\.name) == ["Posterized", "Warm edge"])
        let twinBytes = try place.storage.read(twin.file)
        let renamed = try #require(PresetTest.value(library.rename(file: entry.file, to: "Cool edge")))
        #expect(renamed.file == entry.file && renamed.order == entry.order && renamed.name == "Cool edge")
        #expect(try place.storage.read(twin.file) == twinBytes, "a rename leaves the other preset untouched")
        // Renaming to its own name in another case is allowed.
        #expect(PresetTest.value(library.rename(file: entry.file, to: "COOL EDGE"))?.name == "COOL EDGE")
        let reopened = try #require(PresetTest.value(library.open(file: entry.file)))
        #expect(reopened.fingerprint() == chain.fingerprint())
        #expect(PresetTest.failure(library.remove(file: entry.file)) == nil)
        #expect(!place.storage.exists(entry.file) && library.entries.map(\.file) == [twin.file])
        #expect(try place.storage.read(twin.file) == twinBytes, "a removal leaves the other preset untouched")
        #expect(PresetTest.failure(library.remove(file: entry.file)) == .missing)
        #expect(PresetTest.failure(library.open(file: entry.file)) == .missing)
        // The counter is not reused after a removal; the empty chain saves too.
        #expect(PresetTest.value(library.save(name: "Nothing", chain: EffectChain.empty))?.file == "preset-3.json")
        #expect(PresetTest.value(library.open(file: "preset-3.json")) == EffectChain.empty)
    }

    @Test func refusedSavesAndRenamesChangeNothing() throws {
        let place = try PresetStoragePlace("refusals")
        defer { place.remove() }
        let library = LookLibrary(storage: place.storage)
        for n in 1...LookLibrary.maxPresets {
            #expect(PresetTest.value(library.save(name: "Preset \(n)", chain: PresetTest.single)) != nil)
        }
        let before = try place.contents()
        let entries = library.entries
        let full = PresetTest.failure(library.save(name: "Preset 25", chain: PresetTest.single))
        #expect(full == .full && full?.message == "The library holds 24 presets.")
        let empty = PresetTest.failure(library.save(name: "   ", chain: PresetTest.single))
        #expect(empty == .badName && empty?.message == "A name has 1 to 40 characters.")
        let long = String(repeating: "a", count: 41)
        #expect(PresetTest.failure(library.save(name: long, chain: PresetTest.single)) == .badName)
        let taken = PresetTest.failure(library.save(name: " preset 3 ", chain: PresetTest.mixed))
        #expect(taken == .taken("Preset 3") && taken?.message == "A preset is already called Preset 3.")
        let first = try #require(library.entries.last)
        #expect(PresetTest.failure(library.rename(file: first.file, to: "PRESET 4")) == .taken("Preset 4"))
        #expect(PresetTest.failure(library.rename(file: first.file, to: "")) == .badName)
        #expect(PresetTest.failure(library.rename(file: first.file, to: long)) == .badName)
        #expect(PresetTest.failure(library.rename(file: "preset-99.json", to: "Other")) == .missing)
        #expect(try place.contents() == before && library.entries == entries, "a refusal changes nothing")
        // A 40-character name fits (a rename keeps the count).
        let forty = String(repeating: "b", count: 40)
        #expect(PresetTest.value(library.rename(file: first.file, to: forty))?.name == forty)
    }

    @Test func unreadableFilesAreListedAndKeptByteIdentical() throws {
        let place = try PresetStoragePlace("unreadable")
        defer { place.remove() }
        let storage = place.storage
        let library = LookLibrary(storage: storage)
        let good = try #require(PresetTest.value(library.save(name: "Good", chain: PresetTest.mixed)))
        let valid = try storage.read(good.file)
        let validText = try #require(String(data: valid, encoding: .utf8))
        try storage.write(Data("{not json".utf8), to: "preset-2.json")
        let tail = "\"version\":1}"
        #expect(validText.hasSuffix(tail))
        try storage.write(Data((String(validText.dropLast(tail.count)) + "\"version\":2}").utf8), to: "preset-3.json")
        try storage.write(Data(count: LookLibrary.maxFileBytes + 1), to: "preset-4.json")
        try storage.write(Data(validText.replacingOccurrences(of: "\"vignette\"", with: "\"sparkle\"").utf8),
                          to: "preset-5.json")
        let before = try place.contents()
        let listed = LookLibrary(storage: storage)
        #expect(listed.entries.map(\.file) == ["preset-1.json", "preset-2.json", "preset-3.json", "preset-4.json",
                                               "preset-5.json"])
        #expect(listed.entries.map(\.refusal) == [nil, "damaged", "newer-version", "too-large", "unknown-effect"])
        #expect(listed.entries.dropFirst().allSatisfy { $0.order == 0 && !$0.isReadable })
        #expect(listed.next == 6)
        for file in ["preset-2.json", "preset-3.json", "preset-4.json", "preset-5.json"] {
            let refused = PresetTest.failure(listed.open(file: file))
            #expect(refused == .unreadable(listed.entry(file: file)?.refusal ?? ""))
            #expect(PresetTest.failure(listed.rename(file: file, to: "Renamed")) != nil)
        }
        #expect(PresetTest.failure(listed.open(file: "preset-2.json"))?.message
                == "This preset cannot be opened (damaged).")
        #expect(try place.contents() == before, "listing and opening keep every file byte-identical")
        // A save after them takes the next number and keeps them; one is removed only on request.
        let saved = try #require(PresetTest.value(listed.save(name: "Later", chain: PresetTest.single)))
        #expect(saved.file == "preset-6.json" && listed.entries.first == saved)
        for (name, data) in before where name != LookLibrary.indexFile {
            #expect(try storage.read(name) == data, "\(name) kept")
        }
        #expect(PresetTest.failure(listed.remove(file: "preset-2.json")) == nil)
        #expect(!storage.exists("preset-2.json") && listed.entries.count == 5)
    }

    @Test func aNewerIndexMakesTheLibraryReadOnly() throws {
        let place = try PresetStoragePlace("newer-index")
        defer { place.remove() }
        let storage = place.storage
        let entry = try #require(PresetTest.value(LookLibrary(storage: storage)
            .save(name: "Warm", chain: PresetTest.mixed)))
        try storage.write(Data("{\"body\":{},\"kind\":\"a25.preset-library\",\"version\":2}".utf8),
                          to: LookLibrary.indexFile)
        let before = try place.contents()
        let library = LookLibrary(storage: storage)
        #expect(library.isReadOnly && library.indexProblem == "newer-version" && library.entries == [entry])
        #expect(PresetTest.failure(library.save(name: "Cold", chain: PresetTest.single)) == .readOnly)
        #expect(PresetTest.failure(library.rename(file: entry.file, to: "Cold")) == .readOnly)
        #expect(PresetTest.failure(library.remove(file: entry.file)) == .readOnly)
        #expect(PresetTest.value(library.open(file: entry.file)) == PresetTest.mixed, "opening still works")
        #expect(try place.contents() == before)
    }

    @Test func aDamagedIndexIsRebuiltOnlyByTheNextChange() throws {
        let place = try PresetStoragePlace("damaged-index")
        defer { place.remove() }
        let storage = place.storage
        let entry = try #require(PresetTest.value(LookLibrary(storage: storage)
            .save(name: "Warm", chain: PresetTest.mixed)))
        let damaged = Data("[1, 2".utf8)
        try storage.write(damaged, to: LookLibrary.indexFile)
        let before = try place.contents()
        let library = LookLibrary(storage: storage)
        #expect(!library.isReadOnly && library.indexProblem == "damaged" && library.entries == [entry])
        #expect(library.next == 2, "the counter is recovered from the files")
        #expect(PresetTest.value(library.open(file: entry.file)) == PresetTest.mixed)
        library.reload()
        #expect(try place.contents() == before, "reading and opening do not rewrite the index")
        let saved = try #require(PresetTest.value(library.save(name: "Cold", chain: PresetTest.single)))
        #expect(saved.file == "preset-2.json")
        let index = try LookLibrary.decodeIndex(storage.read(LookLibrary.indexFile)).get()
        #expect(index.next == 3 && index.entries.map(\.file) == ["preset-2.json", "preset-1.json"])
        #expect(LookLibrary(storage: storage).indexProblem == nil)
    }

    @Test func aFullQuotaRefusesWithTheMessageAndWritesNothing() throws {
        let place = try PresetStoragePlace("quota")
        defer { place.remove() }
        let storage = place.storage
        let library = LookLibrary(storage: storage)
        let entry = try #require(PresetTest.value(library.save(name: "Warm", chain: PresetTest.mixed)))
        let used = try place.contents().values.reduce(0) { $0 + $1.count }
        try storage.write(Data(count: StorageQuota.maxBytes - used - 8), to: "filler.bin")
        let before = try place.contents()
        let refused = PresetTest.failure(library.save(name: "Cold", chain: PresetTest.single))
        #expect(refused == .noSpace && refused?.code == "a25.no-space")
        #expect(refused?.message == "There is not enough space to save this preset.")
        #expect(!storage.exists("preset-2.json"))
        #expect(PresetTest.failure(library.rename(file: entry.file, to: "Warm at the end of a long day")) == .noSpace)
        #expect(try place.contents() == before, "nothing is half-written")
        #expect(library.entries == [entry])
        #expect(PresetTest.value(library.open(file: entry.file))?.fingerprint() == PresetTest.mixed.fingerprint())
    }

    @Test func anInvalidChainIsRefusedBeforeWriting() throws {
        let place = try PresetStoragePlace("invalid-chain")
        defer { place.remove() }
        let library = LookLibrary(storage: place.storage)
        let bad = EffectChain(nodes: [EffectNode(id: 1, effect: .grade, enabled: true,
                                                 values: ["exposure": 9, "contrast": 1, "saturation": 1])])
        #expect(PresetTest.failure(library.save(name: "Bad", chain: bad)) == .chain("out-of-range"))
        #expect(place.storage.list().isEmpty)
    }
}
