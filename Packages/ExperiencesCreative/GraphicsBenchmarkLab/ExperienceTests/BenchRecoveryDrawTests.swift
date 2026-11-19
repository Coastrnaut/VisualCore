// BenchRecoveryDrawTests — feature 178 (A24-P06) T-A24-604 (FR-A24-603; SC-A24-602). Short runs only (well under 10 s,
// no sleep, no wall-clock assertion, synthetic frame times). Through the one app's session host on the simulator, over
// a temporary experience storage (`BenchStoragePlace`, its folder and defaults suite removed afterwards): two runs of
// the opening case (quads) are started, stopped and saved through the presenter, which writes `result-1.json`,
// `result-2.json` and `results.json`; a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `BenchDrawError.injected` once) fails the session with that error's message and leaves every storage file
// byte for byte, also after the session is closed. A new session over the same storage lists both results and opens
// each equal to the saved run, and neither listing, opening nor drawing writes anything.
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// A drawing failure fails the session, keeps every stored file and a new session reopens both results.
@MainActor
@Suite(.serialized) struct BenchRecoveryDrawTests {
    /// Opens Graphics Benchmark Lab in `session` with its results in `storage` and its exports through `exporter`,
    /// lays the view out at 64 × 48 points, pins the quality to level 0 and draws one frame at the synthetic time 0.
    private func open(_ session: ExperienceSession, storage: ExperienceStorage,
                      exporter: ResultExporter) async throws -> ExperienceShell<BenchPresenter> {
        if session.qualityPin == nil { session.qualityPin = 0 }
        let id = BenchTest.id
        var made: ExperienceShell<BenchPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = GraphicsBenchmarkLabExperience.make(id: id, storage: storage, exporter: exporter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let shell = try #require(made)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 64, height: 48))
        view.layoutIfNeeded()
        try BenchTest.draw(session, shell, at: 0)
        return shell
    }

    /// Starts a run at `start`, draws `count` frames half a second apart, stops it, draws one frame and saves it;
    /// returns the saved file's number and the ended run.
    private func runAndSave(_ session: ExperienceSession, _ shell: ExperienceShell<BenchPresenter>, from start: Double,
                            count: Int) throws -> (n: Int, run: BenchmarkRun) {
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: start, step: 0.5, count: count))
        BenchTest.accept(shell, "run.stop")
        try BenchTest.draw(session, shell, at: start + Double(count) * 0.5)
        #expect(shell.presenter.recorder.state == .stopped)
        let run = try #require(shell.presenter.recorder.runRecord(), "the stopped run has a record")
        let n = try #require(ResultTest.value(shell.presenter.saveResult()))
        return (n, run)
    }

    @Test func aFailedDrawLeavesTheResultsAndANewSessionOpensThem() async throws {
        let place = try BenchStoragePlace("recovery-draw")
        defer { place.remove() }
        let exporter = ResultTest.exporter("recovery-draw")
        defer { exporter.clear() }

        let first = ExperienceSession()
        let shell = try await open(first, storage: place.storage, exporter: exporter)
        #expect(place.storage.list().isEmpty, "nothing is written at open")
        let one = try runAndSave(first, shell, from: 10, count: 9)
        let two = try runAndSave(first, shell, from: 20, count: 7)
        #expect(one.n == 1 && two.n == 2)
        try BenchTest.draw(first, shell, times: [30, 30.5])
        let saved = try place.contents()
        #expect(Set(saved.keys) == ["result-1.json", "result-2.json", ResultLibrary.indexFile],
                "two results and the index")

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A24-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: BenchDrawError.injected), "the injected error's message")
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
        let reopened = try await open(second, storage: place.storage, exporter: exporter)
        try BenchTest.draw(second, reopened, times: [1, 1.5])
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let presenter = reopened.presenter
        presenter.showResults()
        let files = presenter.mirror.resultEntries.map(\.file)
        #expect(files == ["result-2.json", "result-1.json"], "both results are listed, newest first")
        #expect(!presenter.mirror.resultsReadOnly)
        for entry in presenter.mirror.resultEntries {
            #expect(entry.isReadable, "\(entry.file) is readable")
        }
        let openedOne = try #require(ResultTest.value(presenter.openResult(file: "result-1.json")))
        let sameOne = openedOne.run == one.run
        #expect(sameOne, "the first result opens equal to the saved run")
        try BenchTest.draw(second, reopened, at: 2)
        let openedTwo = try #require(ResultTest.value(presenter.openResult(file: "result-2.json")))
        let sameTwo = openedTwo.run == two.run
        #expect(sameTwo, "the second result opens equal to the saved run")
        try BenchTest.draw(second, reopened, at: 2.5)
        #expect(second.state == .running && second.failure == nil)
        #expect(try place.contents() == saved, "listing, opening and drawing write nothing")
    }
}
