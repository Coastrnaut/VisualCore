// WallpaperRecoveryDrawTests — feature 143 (A19-P06) T-A19-604 (FR-A19-603; SC-A19-602; clarification Q4; contracts/
// release.md "Recovery"). Short runs only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's
// session host on the simulator, over a temporary experience storage (`TemporaryWallpaperStorage`, its folder and
// defaults suite removed afterwards) and a private export folder: two exports are written through the presenter's own
// export job (a flat renderer, the fixed clock) and recorded in `history.json`; a drawing failure injected with the
// presenter's seam (`failNextDraw`, which throws `WallpaperDrawError.injected` once) fails the session with that
// error's message and leaves `history.json` byte for byte, also after the session is closed. A new session over the
// same storage opens, draws and lists both entries, and opening writes nothing (the file stays byte for byte).
import Foundation
import Testing
import UIKit
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct WallpaperRecoveryDrawTests {
    /// The fixed instant of the tests: 2026-11-17 12:00:00 UTC.
    static let instant = Date(timeIntervalSince1970: 1_794_916_800)

    /// Opens Living Wallpapers in `session` with a history over `storage` (the fixed `clock`) and the export attempt
    /// `stillExport`, lays the view out at 120 × 200 points and draws one frame; returns the shell.
    private func open(_ session: ExperienceSession, storage: ExperienceStorage, clock: FixedClock,
                      stillExport: StillExport) async throws -> ExperienceShell<WallpaperPresenter> {
        let id = WallpaperTest.id
        var made: ExperienceShell<WallpaperPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let history = HistoryStore(storage: storage, clock: clock)
            let shell = LivingWallpapersExperience.make(id: id, stillExport: stillExport, history: history)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 120, height: 200))
        view.layoutIfNeeded()
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return try #require(made)
    }

    @Test func aFailedDrawLeavesTheHistoryAndANewSessionListsIt() async throws {
        let fixture = try TemporaryWallpaperStorage("recovery-draw")
        defer { fixture.remove() }
        let name = HistoryStore.fileName
        let clock = FixedClock(Self.instant)
        let export = WallpaperTest.exporter("recovery-draw")
        defer { export.folder.removeAll() }

        let first = ExperienceSession()
        let shell = try await open(first, storage: fixture.storage, clock: clock, stillExport: export)
        let history = try #require(shell.presenter.history)
        #expect(history.history.entries.isEmpty && history.problem == nil)
        await shell.presenter.job.start(project: SaveTest.smallProject(.jpeg), maxEdge: 4096,
                                        render: SaveTest.flatRender)
        #expect(shell.presenter.job.output != nil, "\(shell.presenter.job.state)")
        clock.advance(by: 60)
        await shell.presenter.job.start(project: SaveTest.smallProject(.png), maxEdge: 4096,
                                        render: SaveTest.flatRender)
        #expect(shell.presenter.job.output != nil, "\(shell.presenter.job.state)")
        let saved = history.history.entries
        #expect(saved.count == 2, "two exports are recorded")
        #expect(saved.map(\.format) == [.png, .jpeg], "newest first")
        #expect(saved.map(\.madeAt) == [Self.instant.timeIntervalSince1970 + 60, Self.instant.timeIntervalSince1970])
        #expect(fixture.storage.exists(name), "history.json is written")
        let bytes = try fixture.storage.read(name)
        #expect(ExportHistory.decode(bytes) == .success(history.history), "the file holds both entries")

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A19-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: WallpaperDrawError.injected), "the injected error's message")
        #expect(failure.message == "The Living Wallpapers draw failed: the test seam injected a failure.")
        #expect(failure.stage == .draw)
        #expect(!shell.presenter.failNextDraw, "the seam clears itself")
        #expect(try fixture.storage.read(name) == bytes, "history.json is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try fixture.storage.read(name) == bytes, "history.json is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await open(second, storage: fixture.storage, clock: clock, stillExport: export)
        _ = second.renderHost?.renderOneFrame(present: false)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let listed = try #require(reopened.presenter.history)
        #expect(listed.problem == nil)
        #expect(listed.history.entries == saved, "the new session lists both entries")
        #expect(listed.shown == saved)
        #expect(try fixture.storage.read(name) == bytes, "opening the history writes nothing")
    }
}
