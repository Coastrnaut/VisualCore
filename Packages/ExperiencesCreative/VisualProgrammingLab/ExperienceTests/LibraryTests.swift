// LibraryTests — feature 169 (A23-P04) T-A23-405 (FR-A23-401, FR-A23-402, FR-A23-406; SC-A23-401, SC-A23-406;
// clarifications Q1, Q2; User Story 1; Edge Cases "The same graph saved twice", "Opening a graph while the preview is
// compiling", "Opening over unsaved work"). The named graphs over a temporary storage (`LabStoragePlace`, removed
// after): save, open, rename and remove round trips give a graph of equal `GraphDocument` fingerprint and canonical
// encoding (identities, connections, values and positions); the same graph saved under two names is two entries; a
// rename or a removal leaves the other files byte-identical; through the presenter, a saved graph opens in a new shell
// over the same storage with no selection; opening over unsaved work asks first, and declining changes neither the
// graph nor the storage; an opened graph compiles once, at the next frame and not in the control; without storage the
// library is unavailable while the examples still open. Synthetic names only; short runs, no clock, no sleep.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct LibraryTests {
    @Test func saveOpenRenameAndRemoveRoundTrip() throws {
        let place = try LabStoragePlace("round-trip")
        defer { place.remove() }
        let library = GraphLibrary(storage: place.storage)
        #expect(library.entries.isEmpty && library.next == 1 && !library.isReadOnly)
        let journey = LabLibraryTest.journey
        let entry = try #require(LabLibraryTest.saved(library.save(name: "  Clouds ", graph: journey)))
        #expect(entry.file == "graph-1.json" && entry.name == "Clouds" && entry.order == 1 && entry.isReadable)
        #expect(entry.stem == "graph-1" && entry.number == 1)
        #expect(place.storage.exists(GraphLibrary.indexFile))
        let opened = try #require(LabLibraryTest.saved(library.open(entry.file)))
        #expect(LabLibraryTest.fingerprint(opened.graph) == LabLibraryTest.fingerprint(journey))
        #expect(try GraphDocument.encode(opened.graph) == GraphDocument.encode(journey), "identities, links, values")
        // A second library over the same storage reads the same list and counter.
        let again = GraphLibrary(storage: place.storage)
        #expect(again.entries == library.entries && again.next == 2)
        // The same graph under a second name is a second entry, listed first (newest).
        let twin = try #require(LabLibraryTest.saved(library.save(name: "Clouds again", graph: journey)))
        #expect(twin.file == "graph-2.json" && twin.order == 2)
        #expect(library.entries.map(\.name) == ["Clouds again", "Clouds"])
        let twinBytes = try place.storage.read(twin.file)
        let renamed = try #require(LabLibraryTest.saved(library.rename(entry.file, to: "Mixed")))
        #expect(renamed.file == entry.file && renamed.order == entry.order && renamed.name == "Mixed")
        #expect(try place.storage.read(twin.file) == twinBytes, "a rename leaves the other graph untouched")
        let reopened = try #require(LabLibraryTest.saved(library.open(entry.file)))
        #expect(LabLibraryTest.fingerprint(reopened.graph) == LabLibraryTest.fingerprint(journey))
        #expect(LabLibraryTest.failure(library.remove(entry.file)) == nil)
        #expect(!place.storage.exists(entry.file) && library.entries.map(\.file) == [twin.file])
        #expect(try place.storage.read(twin.file) == twinBytes, "a removal leaves the other graph untouched")
        #expect(LabLibraryTest.failure(library.remove(entry.file)) == .missing)
        #expect(LabLibraryTest.failure(library.open(entry.file)) == .missing)
        // The counter is not reused after a removal.
        #expect(LabLibraryTest.saved(library.save(name: "Ramp", graph: LabLibraryTest.ramp))?.file == "graph-3.json")
    }

    @Test func aSavedGraphOpensInANewShellWithNoSelection() async throws {
        let place = try LabStoragePlace("new-shell")
        defer { place.remove() }
        let shell = try await LabTest.shell(storage: place.storage)
        let presenter = shell.presenter
        #expect(presenter.library != nil)
        LabTest.accept(shell, "node.add", [3, 40, 300])                 // Gradient 3
        LabTest.accept(shell, "node.move", [1, 72, 112])
        LabTest.accept(shell, "node.select", [3])
        let edited = try LabTest.core(shell).graph
        let entry = try #require(LabLibraryTest.saved(presenter.save(name: "Edited")))
        #expect(presenter.mirror.libraryMessage == "Saved Edited.")
        #expect(!presenter.needsReplaceConfirmation, "the saved graph is the one opening compares with")

        let other = try await LabTest.shell(storage: place.storage)
        #expect(other.presenter.library?.entries.map(\.name) == ["Edited"])
        #expect(LabLibraryTest.saved(other.presenter.open(file: entry.file))?.file == entry.file)
        let core = try LabTest.core(other)
        #expect(LabLibraryTest.fingerprint(core.graph) == LabLibraryTest.fingerprint(edited))
        #expect(try GraphDocument.encode(core.graph) == GraphDocument.encode(edited))
        #expect(core.selection == nil, "an opened graph has no selection")
        #expect(other.presenter.mirror.graph == core.graph && other.presenter.mirror.libraryMessage == "Opened Edited.")
        #expect(try LabTest.digest(other) == labDigest(LabCore(graph: edited)))
        // Renaming and removing through the presenter keep the open graph.
        #expect(LabLibraryTest.saved(other.presenter.rename(file: entry.file, to: "Kept"))?.name == "Kept")
        #expect(other.presenter.mirror.libraryMessage == "Renamed Edited to Kept.")
        #expect(LabLibraryTest.failure(other.presenter.remove(file: entry.file)) == nil)
        #expect(other.presenter.mirror.libraryMessage == "Removed Kept.")
        #expect(try LabTest.core(other).graph == core.graph)
    }

    @Test func openingOverUnsavedWorkAsksFirstAndDecliningChangesNothing() async throws {
        let place = try LabStoragePlace("replace")
        defer { place.remove() }
        let shell = try await LabTest.shell(storage: place.storage)
        let presenter = shell.presenter
        #expect(!presenter.needsReplaceConfirmation, "the starter graph needs no confirmation")
        let library = try #require(presenter.library)
        let entry = try #require(LabLibraryTest.saved(library.save(name: "Ramp", graph: LabLibraryTest.ramp)))
        LabTest.accept(shell, "node.add", [0, 40, 300])                 // Time 3: unsaved work
        #expect(presenter.needsReplaceConfirmation)
        let edited = try LabTest.fingerprint(shell)
        let files = try place.contents()

        #expect(!presenter.request(.file(entry.file)), "it asks first")
        #expect(presenter.mirror.pendingReplace == .file(entry.file))
        #expect(try LabTest.fingerprint(shell) == edited && place.contents() == files, "asking changes nothing")
        presenter.declineReplace()
        #expect(presenter.mirror.pendingReplace == nil)
        #expect(try LabTest.fingerprint(shell) == edited && place.contents() == files, "declining changes nothing")
        presenter.confirmReplace()
        #expect(try LabTest.fingerprint(shell) == edited, "nothing pending, nothing opened")

        #expect(!presenter.request(.example("clouds")))
        #expect(presenter.mirror.pendingReplace == .example("clouds"))
        #expect(!presenter.request(.file(entry.file)))
        #expect(presenter.mirror.pendingReplace == .file(entry.file), "the latest request is the pending one")
        presenter.confirmReplace()
        #expect(presenter.mirror.pendingReplace == nil)
        #expect(try LabTest.fingerprint(shell) == LabLibraryTest.fingerprint(LabLibraryTest.ramp))
        #expect(!presenter.needsReplaceConfirmation)
        #expect(try place.contents() == files, "opening writes nothing")
        // Nothing changed since the open: an example opens at once.
        #expect(presenter.request(.example("clouds")))
        #expect(try LabTest.fingerprint(shell) == LabLibraryTest.fingerprint(LabExamples.clouds.graph))
        #expect(presenter.mirror.libraryMessage == "Opened the example Clouds.")
    }

    @Test func anOpenedGraphCompilesOnceAtTheNextFrame() async throws {
        let place = try LabStoragePlace("compile")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session, size: CGSize(width: 96, height: 96), preview: true,
                                           storage: place.storage)
        let presenter = shell.presenter
        let library = try #require(presenter.library)
        let entry = try #require(LabLibraryTest.saved(library.save(name: "Journey", graph: LabLibraryTest.journey)))
        #expect(presenter.previewState == .ready)
        let compiles = presenter.pipeline.compileCount
        #expect(LabLibraryTest.saved(presenter.open(file: entry.file)) != nil)
        #expect(presenter.pipeline.compileCount == compiles, "opening compiles nothing in the control")
        try LabTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1, "the opened graph compiles at the next frame")
        #expect(presenter.previewState == .ready)
        #expect(presenter.pipeline.schedule?.passes.count == 6, "the journey's six passes (Blur's two included)")
        try LabTest.draw(session, frames: 2)
        #expect(presenter.pipeline.compileCount == compiles + 1, "and only once")
        #expect(session.renderHost?.resources.stats.leaked == 0)
    }

    @Test func withoutStorageTheLibraryIsUnavailableAndTheExamplesStillOpen() async throws {
        let shell = try await LabTest.shell()
        let presenter = shell.presenter
        #expect(presenter.library == nil)
        #expect(LabLibraryTest.failure(presenter.save(name: "Clouds")) == .unavailable)
        #expect(LabLibraryTest.failure(presenter.open(file: "graph-1.json")) == .unavailable)
        #expect(presenter.mirror.libraryMessage == "The library is not available.")
        #expect(LabLibraryTest.saved(presenter.openExample(id: "soft-gradient"))?.id == "soft-gradient")
        #expect(try LabTest.fingerprint(shell) == LabLibraryTest.fingerprint(LabExamples.softGradient.graph))
        #expect(LabLibraryTest.failure(presenter.openExample(id: "sunset")) == .missing)
        let unreadable = GraphLibraryEntry(file: "graph-3.json", name: "graph-3.json", order: 0,
                                           state: .unreadable("damaged"))
        #expect(LabLibraryView.rowLabel(unreadable) == "graph-3.json, unreadable: damaged")
        #expect(LabLibraryView.identifierNames(unreadable) == ["library-row-graph-3", "library-remove-graph-3"])
        let readable = GraphLibraryEntry(file: "graph-1.json", name: "Clouds", order: 1, state: .readable)
        #expect(LabLibraryView.rowLabel(readable) == "Saved graph Clouds")
        #expect(LabLibraryView.identifierNames(readable)
                == ["library-row-graph-1", "library-open-graph-1", "library-rename-graph-1", "library-remove-graph-1"])
        #expect(LabLibraryView.stacksButtons(.accessibility1) && !LabLibraryView.stacksButtons(.large))
    }
}
