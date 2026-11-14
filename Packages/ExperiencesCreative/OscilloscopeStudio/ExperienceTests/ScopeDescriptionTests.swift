// Feature 065 (A08-P05) T-A08-505 (FR-A08-520, FR-A08-521; SC-A08-503, SC-A08-504; story 3). The canvas description
// for every view and state, the paced announcements through a recording sink (frames of 1/60 s drawn back to back, so
// the announcement clock moves 1.5 s in 90 frames, no wall clock), and the quality levels: drawn columns and spectrum
// analyses at ½ and ¼ with the digest unchanged; the core declares three levels.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class ScopeDescriptionTests: XCTestCase {
    private func core(_ shell: ExperienceShell<ScopePresenter>) throws -> ScopeCore {
        try XCTUnwrap(shell.presenter.lastCore)
    }

    // MARK: Description

    func testTheDescriptionNamesEveryViewAndState() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: ScopeTest.monoFileSources)
        let presenter = shell.presenter

        // Test signal (demo), waveform view.
        var text = shell.accessibilitySummary
        XCTAssertTrue(text.contains("test signal"), text)
        XCTAssertTrue(text.contains("2 channels"), text)
        XCTAssertTrue(text.contains("waveform view"), text)
        XCTAssertTrue(text.contains("per division"), text)
        XCTAssertTrue(text.contains("not clipping"), text)

        // Clipping.
        XCTAssertTrue(shell.handle(control: "gain.select", values: [3]).isAccepted)
        try ScopeTest.frames(session, 1)
        text = shell.accessibilitySummary
        XCTAssertTrue(text.contains(", clipping"), text)
        XCTAssertTrue(shell.handle(control: "gain.select", values: [1]).isAccepted)

        // XY view.
        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(shell.accessibilitySummary.contains("XY view"), shell.accessibilitySummary)

        // Spectrum view with its readout.
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 1)
        text = shell.accessibilitySummary
        XCTAssertTrue(text.contains("spectrum view"), text)
        XCTAssertTrue(text.contains("relative to full scale") || text.contains("filling"), text)

        // Frozen.
        XCTAssertTrue(shell.handle(control: "display.select", values: [0]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(shell.accessibilitySummary.contains("frozen at 48,000 Hz"), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [0]).isAccepted)

        // Mono source in XY: the mark is named.
        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mono.wav")
        XCTAssertTrue(presenter.chooseFile(url: url))
        try ScopeTest.frames(session, 1)
        text = shell.accessibilitySummary
        XCTAssertTrue(text.contains("1 channel"), text)
        XCTAssertTrue(text.contains("XY needs two channels"), text)
        session.close()
    }

    func testTheSpectrumDescriptionSaysNoSignalWithoutASource() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: ScopeTest.flatSources)
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 1)
        let text = shell.accessibilitySummary
        XCTAssertTrue(text.contains("spectrum view"), text)
        XCTAssertTrue(text.contains("no signal") || text.contains("filling"), text)
        session.close()
    }

    // MARK: Announcements

    func testChangesAreAnnouncedAtMostOncePerIntervalAndOnlyWithVoiceOver() async throws {
        let sink = ScopeRecordingSink()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, announcementSink: sink, voiceOverRunning: { true })
        try ScopeTest.frames(session, 2)
        XCTAssertTrue(sink.texts.isEmpty, "the first frame sets the reference only")

        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(sink.texts, [ScopeAnnouncer.viewChanged(.spectrum)])

        // Rapid changes inside the interval are held, and the last one is released once 1.5 s have passed.
        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(shell.handle(control: "display.select", values: [0]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(sink.texts.count, 1, "nothing inside the interval")
        try ScopeTest.frames(session, 90)
        XCTAssertEqual(sink.texts.count, 2)
        XCTAssertEqual(sink.texts.last, ScopeAnnouncer.viewChanged(.waveform))

        // A freeze right after an announcement waits for the interval, then is announced.
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [1]).isAccepted)
        try ScopeTest.frames(session, 2)
        XCTAssertEqual(sink.texts.count, 2, "held inside the interval")
        try ScopeTest.frames(session, 90)
        XCTAssertEqual(sink.texts.last, ScopeAnnouncer.freeze(true))
        session.close()
    }

    func testNothingIsAnnouncedWithoutVoiceOver() async throws {
        let sink = ScopeRecordingSink()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, announcementSink: sink, voiceOverRunning: { false })
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 100)
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [1]).isAccepted)
        try ScopeTest.frames(session, 100)
        XCTAssertTrue(sink.texts.isEmpty)
        session.close()
    }

    func testARouteChangeAnnouncesTheChannelCount() async throws {
        let sink = ScopeRecordingSink()
        let microphone = ScopeQuietMicrophone(channelCount: 2)
        let factory = ScopeSourceFactory(testSignal: { TestSignalAudioSource(signal: $0) },
                                         file: { _ in throw AudioSourceError.undecodable("test double") },
                                         microphone: { _ in microphone })
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: factory, announcementSink: sink,
                                             voiceOverRunning: { true })
        let picked = await shell.presenter.pickSource(.microphone)
        XCTAssertEqual(picked, .accepted)
        try ScopeTest.frames(session, 100)
        let before = sink.texts.count
        microphone.channelCount = 1
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(sink.texts.count, before + 1)
        XCTAssertTrue(try XCTUnwrap(sink.texts.last).contains(ScopeAnnouncer.channels(1)), sink.texts.description)
        session.close()
    }

    // MARK: Quality levels

    func testTheCoreDeclaresThreeLevels() {
        XCTAssertEqual(ScopeCore.qualityTiers, 3)
        XCTAssertEqual(ScopeQuality.levels.count, ScopeCore.qualityTiers)
    }

    func testLevelsHalveAndQuarterTheColumnsAndAnalysesWithTheSameDigest() async throws {
        var columns: [Int] = []
        var analyses: [Int] = []
        var cores: [ScopeCore] = []
        for level in 0..<3 {
            let session = ExperienceSession()
            let shell = try await ScopeTest.open(session, size: CGSize(width: 320, height: 120))
            shell.presenter.forceTierForTesting = level
            try ScopeTest.frames(session, 1)
            columns.append(shell.presenter.lastColumns)
            XCTAssertEqual(shell.presenter.lastQualityLevel, level)
            XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
            let start = shell.presenter.spectrumAnalyses
            try ScopeTest.frames(session, 16)
            analyses.append(shell.presenter.spectrumAnalyses - start)
            cores.append(try core(shell))
            session.close()
        }
        XCTAssertGreaterThan(columns[0], 4)
        XCTAssertLessThanOrEqual(abs(columns[1] * 2 - columns[0]), 2, "\(columns)")
        XCTAssertLessThanOrEqual(abs(columns[2] * 4 - columns[0]), 4, "\(columns)")
        XCTAssertEqual(analyses[0], 16)
        XCTAssertLessThanOrEqual(abs(analyses[1] - 8), 1, "\(analyses)")
        XCTAssertLessThanOrEqual(abs(analyses[2] - 4), 1, "\(analyses)")
        XCTAssertTrue(cores.allSatisfy { $0 == cores[0] }, "the level never reaches the state, so the digest is equal")
    }
}
