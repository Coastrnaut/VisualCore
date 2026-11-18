// StudioRecoveryDrawTests — feature 164 (A22-P06) T-A22-604 (FR-A22-603; SC-A22-602; clarification Q4). Short runs
// only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's session host on the simulator, over
// a temporary experience storage (`StudioStoragePlace`, its folder and defaults suite removed afterwards): two
// projects are saved through the presenter ("Sample one", the Gradient template, and "Sample two", the fixed source),
// which writes `project-1.json`, `project-2.json` and `library.json`; a drawing failure injected with the presenter's
// seam (`failNextDraw`, which throws `StudioDrawError.injected` once) fails the session with that error's message and
// leaves every storage file byte for byte, also after the session is closed. A new session over the same storage lists
// both projects and opens each with its source, and neither opening nor drawing writes anything.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct StudioRecoveryDrawTests {
    @Test func aFailedDrawLeavesTheLibraryAndANewSessionOpensBothProjects() async throws {
        let place = try StudioStoragePlace("recovery-draw")
        defer { place.remove() }

        let first = ExperienceSession()
        let shell = try await PresenterLibraryTests.open(first, storage: place.storage)
        #expect(place.storage.list().isEmpty, "nothing is written at open")
        let gradient = shell.presenter.document.source
        let one = try #require(StudioLibraryTest.saved(shell.presenter.saveProject(name: "Sample one")))
        try StudioTest.run(first, shell, source: StudioTest.fixedSource)
        let two = try #require(StudioLibraryTest.saved(shell.presenter.saveProject(name: "Sample two")))
        try StudioTest.draw(first, frames: 2)
        let saved = try place.contents()
        #expect(Set(saved.keys) == [one.file, two.file, ProjectLibrary.indexFile], "two projects and the index")

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A22-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: StudioDrawError.injected), "the injected error's message")
        #expect(failure.message == "The Shader Studio draw failed: the test seam injected a failure.")
        #expect(failure.stage == .draw)
        #expect(!shell.presenter.failNextDraw, "the seam clears itself")
        #expect(try place.contents() == saved, "every file is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try place.contents() == saved, "every file is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await PresenterLibraryTests.open(second, storage: place.storage)
        try StudioTest.draw(second, frames: 2)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let presenter = reopened.presenter
        let library = try #require(presenter.library)
        #expect(library.entries.map(\.name) == ["Sample two", "Sample one"], "both projects are listed, newest first")
        #expect(library.entries.allSatisfy(\.isReadable) && !library.isReadOnly && library.indexProblem == nil)
        guard case .success(let openedOne) = presenter.openProject(one.file) else {
            Issue.record("Sample one does not open")
            return
        }
        #expect(openedOne.project.source == gradient && presenter.document.source == gradient)
        try StudioTest.draw(second)
        guard case .success(let openedTwo) = presenter.openProject(two.file) else {
            Issue.record("Sample two does not open")
            return
        }
        #expect(openedTwo.project.source == StudioTest.fixedSource)
        #expect(presenter.document.source == StudioTest.fixedSource)
        try StudioTest.draw(second)
        #expect(second.state == .running && second.failure == nil)
        #expect(try place.contents() == saved, "opening and drawing write nothing")
    }
}
