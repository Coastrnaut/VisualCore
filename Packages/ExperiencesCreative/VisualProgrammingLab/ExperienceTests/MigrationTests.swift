// MigrationTests — feature 169 (A23-P04) T-A23-405 (FR-A23-403; SC-A23-402, SC-A23-406; clarification Q3; User Story 2
// scenario 2; research D3). The graph file stays schema 1; the library reads an embedded graph of an older version
// through its `MigrationChain` (by default `GraphDocument.migrations`, which has no step yet). A synthetic version-0
// shape (the nodes under `items`) is listed as unreadable (`damaged`, no step) with the default chain; with a test chain
// whose step 0 renames `items` to `nodes`, the same file is listed, opens with the fingerprint of the graph it was made
// from (also through the presenter, in a shell made with that chain), and stays byte-identical until a rename writes it
// again in schema 1. A step that throws gives `damaged`. Short runs, no clock, no sleep.
import Foundation
import Testing
import VisualCoreExperience
import VisualCorePersistence
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct MigrationTests {
    /// Version 0 → 1: the nodes were called `items`.
    static let chain = MigrationChain(currentVersion: 1, steps: [0: { body in
        var next = body
        guard let items = next.removeValue(forKey: "items") else { throw MigrationError.missingStep(0) }
        next["nodes"] = items
        return next
    }])

    /// A chain whose step 0 always throws.
    static let failing = MigrationChain(currentVersion: 1, steps: [0: { _ in throw MigrationError.missingStep(0) }])

    /// The saved graph file of the ramp (``LabLibraryTest/ramp``) named "Old ramp", its embedded graph rewritten in
    /// the synthetic version-0 shape.
    static func versionZero() throws -> Data {
        let current = try GraphLibrary.encode(name: "Old ramp", order: 1, graph: LabLibraryTest.ramp)
        let text = try #require(String(data: current, encoding: .utf8))
        let old = text.replacingOccurrences(of: "\"nodes\":", with: "\"items\":")
            .replacingOccurrences(of: "\"kind\":\"a23.visual-graph\",\"version\":1",
                                  with: "\"kind\":\"a23.visual-graph\",\"version\":0")
        #expect(old.contains("\"items\":") && !old.contains("\"nodes\":") && old.contains("\"version\":0"))
        return Data(old.utf8)
    }

    @Test func withoutAStepTheOldFileIsListedAsDamagedAndKept() throws {
        let place = try LabStoragePlace("migration-none")
        defer { place.remove() }
        let old = try Self.versionZero()
        try place.storage.write(old, to: "graph-1.json")
        let library = GraphLibrary(storage: place.storage)
        #expect(library.migrations.currentVersion == GraphDocument.schemaVersion)
        #expect(library.entries.map(\.state) == [.unreadable("damaged")])
        #expect(LabLibraryTest.failure(library.open("graph-1.json")) == .unreadable("damaged"))
        let throwing = GraphLibrary(storage: place.storage, migrations: Self.failing)
        #expect(throwing.entries.map(\.state) == [.unreadable("damaged")], "a step that throws")
        #expect(try place.storage.read("graph-1.json") == old)
    }

    @Test func anOldFileMigratesAndOpens() throws {
        let place = try LabStoragePlace("migration-step")
        defer { place.remove() }
        let old = try Self.versionZero()
        try place.storage.write(old, to: "graph-1.json")
        let library = GraphLibrary(storage: place.storage, migrations: Self.chain)
        #expect(library.entries == [GraphLibraryEntry(file: "graph-1.json", name: "Old ramp", order: 1,
                                                      state: .readable)])
        let opened = try #require(LabLibraryTest.saved(library.open("graph-1.json")))
        #expect(LabLibraryTest.fingerprint(opened.graph) == LabLibraryTest.fingerprint(LabLibraryTest.ramp))
        #expect(try GraphDocument.encode(opened.graph) == GraphDocument.encode(LabLibraryTest.ramp))
        #expect(try place.storage.read("graph-1.json") == old, "opening does not rewrite the file")
        // A current file reads the same through the test chain.
        let current = try #require(LabLibraryTest.saved(library.save(name: "New ramp", graph: LabLibraryTest.ramp)))
        let reopened = try #require(LabLibraryTest.saved(library.open(current.file)))
        #expect(LabLibraryTest.fingerprint(reopened.graph) == LabLibraryTest.fingerprint(LabLibraryTest.ramp))
        // A rename writes the old file again in schema 1, readable without the step.
        #expect(LabLibraryTest.saved(library.rename("graph-1.json", to: "Older ramp"))?.name == "Older ramp")
        #expect(try place.storage.read("graph-1.json")
                == GraphLibrary.encode(name: "Older ramp", order: 1, graph: LabLibraryTest.ramp))
        let allReadable = GraphLibrary(storage: place.storage).entries.allSatisfy { $0.isReadable }
        #expect(allReadable)
    }

    @Test func anOldFileOpensThroughThePresenter() async throws {
        let place = try LabStoragePlace("migration-presenter")
        defer { place.remove() }
        try place.storage.write(try Self.versionZero(), to: "graph-1.json")
        let shell = try await LabTest.shell(storage: place.storage, migrations: Self.chain)
        #expect(shell.presenter.library?.entries.first?.isReadable == true)
        #expect(LabLibraryTest.saved(shell.presenter.open(file: "graph-1.json"))?.name == "Old ramp")
        let core = try LabTest.core(shell)
        #expect(LabLibraryTest.fingerprint(core.graph) == LabLibraryTest.fingerprint(LabLibraryTest.ramp))
        #expect(core.selection == nil)
    }
}
