// LabRecoveryDrawTests — feature 171 (A23-P06) T-A23-604 (FR-A23-603; SC-A23-602). Short runs only (well under 10 s,
// no sleep, no wall-clock assertion). Through the one app's session host on the simulator, over a temporary experience
// storage (`LabStoragePlace`, its folder and defaults suite removed afterwards): two graphs are saved through the
// presenter ("Sample one", the starter graph, and "Sample two", the starter graph with a Gradient added), which writes
// `graph-1.json`, `graph-2.json` and `library.json`; a drawing failure injected with the presenter's seam
// (`failNextDraw`, which throws `LabDrawError.injected` once) fails the session with that error's message and leaves
// every storage file byte for byte, also after the session is closed. A new session over the same storage lists both
// graphs and opens each with its fingerprint, and neither opening nor drawing writes anything.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

/// A drawing failure fails the session, keeps every stored file and a new session reopens both graphs.
@MainActor
@Suite(.serialized) struct LabRecoveryDrawTests {
    @Test func aFailedDrawLeavesTheLibraryAndANewSessionOpensBothGraphs() async throws {
        let place = try LabStoragePlace("recovery-draw")
        defer { place.remove() }

        let first = ExperienceSession()
        let shell = try await LabTest.open(first, storage: place.storage)
        #expect(place.storage.list().isEmpty, "nothing is written at open")
        let starter = try LabTest.core(shell).graph
        let one = try #require(LabLibraryTest.saved(shell.presenter.save(name: "Sample one")))
        LabTest.accept(shell, "node.add", [3, 40, 300])                 // Gradient 3
        let edited = try LabTest.core(shell).graph
        let two = try #require(LabLibraryTest.saved(shell.presenter.save(name: "Sample two")))
        try LabTest.draw(first, frames: 2)
        let saved = try place.contents()
        #expect(Set(saved.keys) == [one.file, two.file, GraphLibrary.indexFile], "two graphs and the index")

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A23-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: LabDrawError.injected), "the injected error's message")
        #expect(failure.message == "The drawing failed (injected by a test).")
        #expect(failure.stage == .draw)
        let cleared = shell.presenter.failNextDraw
        #expect(!cleared, "the seam clears itself")
        #expect(try place.contents() == saved, "every file is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try place.contents() == saved, "every file is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await LabTest.open(second, storage: place.storage)
        try LabTest.draw(second, frames: 2)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let presenter = reopened.presenter
        let library = try #require(presenter.library)
        let names = library.entries.map(\.name)
        #expect(names == ["Sample two", "Sample one"], "both graphs are listed, newest first")
        let problem = library.indexProblem
        #expect(!library.isReadOnly && problem == nil)
        for entry in library.entries {
            #expect(entry.isReadable, "\(entry.file) is readable")
        }
        #expect(LabLibraryTest.saved(presenter.open(file: one.file))?.name == "Sample one")
        let openedOne = try LabTest.core(reopened).graph
        #expect(LabLibraryTest.fingerprint(openedOne) == LabLibraryTest.fingerprint(starter))
        try LabTest.draw(second)
        #expect(LabLibraryTest.saved(presenter.open(file: two.file))?.name == "Sample two")
        let openedTwo = try LabTest.core(reopened).graph
        #expect(LabLibraryTest.fingerprint(openedTwo) == LabLibraryTest.fingerprint(edited))
        try LabTest.draw(second)
        #expect(second.state == .running && second.failure == nil)
        #expect(try place.contents() == saved, "opening and drawing write nothing")
    }
}
