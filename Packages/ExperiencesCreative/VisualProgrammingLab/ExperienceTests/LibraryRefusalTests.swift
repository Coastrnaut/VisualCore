// LibraryRefusalTests — feature 169 (A23-P04) T-A23-405 (FR-A23-401, FR-A23-403, FR-A23-406; SC-A23-402, SC-A23-403,
// SC-A23-406; clarification Q1; User Stories 1, 2; Edge Cases "A name of only spaces or past the length limit", "A file
// past the size limit", "The storage quota reached while saving"). Over a temporary storage (`LabStoragePlace`):
//   - the caps at and one past each bound: 24 graphs (an unreadable file counts) and a 25th refused with "The library
//     holds 24 graphs."; names of 40 and 41 characters, empty and only spaces ("A name has 1 to 40 characters."); a
//     name taken in another case ("A graph is already called <name>."); every refusal leaves the storage
//     byte-identical;
//   - damaged, newer (the file's envelope and the embedded graph's), oversized (81,921 bytes and more) and out-of-range
//     samples are listed as unreadable with their codes, refused on open and rename (also through the presenter, the
//     open graph unchanged), still present byte for byte afterwards, and removed only by an explicit call;
//   - a full byte quota (a filler file) refuses a save and a rename with the storage's code and writes nothing;
//   - a newer index makes the library read only (opening still works) and is never overwritten.
// Synthetic names only; short runs, no clock, no sleep.
import Foundation
import Testing
import VisualCoreExperience
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct LibraryRefusalTests {
    /// The text of the saved graph file of `graph` named `name` with order `order`.
    static func text(_ name: String, order: Int = 1, graph: VisualGraph) throws -> String {
        try #require(String(data: try GraphLibrary.encode(name: name, order: order, graph: graph), encoding: .utf8))
    }

    @Test func theCountAndNameCapsRefuseAtOnePastAndChangeNothing() throws {
        let place = try LabStoragePlace("caps")
        defer { place.remove() }
        let storage = place.storage
        // An unreadable file counts towards the 24.
        try storage.write(Data("{\"kind\":\"a23.saved-graph\"".utf8), to: "graph-1.json")
        let library = GraphLibrary(storage: storage)
        for index in 1..<GraphLibrary.maxGraphs {
            _ = LabLibraryTest.saved(library.save(name: "Graph \(index)", graph: LabLibraryTest.ramp))
        }
        #expect(library.entries.count == 24 && library.readable.count == 23)
        var before = try place.contents()
        let full = LabLibraryTest.failure(library.save(name: "One more", graph: LabLibraryTest.ramp))
        #expect(full == .full && full?.message == "The library holds 24 graphs.")
        #expect(try place.contents() == before)

        #expect(LabLibraryTest.failure(library.remove("graph-24.json")) == nil)
        #expect(library.entries.count == 23)
        before = try place.contents()
        let target = try #require(library.entry(named: "Graph 1"))
        for bad in ["", "   ", String(repeating: "b", count: 41), " " + String(repeating: "c", count: 41) + " "] {
            let refused = LabLibraryTest.failure(library.save(name: bad, graph: LabLibraryTest.ramp))
            #expect(refused == .badName && refused?.message == "A name has 1 to 40 characters.", "\(bad.count)")
            #expect(LabLibraryTest.failure(library.rename(target.file, to: bad)) == .badName)
        }
        let taken = LabLibraryTest.failure(library.save(name: "  graph 2", graph: LabLibraryTest.journey))
        #expect(taken == .taken("Graph 2") && taken?.message == "A graph is already called Graph 2.")
        #expect(LabLibraryTest.failure(library.rename(target.file, to: "GRAPH 3")) == .taken("Graph 3"))
        #expect(try place.contents() == before, "every refusal writes nothing")

        // At the bounds: a 40-character name (trimmed) saves as the 24th graph; a rename to its own name in
        // another case is accepted.
        let forty = String(repeating: "a", count: 40)
        #expect(LabLibraryTest.saved(library.save(name: " " + forty + " ", graph: LabLibraryTest.ramp))?.name == forty)
        #expect(library.entries.count == 24)
        #expect(LabLibraryTest.saved(library.rename(target.file, to: "GRAPH 1"))?.name == "GRAPH 1")
        #expect(LabLibraryTest.failure(library.save(name: "A", graph: LabLibraryTest.ramp)) == .full)
    }

    @Test func unreadableFilesAreListedRefusedAndKept() async throws {
        let place = try LabStoragePlace("unreadable")
        defer { place.remove() }
        let storage = place.storage
        let good = try Self.text("Good", graph: LabLibraryTest.ramp)
        try storage.write(Data("{\"kind\":\"a23.saved-graph\"".utf8), to: "graph-1.json")
        try storage.write(Data("{\"body\":{},\"kind\":\"a23.saved-graph\",\"version\":2}".utf8), to: "graph-2.json")
        let padded = Data(good.utf8) + Data(repeating: 0x20, count: GraphLibrary.maxFileBytes + 1 - good.utf8.count)
        #expect(padded.count == GraphLibrary.maxFileBytes + 1)
        try storage.write(padded, to: "graph-3.json")
        let newerGraph = good.replacingOccurrences(of: "\"kind\":\"a23.visual-graph\",\"version\":1",
                                                   with: "\"kind\":\"a23.visual-graph\",\"version\":2")
        #expect(newerGraph != good)
        try storage.write(Data(newerGraph.utf8), to: "graph-4.json")
        let wide = good.replacingOccurrences(of: "\"x\":100", with: "\"x\":9000")
        #expect(wide != good)
        try storage.write(Data(wide.utf8), to: "graph-5.json")
        // At the size bound exactly, a padded file still reads.
        let atBound = Data(good.utf8) + Data(repeating: 0x20, count: GraphLibrary.maxFileBytes - good.utf8.count)
        try storage.write(atBound, to: "graph-6.json")
        let before = try place.contents()

        let library = GraphLibrary(storage: storage)
        #expect(library.entries.map { $0.refusal ?? "readable" }
                == ["readable", "damaged", "newer-version", "too-large", "newer-version", "out-of-range"])
        #expect(library.entries.first?.file == "graph-6.json")
        for entry in library.entries where !entry.isReadable {
            let code = entry.refusal ?? ""
            let opened = LabLibraryTest.failure(library.open(entry.file))
            #expect(opened == .unreadable(code), "\(entry.file)")
            #expect(opened?.message == "This saved graph cannot be opened (\(code)).")
            #expect(LabLibraryTest.failure(library.rename(entry.file, to: "Fixed")) == .unreadable(code))
        }
        #expect(try place.contents() == before, "nothing is rewritten or removed")
        #expect(GraphLibrary(storage: storage).entries == library.entries)

        // Through the presenter: refused, the open graph unchanged, the file kept.
        let shell = try await LabTest.shell(storage: storage)
        let graph = try LabTest.core(shell).graph
        #expect(LabLibraryTest.failure(shell.presenter.open(file: "graph-1.json")) == .unreadable("damaged"))
        #expect(try LabTest.core(shell).graph == graph)
        #expect(shell.presenter.mirror.libraryMessage == "This saved graph cannot be opened (damaged).")

        // A good graph still saves after the highest file; the unreadable files stay; one is removed on request.
        let saved = try #require(LabLibraryTest.saved(library.save(name: "Waves", graph: LabLibraryTest.journey)))
        #expect(saved.file == "graph-7.json" && library.entries.first == saved)
        for (name, data) in before { #expect(try storage.read(name) == data, "\(name) kept") }
        #expect(LabLibraryTest.failure(library.remove("graph-1.json")) == nil)
        #expect(!storage.exists("graph-1.json") && library.entries.count == 6)
    }

    @Test func aFullQuotaRefusesAndWritesNothing() throws {
        let place = try LabStoragePlace("quota")
        defer { place.remove() }
        let storage = place.storage
        let library = GraphLibrary(storage: storage)
        let entry = try #require(LabLibraryTest.saved(library.save(name: "Clouds", graph: LabLibraryTest.journey)))
        let used = try place.contents().values.reduce(0) { $0 + $1.count }
        try storage.write(Data(count: StorageQuota.maxBytes - used - 8), to: "filler.bin")
        let before = try place.contents()
        let refused = LabLibraryTest.failure(library.save(name: "Ramp", graph: LabLibraryTest.ramp))
        #expect(refused == .storage(.quotaExceeded("bytes")))
        #expect(refused?.message == "The library could not be changed (storage.quota-exceeded).")
        #expect(!storage.exists("graph-2.json"))
        let longer = LabLibraryTest.failure(library.rename(entry.file, to: "Clouds at the end of a long day"))
        #expect(longer == .storage(.quotaExceeded("bytes")))
        #expect(try place.contents() == before, "nothing is half-written")
        #expect(library.entries == [entry])
        let opened = try #require(LabLibraryTest.saved(library.open(entry.file)))
        #expect(LabLibraryTest.fingerprint(opened.graph) == LabLibraryTest.fingerprint(LabLibraryTest.journey))
    }

    @Test func aNewerIndexMakesTheLibraryReadOnly() throws {
        let place = try LabStoragePlace("newer-index")
        defer { place.remove() }
        let storage = place.storage
        let entry = try #require(LabLibraryTest.saved(GraphLibrary(storage: storage)
            .save(name: "Clouds", graph: LabLibraryTest.journey)))
        try storage.write(Data("{\"body\":{},\"kind\":\"a23.graph-library\",\"version\":2}".utf8),
                          to: GraphLibrary.indexFile)
        let before = try place.contents()
        let library = GraphLibrary(storage: storage)
        #expect(library.isReadOnly && library.indexProblem == "newer-version" && library.entries == [entry])
        #expect(LabLibraryTest.failure(library.save(name: "Ramp", graph: LabLibraryTest.ramp)) == .readOnly)
        #expect(LabLibraryTest.failure(library.rename(entry.file, to: "Ramp")) == .readOnly)
        #expect(LabLibraryTest.failure(library.remove(entry.file)) == .readOnly)
        #expect(LabLibraryTest.failure(library.open(entry.file)) == nil)
        #expect(try place.contents() == before)
    }
}
