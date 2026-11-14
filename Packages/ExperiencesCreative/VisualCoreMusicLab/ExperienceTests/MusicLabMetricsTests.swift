// MusicLabMetricsTests — feature 051 (A06-P05) T-A06-508 (FR-A06-510–513; SC-A06-503). Inside the one app's session
// host on the simulator, short runs only: the metric text of the 1 kHz demo tone and of silence; announcements through
// a recording sink, rate-limited while VoiceOver runs and absent while it does not; the host's tier selecting the
// analysis level; each palette changing the Bars picture.
import XCTest
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering
import VisualCoreUI

@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

@MainActor
private final class RecordingSink: AnnouncementSink {
    private(set) var texts: [String] = []
    func announce(_ text: String) { texts.append(text) }
}

@MainActor
final class MusicLabMetricsTests: XCTestCase {
    private func open(_ session: ExperienceSession, sink: RecordingSink, voiceOver: Bool) async throws
        -> ExperienceShell<MusicLabPresenter> {
        let id = try XCTUnwrap(VisualCoreMusicLabExperience.id)
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: GrantedPermission(), factory: .system,
                                                          announcementSink: sink, voiceOverRunning: { voiceOver })
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    private func frames(_ session: ExperienceSession, _ count: Int) async throws {
        for _ in 0..<count {
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            try await Task.sleep(for: .milliseconds(16))
        }
    }

    func testTheMetricTextOfTheToneAndOfSilence() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, sink: RecordingSink(), voiceOver: false)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        try await frames(session, 20)
        let presenter = shell.presenter
        let features = presenter.lastFeatures
        XCTAssertEqual(Double(features.rmsDB), -9.03, accuracy: 1)
        XCTAssertEqual(presenter.lastMetricText,
                       MetricText.make(rmsDB: features.rmsDB,
                                       regionEnergies: MetricText.regionEnergies(bandEnergies: features.bandEnergies),
                                       beat: features.beatEnergy))
        XCTAssertTrue(presenter.lastMetricText.hasSuffix("strongest high-mid, no beat"), presenter.lastMetricText)
        XCTAssertEqual(presenter.mirror.metricText, presenter.lastMetricText)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(presenter.lastMetricText + "."))
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [3]).isAccepted)
        try await frames(session, 20)
        XCTAssertEqual(presenter.lastMetricText, "Level silent, strongest none, no beat")
        session.close()
    }

    func testAnnouncementsAreRateLimitedAndOnlyWithVoiceOver() async throws {
        let silentSink = RecordingSink()
        let quiet = ExperienceSession()
        _ = try await open(quiet, sink: silentSink, voiceOver: false)
        try await frames(quiet, 30)
        XCTAssertTrue(silentSink.texts.isEmpty, "no announcements without VoiceOver")
        quiet.close()

        let sink = RecordingSink()
        let session = ExperienceSession()
        let shell = try await open(session, sink: sink, voiceOver: true)
        // The melody changes its metrics often; ~2.5 s of frames allow at most 2 announcements (0 s and ≥ 2 s).
        try await frames(session, 150)
        XCTAssertGreaterThanOrEqual(sink.texts.count, 1)
        XCTAssertLessThanOrEqual(sink.texts.count, 2, "\(sink.texts)")
        XCTAssertTrue(zip(sink.texts, sink.texts.dropFirst()).allSatisfy { $0 != $1 })
        XCTAssertFalse(shell.presenter.lastMetricText.isEmpty)
        session.close()
    }

    func testTheTierSelectsTheAnalysisLevel() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, sink: RecordingSink(), voiceOver: false)
        try await frames(session, 2)
        XCTAssertEqual(shell.presenter.analysisLevel, 0)
        XCTAssertEqual(shell.presenter.extractor?.size, 1_024)
        // The analysis follows the tier handed to draw: level 2 gives 256-sample windows with 8 bands.
        let host = try XCTUnwrap(session.renderHost)
        shell.presenter.forceTierForTesting = 2
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.presenter.analysisLevel, 2)
        XCTAssertEqual(shell.presenter.extractor?.size, 256)
        XCTAssertEqual(shell.presenter.extractor?.layout.bandCount, 8)
        session.close()
    }

    func testEachPaletteChangesTheBarsPicture() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, sink: RecordingSink(), voiceOver: false)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        let host = try XCTUnwrap(session.renderHost)
        var pictures: [[UInt8]] = []
        for palette in MusicLabPalette.allCases {
            XCTAssertTrue(shell.handle(control: "palette.select", values: [Double(palette.rawValue)]).isAccepted)
            try await frames(session, 10)
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(shell.presenter.lastPalette, palette)
            pictures.append(host.readPixels())
        }
        XCTAssertNotEqual(pictures[0], pictures[1])
        XCTAssertNotEqual(pictures[0], pictures[2])
        XCTAssertNotEqual(pictures[1], pictures[2])
        session.close()
    }
}
