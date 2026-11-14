// ScopeSessionTests — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121, FR-A08-122; story 1 scenarios 1, 2 and
// 4; story 2 scenario 4; edge cases). The A08 adapter inside the one app's session host on the simulator, short runs
// only (each test well under 10 s, no wall-clock assertion): the first frame acquires a triggered window of the real
// 1 kHz test signal (480 samples at 1 ms/div holding 10 ± 0.1 periods, starting at the rising zero crossing, the right
// channel at 1.5 kHz) and draws at most one segment per displayed sample, described in words; gain and timebase change
// the window; waveform and frequency restart the source; a flat line never triggers (auto: "no trigger"; normal:
// waiting); suspending stops the source and activating starts it on a fresh buffer; a denied microphone keeps the
// previous source with a message and the offer of the test signal; a granted microphone is read as one channel; an
// undecodable file keeps the previous source.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class ScopeSessionTests: XCTestCase {
    private func core(_ shell: ExperienceShell<ScopePresenter>) throws -> ScopeCore {
        try XCTUnwrap(shell.engine.core)
    }

    func testTheFirstFrameShowsATriggeredTenPeriodWindowOfTheTestSignal() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertEqual(presenter.activeKey, .testSignal(waveform: 0, frequency: ScopeSettings.defaultFrequencyIndex))
        XCTAssertEqual(presenter.activeChannelCount, 2)
        try ScopeTest.frames(session, 2)
        let window = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(window.sampleRate, 48_000)
        XCTAssertEqual(window.channelCount, 2)
        XCTAssertEqual(window.sampleCount, 480, "10 divisions of 1 ms at 48 kHz")
        XCTAssertTrue(window.triggered)
        XCTAssertFalse(window.partial)
        XCTAssertFalse(window.waiting)
        XCTAssertFalse(window.clipped)
        XCTAssertGreaterThanOrEqual(window.left[0], 0, "starts at the level on the rising slope")
        XCTAssertLessThan(window.left[0], 0.07, "within one sample of the crossing")
        XCTAssertGreaterThan(window.left[1], window.left[0], "rising")
        let periods = try XCTUnwrap(ScopeTest.measuredPeriods(window.left))
        XCTAssertEqual(periods, 10, accuracy: 0.1)
        let right = try XCTUnwrap(ScopeTest.measuredPeriods(window.right))
        XCTAssertEqual(right, 15, accuracy: 0.15, "the right channel runs at 1.5 kHz")
        XCTAssertEqual(presenter.lastSegmentCounts, [479, 479], "one segment per displayed sample")
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        XCTAssertEqual(shell.accessibilitySummary,
                       "Oscilloscope Studio: test signal, sine 1 kHz, 2 channels, 1 ms per division, gain ×1, "
                           + "triggered rising at 0, not clipping.")
        XCTAssertEqual(presenter.mirror.status, "2 channels, triggered rising at 0, not clipping")

        // Consecutive windows start at a rising crossing too, so the trace does not drift.
        for _ in 0..<5 {
            try ScopeTest.frames(session, 1)
            let next = try XCTUnwrap(presenter.lastWindow)
            XCTAssertTrue(next.triggered)
            XCTAssertGreaterThanOrEqual(next.left[0], 0)
            XCTAssertLessThan(next.left[0], 0.07)
        }

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertNil(presenter.activeKey, "the source stops with the scene")
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testGainClipsAndTheTimebaseWidensTheWindow() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        let starts = presenter.startCount
        XCTAssertTrue(shell.handle(control: "gain.select", values: [3]).isAccepted)    // ×5: 0.5 × 5 > full scale
        try ScopeTest.frames(session, 1)
        let clipped = try XCTUnwrap(presenter.lastWindow)
        XCTAssertTrue(clipped.clipped)
        XCTAssertEqual(clipped.displayValues(channel: 0, gain: 5).map { abs($0) }.max(), 1, "clamped at full scale")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("gain ×5, triggered rising at 0, clipping."),
                      shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "gain.select", values: [1]).isAccepted)

        XCTAssertTrue(shell.handle(control: "timebase.select", values: [5]).isAccepted)  // 5 ms/div: 2,400 samples
        let full = try await ScopeTest.frames(session, until: {
            guard let w = presenter.lastWindow else { return false }
            return w.sampleCount == 2_400 && w.triggered
        }, limit: 90)
        XCTAssertTrue(full, "the source writes 4,800 frames within about 0.1 s")
        let wide = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(try XCTUnwrap(ScopeTest.measuredPeriods(wide.left)), 50, accuracy: 0.1)
        XCTAssertLessThanOrEqual(presenter.lastSegmentCounts[0], wide.sampleCount - 1)
        XCTAssertEqual(presenter.startCount, starts, "gain and timebase do not restart the source")
        session.close()
    }

    func testWaveformAndFrequencyRestartTheSource() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        let starts = presenter.startCount
        XCTAssertTrue(shell.handle(control: "signal.frequency", values: [1]).isAccepted)   // 440 Hz
        XCTAssertEqual(presenter.startCount, starts + 1, "restarted at once by the description")
        try ScopeTest.frames(session, 1)
        let window = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(window.sampleCount, 480)
        XCTAssertTrue(window.triggered)
        XCTAssertEqual(try XCTUnwrap(ScopeTest.measuredPeriods(window.left)), 4.4, accuracy: 0.1)

        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [1]).isAccepted)    // square
        XCTAssertEqual(presenter.startCount, starts + 2)
        try ScopeTest.frames(session, 1)
        let square = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(Set(square.left), [0.5, -0.5], "only the high and low levels")
        XCTAssertTrue(shell.accessibilitySummary.contains("test signal, square 440 Hz, 2 channels"))

        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [2]).isAccepted)    // sweep
        XCTAssertEqual(presenter.activeKey, .testSignal(waveform: 2, frequency: -1))
        let sweepStarts = presenter.startCount
        XCTAssertTrue(shell.handle(control: "signal.frequency", values: [3]).isAccepted)
        XCTAssertEqual(presenter.startCount, sweepStarts, "the sweep ignores the frequency")
        XCTAssertTrue(shell.accessibilitySummary.contains("test signal, sweep 100 Hz to 10 kHz"))
        session.close()
    }

    func testAFlatLineNeverTriggersAndNormalModeWaits() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: ScopeTest.flatSources)
        let presenter = shell.presenter
        try ScopeTest.frames(session, 1)
        let free = try XCTUnwrap(presenter.lastWindow)
        XCTAssertFalse(free.triggered)
        XCTAssertFalse(free.waiting)
        XCTAssertEqual(free.sampleCount, 480, "auto mode shows the newest span")
        XCTAssertTrue(shell.accessibilitySummary.contains("no trigger, not clipping."), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "trigger.mode", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        let waiting = try XCTUnwrap(presenter.lastWindow)
        XCTAssertTrue(waiting.waiting)
        XCTAssertTrue(shell.accessibilitySummary.contains("waiting for a rising trigger at 0"),
                      shell.accessibilitySummary)
        session.close()
    }

    func testSuspendingStopsTheSourceAndActivatingStartsItOnAFreshBuffer() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        try ScopeTest.frames(session, 2)
        let source = try XCTUnwrap(presenter.activeStereo as? TestSignalAudioSource)
        let buffer = presenter.stereoBuffer
        let starts = presenter.startCount
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        // The lifecycle watch (every 0.1 s) stops the source; wait for it, bounded.
        for _ in 0..<40 where presenter.activeKey != nil { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNil(presenter.activeKey, "no source runs while suspended")
        XCTAssertTrue(presenter.isSuspended)
        XCTAssertEqual(source.state, .idle)
        let frozen = buffer.totalFrames
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(buffer.totalFrames, frozen, "nothing is written while suspended")

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        try ScopeTest.frames(session, 1)
        XCTAssertFalse(presenter.isSuspended)
        XCTAssertNotNil(presenter.activeKey)
        XCTAssertEqual(presenter.startCount, starts + 1)
        XCTAssertFalse(presenter.stereoBuffer === buffer, "a fresh buffer")
        let window = try XCTUnwrap(presenter.lastWindow)
        XCTAssertLessThan(window.startFrame, 2 * TestSignalAudioSource.blockFrames,
                          "the window holds only samples written after the return")
        XCTAssertTrue(window.triggered)
        session.close()
    }

    func testADeniedMicrophoneKeepsThePreviousSourceAndOffersTheTestSignal() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, permission: .denied)
        let presenter = shell.presenter
        let key = presenter.activeKey
        XCTAssertNotNil(key)
        let result = await presenter.pickSource(.microphone)
        XCTAssertEqual(result, .rejected(.rule(code: ScopeRule.permissionDenied)))
        XCTAssertEqual(try core(shell).state.source, .testSignal, "nothing was sent")
        XCTAssertEqual(presenter.activeKey, key, "the previous source keeps running")
        XCTAssertNil(presenter.activeMono)
        XCTAssertEqual(presenter.mirror.message, ScopePresenter.deniedMessage)
        XCTAssertTrue(presenter.mirror.showsSettingsLink)
        XCTAssertTrue(presenter.mirror.offersTestSignal)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(try XCTUnwrap(presenter.lastWindow).triggered, "the trace goes on")

        // Taking the offer clears the message.
        XCTAssertEqual(presenter.useTestSignal(), .accepted)
        XCTAssertNil(presenter.mirror.message)
        XCTAssertFalse(presenter.mirror.offersTestSignal)
        session.close()
    }

    func testAGrantedMicrophoneIsReadAsOneChannel() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, permission: .granted)
        let presenter = shell.presenter
        let result = await presenter.pickSource(.microphone)
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(try core(shell).state.source, .microphone)
        XCTAssertEqual(presenter.activeKey, .microphone)
        XCTAssertNotNil(presenter.activeMono)
        XCTAssertNil(presenter.activeStereo)
        XCTAssertEqual(presenter.activeChannelCount, 1)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(try XCTUnwrap(presenter.lastWindow).channelCount, 1)
        XCTAssertEqual(presenter.lastSegmentCounts[1], 0, "no second trace for a mono source")
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Oscilloscope Studio: microphone, 1 channel, "),
                      shell.accessibilitySummary)
        session.close()
        XCTAssertNil(presenter.activeMono, "the microphone is released with the scene")
    }

    func testAnUndecodableFileKeepsThePreviousSource() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        let key = presenter.activeKey
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-audio.wav")
        XCTAssertFalse(presenter.chooseFile(url: url))
        XCTAssertEqual(try core(shell).state.source, .testSignal)
        XCTAssertEqual(presenter.activeKey, key)
        XCTAssertEqual(presenter.mirror.message, ScopePresenter.undecodableMessage)
        XCTAssertTrue(presenter.mirror.offersTestSignal)
        XCTAssertFalse(presenter.mirror.showsSettingsLink)
        session.close()
    }
}
