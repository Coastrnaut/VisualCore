// AmbientRecoveryDrawTests — feature 136 (A18-P06) T-A18-604 (FR-A18-603; SC-A18-602; clarification Q4; contracts/
// release.md "Recovery"). Short runs only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's
// session host on the simulator, over a temporary experience storage and a private defaults suite (both removed
// afterwards): two favourites are saved through the session's own library (`favourites.json`, synthetic ids
// `00000000-0000-4000-8000-…`); a drawing failure injected with the presenter's seam (`failNextDraw`, which throws
// `AmbientDrawError.injected` once) fails the session with that error's message and leaves `favourites.json` byte for
// byte, also after the session is closed. A new session over the same storage opens, draws and lists both favourites,
// and opening writes nothing (the file stays byte for byte).
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// A storage over a fresh temporary folder and a private defaults suite; `cleanUp()` removes both.
@MainActor
private struct RecoveryStorage {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let storage: ExperienceStorage

    init(_ name: String) throws {
        suite = "a18.recovery-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: AmbientTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suite)
    }
}

/// Synthetic ids `00000000-0000-4000-8000-<n as 12 digits>`, one per call, starting at `first`.
@MainActor
private final class RecoveryIDs {
    private var next: Int

    /// Ids from `first` on.
    init(first: Int = 1) { next = first }

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

@MainActor
@Suite(.serialized) struct AmbientRecoveryDrawTests {
    /// Opens Ambient Clock in `session` with a favourites library over `storage` (the fixed clock, ids from `ids`),
    /// lays the view out at 200 × 200 points and draws one frame; returns the shell.
    private func open(_ session: ExperienceSession, storage: ExperienceStorage,
                      ids: RecoveryIDs) async throws -> ExperienceShell<AmbientPresenter> {
        let id = AmbientTest.id
        let clock = FixedClock(AmbientFixtures.instant)
        let provider = AmbientEnvironmentBox().provider
        let center = NotificationCenter()
        var made: ExperienceShell<AmbientPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let library = AmbientFavourites(storage: storage, clock: clock, makeID: { ids.make() })
            let shell = AmbientClockExperience.make(id: id, clock: clock, environment: provider, center: center,
                                                    favourites: library)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 200, height: 200))
        view.layoutIfNeeded()
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return try #require(made)
    }

    @Test func aFailedDrawLeavesTheFavouritesAndANewSessionListsThem() async throws {
        let fixture = try RecoveryStorage("draw")
        defer { fixture.cleanUp() }
        let name = AmbientFavourites.fileName

        let first = ExperienceSession()
        let shell = try await open(first, storage: fixture.storage, ids: RecoveryIDs())
        let library = try #require(shell.presenter.favourites)
        #expect(library.entries.isEmpty && library.problems.isEmpty)
        let evening = try ThemePreset(theme: 2, palette: 1, speed: 1.5, motion: true)
        let shapes = try ThemePreset(theme: 3, palette: 2, speed: 0.5, motion: false)
        let savedEvening = try library.save(name: "Evening", preset: evening).get()
        let savedShapes = try library.save(name: "Night shapes", preset: shapes).get()
        #expect(savedEvening.id == RecoveryIDs.id(1) && savedShapes.id == RecoveryIDs.id(2))
        let saved = library.entries
        #expect(saved.count == 2)
        #expect(fixture.storage.exists(name), "favourites.json is written")
        let bytes = try fixture.storage.read(name)
        #expect(try AmbientFavourites.decode(bytes).get() == saved, "the file holds both favourites")

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A18-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: AmbientDrawError.injected), "the injected error's message")
        #expect(failure.message == "The Ambient Clock draw failed: the test seam injected a failure.")
        #expect(failure.stage == .draw)
        #expect(!shell.presenter.failNextDraw, "the seam clears itself")
        #expect(try fixture.storage.read(name) == bytes, "favourites.json is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try fixture.storage.read(name) == bytes, "favourites.json is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await open(second, storage: fixture.storage, ids: RecoveryIDs(first: 3))
        _ = second.renderHost?.renderOneFrame(present: false)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let listed = try #require(reopened.presenter.favourites)
        #expect(listed.problems.isEmpty)
        #expect(listed.entries == saved, "the new session lists both favourites")
        #expect(listed.entries.map(\.name) == ["Evening", "Night shapes"])
        #expect(try fixture.storage.read(name) == bytes, "opening the favourites writes nothing")
    }
}
