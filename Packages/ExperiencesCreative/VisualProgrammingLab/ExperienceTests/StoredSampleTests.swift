// StoredSampleTests — feature 169 (A23-P04) T-A23-405 (FR-A23-402, FR-A23-403; SC-A23-401, SC-A23-406; clarification
// Q3). The committed schema-1 sample `ExperienceTests/Fixtures/graph-sample.json` is answered by the code that reads it
// in the app. It was written once through the real encoder, `GraphLibrary.encode(name:order:graph:)`, of "Sample
// clouds" (order 1, the example graph `mixed-clouds`: six nodes, five connections, parameters off their defaults); the
// first test proves today's encoder still writes exactly its bytes. Copied into a temporary experience storage as
// `graph-1.json` (`LabStoragePlace`, removed afterwards), it lists with its name and order, opens with the fingerprint
// and canonical encoding of the example's graph (also through the presenter, with no selection), and afterwards the
// stored copy and the bundled sample are byte for byte the sample and no file was added (reading writes no index). No
// UUID and no path appears in the sample. Short runs only, no clock, no sleep.
import Foundation
import Testing
import VisualCoreExperience
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

/// The bytes of the bundled sample `name` (without extension).
private func sample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@MainActor
@Suite(.serialized) struct StoredSampleTests {
    /// The graph of the sample: the example `mixed-clouds`.
    static var graph: VisualGraph { LabExamples.mixedClouds.graph }

    @Test func theEncoderWritesTheSampleBytes() throws {
        let bytes = try sample("graph-sample")
        #expect(try GraphLibrary.encode(name: "Sample clouds", order: 1, graph: Self.graph) == bytes,
                "the committed sample is today's encoding")
        let decoded = GraphLibrary.decode(bytes)
        guard case .success(let found) = decoded else {
            Issue.record("the sample does not decode: \(decoded)")
            return
        }
        #expect(found.saved.name == "Sample clouds" && found.saved.order == 1)
        #expect(found.graph.nodes.count == 6 && found.graph.edges.count == 5)
    }

    @Test func theSampleListsOpensAndStaysUnchanged() async throws {
        let place = try LabStoragePlace("sample-current")
        defer { place.remove() }
        let bytes = try sample("graph-sample")
        try place.storage.write(bytes, to: "graph-1.json")
        #expect(try place.storage.read("graph-1.json") == bytes, "the stored copy is the sample")
        let library = GraphLibrary(storage: place.storage)
        #expect(library.indexProblem == nil && !library.isReadOnly && library.next == 2)
        #expect(library.entries == [GraphLibraryEntry(file: "graph-1.json", name: "Sample clouds", order: 1,
                                                      state: .readable)])
        let opened = try #require(LabLibraryTest.saved(library.open("graph-1.json")))
        #expect(LabLibraryTest.fingerprint(opened.graph) == LabLibraryTest.fingerprint(Self.graph))
        #expect(try GraphDocument.encode(opened.graph) == GraphDocument.encode(Self.graph))
        #expect(opened.graph.node(NodeID(2))?.parameters == ["scale": 6, "speed": 0.5])
        #expect(opened.graph.node(NodeID(3))?.position == CanvasPoint(x: 280, y: 280))

        let shell = try await LabTest.shell(storage: place.storage)
        #expect(LabLibraryTest.saved(shell.presenter.open(file: "graph-1.json"))?.name == "Sample clouds")
        let core = try LabTest.core(shell)
        #expect(LabLibraryTest.fingerprint(core.graph) == LabLibraryTest.fingerprint(Self.graph))
        #expect(core.selection == nil)

        #expect(try place.contents() == ["graph-1.json": bytes], "byte-identical, no file added")
        #expect(try sample("graph-sample") == bytes, "the bundled sample stays byte-identical")
        let text = try #require(String(data: bytes, encoding: .utf8))
        #expect(!text.contains("/") && !text.contains("-4000-"), "no path and no UUID in the sample")
    }
}
