// MusicLabAnalysisTests — feature 048 (A06-P02) T-A06-207 (FR-A06-210–213; SC-A06-205). The analysis inside the one
// app's session host on the simulator, short runs only (each test under 4 s): the demo 1 kHz tone fills its own band
// and reads its level; demo silence leaves every feature at zero and two frames identical; the note sequence shows
// separate beats; changing the source resets the beat; and features never reach the digest.
import XCTest
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering

/// A permission that is never asked (the demo needs none).
@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

@MainActor
final class MusicLabAnalysisTests: XCTestCase {
    private var id: ExperienceID { VisualCoreMusicLabExperience.id ?? ExperienceID(rawValue: "a06.unknown")! }

    private func open(_ session: ExperienceSession) async throws -> ExperienceShell<MusicLabPresenter> {
        let id = self.id
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: GrantedPermission(), factory: .system)
            made = shell
            return shell
        }
        XCTAssertEqual(await session.open(request), .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    /// Waits (bounded) until the running source has written at least one analysis window, then draws a frame.
    private func settle(_ shell: ExperienceShell<MusicLabPresenter>, _ session: ExperienceSession) async throws {
        let ring = shell.presenter.ring
        let start = ring.totalWritten
        for _ in 0..<100 where shell.presenter.ring.totalWritten < start + 2 * MusicLabPresenter.analysisSize {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
    }

    func testTheOneKilohertzToneFillsItsBandAndReadsItsLevel() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        try await settle(shell, session)
        let presenter = shell.presenter
        let features = presenter.lastFeatures
        let extractor = try XCTUnwrap(presenter.extractor)
        let centre = Int((1_000 * Double(extractor.size) / extractor.sampleRate).rounded())
        let band = try XCTUnwrap(extractor.layout.bins.firstIndex { $0.contains(centre) })
        let loudest = try XCTUnwrap(features.bandEnergies.indices.max { features.bandEnergies[$0] < features.bandEnergies[$1] })
        XCTAssertEqual(loudest, band)
        XCTAssertEqual(Double(features.rmsDB), Double(LevelMeter.dBFS(0.5 / 2.squareRoot())), accuracy: 1)
        XCTAssertEqual(presenter.lastDisplay.bars.count, 16)
        XCTAssertEqual(presenter.lastDisplay.bars.indices.max { presenter.lastDisplay.bars[$0] < presenter.lastDisplay.bars[$1] }, band)
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Music Lab: Demo signal, level loud"), summary)
        session.close()
    }

    func testDemoSilenceRestsAtZeroAndDrawsIdenticalFrames() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [3]).isAccepted)
        try await settle(shell, session)
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let features = shell.presenter.lastFeatures
        XCTAssertEqual(features.rms, 0)
        XCTAssertEqual(features.peak, 0)
        XCTAssertEqual(features.flux, 0)
        XCTAssertFalse(features.onset)
        XCTAssertEqual(features.beatEnergy, 0)
        XCTAssertTrue(shell.presenter.lastDisplay.bars.allSatisfy { $0 == 0 })
        let first = host.readPixels()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(host.readPixels(), first, "two frames of silence are identical")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("level quiet."), shell.accessibilitySummary)
        session.close()
    }

    func testTheNoteSequenceShowsSeparateBeats() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let host = try XCTUnwrap(session.renderHost)
        // ≤ 2.5 s of frames, about 60 per second; count rising edges of the beat meter over 0.5.
        var beats = 0, above = false
        for _ in 0..<150 where beats < 3 {
            try await Task.sleep(for: .milliseconds(16))
            XCTAssertTrue(host.renderOneFrame(present: false))
            let isBeat = shell.presenter.lastDisplay.isBeat
            if isBeat, !above { beats += 1 }
            above = isBeat
        }
        XCTAssertGreaterThanOrEqual(beats, 3, "beats in the demo note sequence")
        session.close()
    }

    func testChangingTheSourceResetsTheBeatAndLeavesTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<150 where !shell.presenter.lastDisplay.isBeat {
            try await Task.sleep(for: .milliseconds(16))
            XCTAssertTrue(host.renderOneFrame(present: false))
        }
        XCTAssertTrue(shell.presenter.lastDisplay.isBeat, "a beat was seen first")
        let before = try XCTUnwrap(shell.engine.core)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [3]).isAccepted)
        let digestAfterMode = try XCTUnwrap(shell.engine.core)
        XCTAssertNotEqual(before, digestAfterMode)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertLessThan(shell.presenter.lastFeatures.beatEnergy, 0.5, "the beat restarts from zero")
        // Drawing more frames changes features but never the state.
        let state = try XCTUnwrap(shell.engine.core)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(try XCTUnwrap(shell.engine.core), state)
        session.close()
    }
}
