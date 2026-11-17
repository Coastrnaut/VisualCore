// GardenRecoveryDrawTests — feature 150 (A20-P06) T-A20-604 (FR-A20-603; SC-A20-602; clarification Q4; contracts/
// release.md "Recovery"). Short runs only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's
// session host on the simulator, over a temporary experience storage (`GardenStoragePlace`, its folder and defaults
// suite removed afterwards): two gardens are raked and saved through the presenter's library (`garden-1.json`,
// `garden-2.json` and `library.json`); a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `GardenDrawError.injected` once) fails the session with that error's message and leaves the three files byte
// for byte, also after the session is closed. A new session over the same storage opens, draws and lists both
// gardens, and opening writes nothing (the files stay byte for byte).
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct GardenRecoveryDrawTests {
    /// The three files the two saves write.
    static let files = [GardenLibrary.indexFile, GardenLibrary.fileName(1), GardenLibrary.fileName(2)]

    /// The bytes of each of ``files`` in `storage`.
    private func contents(_ storage: ExperienceStorage) throws -> [Data] {
        try Self.files.map { try storage.read($0) }
    }

    @Test func aFailedDrawLeavesTheLibraryAndANewSessionListsIt() async throws {
        let place = try GardenStoragePlace("recovery-draw")
        defer { place.remove() }

        let first = ExperienceSession()
        let shell = try await GardenTest.open(first, storage: place.storage)
        let library = try #require(shell.presenter.library)
        #expect(library.entries.isEmpty && library.indexProblem == nil)
        GardenTest.rake(shell, from: Vec2(0.1, 0.3), to: Vec2(0.9, 0.3))
        let firstSave = shell.presenter.saveGarden(named: "Morning Rake")
        #expect(firstSave.isSuccess, "\(firstSave)")
        GardenTest.rake(shell, from: Vec2(0.2, 0.7), to: Vec2(0.8, 0.6), rake: 1)
        let secondSave = shell.presenter.saveGarden(named: "Evening Rake")
        #expect(secondSave.isSuccess, "\(secondSave)")
        let saved = library.entries
        #expect(saved.map(\.name) == ["Evening Rake", "Morning Rake"], "two gardens, newest first")
        #expect(saved.map(\.file) == [GardenLibrary.fileName(2), GardenLibrary.fileName(1)])
        #expect(saved.filter(\.isReadable).count == 2)
        for file in Self.files { #expect(place.storage.exists(file), "\(file) is written") }
        let bytes = try contents(place.storage)

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A20-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: GardenDrawError.injected), "the injected error's message")
        #expect(failure.message == "The Digital Zen Garden draw failed: the test seam injected a failure.")
        #expect(failure.stage == .draw)
        #expect(!shell.presenter.failNextDraw, "the seam clears itself")
        #expect(try contents(place.storage) == bytes, "the library's files are unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try contents(place.storage) == bytes, "the library's files are unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await GardenTest.open(second, storage: place.storage)
        _ = second.renderHost?.renderOneFrame(present: false)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let listed = try #require(reopened.presenter.library)
        #expect(listed.indexProblem == nil && !listed.isReadOnly)
        #expect(listed.entries == saved, "the new session lists both gardens")
        #expect(try contents(place.storage) == bytes, "opening the library writes nothing")
    }
}

private extension Result {
    /// Whether the result is a success.
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
