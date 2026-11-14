// ScopeSessionTests — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121, FR-A08-122; story 1 scenarios 1, 2 and
// 4; story 2 scenario 4; edge cases). The A08 adapter inside the one app's session host on the simulator, short runs
// only (each test well under 10 s, no wall-clock assertion): the first frame acquires a triggered window of the real
// 1 kHz test signal (480 samples at 1 ms/div holding 10 ± 0.1 periods, starting at the rising zero crossing, the right
// channel at 1.5 kHz) and draws at most one segment per displayed sample, described in words; gain and timebase change
// the window; waveform and frequency restart the source; a flat line never triggers (auto: "no trigger"; normal:
// waiting); suspending stops the source and activating starts it on a fresh buffer; a denied microphone keeps the
// previous source with a message and the offer of the test signal; a granted microphone is read as one channel; an
// undecodable file keeps the previous source.
// Feature 062 (A08-P02) T-A08-206 (FR-A08-210–213; story 1 scenarios 1–3; story 2 scenario 4): each channel is one
// decimated polyline (at most two points per pixel column, at most two trace nodes per frame); in XY the plotted points
// are exactly `ScopeTrace.xyPoints` of the window's pairs scaled by the gain, one per frame; a mono source in XY keeps
// the waveform with the mark "XY needs two channels" and says so, and a stereo source shows XY again without a new
// choice; the description names the view and the test signal's 2 : 3 ratio.
// Feature 063 (A08-P03) T-A08-303 (FR-A08-301–305; story 1 scenarios 1, 2, 4 and 5; SC-A08-301, SC-A08-302): with the
// synchronous `ScopeBlockSource` (8,192 frames written at start, source time advanced explicitly, no wall clock) the
// spectrum of the 1 kHz test sine reads 1,000 Hz within one bin at −6.02 dBFS within 1.5 dB, of the left channel, as
// one polyline of at most one point per pixel column, and the description and the status carry the readout text; gain
// ×10 leaves the readout unchanged; the flat line says "no signal"; 1,024 written frames say "filling"; the sweep's
// readout rises over 0.3 s of source time.
// Feature 064 (A08-P04) T-A08-403 (FR-A08-401–404, FR-A08-411, FR-A08-412; SC-A08-401–403, SC-A08-405; story 1
// AC1–AC5, story 2; edge cases): with `ScopeBlockSource` (source time advanced explicitly) a frozen window stays
// identical over 60 frames while 61,440 new frames arrive, and unfreezing resumes the newest window; freezing an empty
// window is refused with "Nothing to freeze yet"; a change of source releases the freeze (a waveform change keeps it);
// cursors one period apart on 100 Hz (5 ms/div), 440 Hz (2 ms/div) and 1 kHz (1 ms/div) read `ScopeReadout.time`
// and the expected period and frequency text, and the level cursor reads "0.50 of full scale (−6.0 dBFS)"; the level
// cursor at a clipped value reads "at or beyond full scale"; the spectrum frequency cursor reads "± 11.7 Hz" with a
// level in dBFS; two synthetic pointers pinching ×2 and ×4 step the timebase down one and two values (and pinching in
// steps it up, clamped at the ends), pinch in the spectrum view changes nothing and shows the hint; one finger drags
// the nearest cursor; a restored frozen snapshot freezes the next window, also in a new session.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

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
        XCTAssertEqual(presenter.lastTraceNodeCount, 2, "one polyline per channel")
        XCTAssertGreaterThanOrEqual(presenter.lastColumns, 1)
        XCTAssertLessThanOrEqual(presenter.lastColumns, ScopePresenter.maxColumns)
        for channel in 0..<2 {
            let reduced = MinMaxDecimator.reduce(window.displayValues(channel: channel, gain: 1),
                                                 columns: presenter.lastColumns)
            XCTAssertEqual(presenter.lastPointCounts[channel], 2 * reduced.count, "min and max per column")
            XCTAssertLessThanOrEqual(presenter.lastPointCounts[channel], 2 * presenter.lastColumns,
                                     "at most two points per pixel column")
        }
        XCTAssertFalse(presenter.lastShowsXY)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        XCTAssertEqual(shell.accessibilitySummary,
                       "Oscilloscope Studio: test signal, sine 1 kHz, 2 channels, waveform view, 1 ms per division, "
                           + "gain ×1, triggered rising at 0, not clipping.")
        XCTAssertEqual(presenter.mirror.status, "2 channels, triggered rising at 0, not clipping")

        // Consecutive windows start at a rising crossing too, so the trace does not drift.
        for _ in 0..<5 {
            try ScopeTest.frames(session, 1)
            let next = try XCTUnwrap(presenter.lastWindow)
            XCTAssertTrue(next.triggered)
            XCTAssertGreaterThanOrEqual(next.left[0], 0)
            XCTAssertLessThan(next.left[0], 0.07)
            XCTAssertLessThanOrEqual(presenter.lastTraceNodeCount, 2)
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
        XCTAssertLessThanOrEqual(presenter.lastPointCounts[0], 2 * presenter.lastColumns)
        XCTAssertEqual(presenter.lastPointCounts[0],
                       2 * MinMaxDecimator.reduce(wide.displayValues(channel: 0, gain: 1),
                                                  columns: presenter.lastColumns).count)
        XCTAssertLessThan(presenter.lastPointCounts[0], 2 * wide.sampleCount, "2,400 samples reduced to the columns")
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

    /// Feature 062 (A08-P02) T-A08-207 (FR-A08-213; SC-A08-204): a level the 0.5 test signal never reaches is a
    /// missing crossing: auto mode shows the newest span and says "no trigger"; after one triggered window at 0,
    /// normal mode keeps that window and says "waiting".
    func testAMissingCrossingNeverTriggersAndNormalModeKeepsTheLastTrace() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        try ScopeTest.frames(session, 1)
        let triggered = try XCTUnwrap(presenter.lastWindow)
        XCTAssertTrue(triggered.triggered, "the level 0 crossing triggers first")
        XCTAssertTrue(shell.handle(control: "trigger.level", values: [0.9]).isAccepted)
        try ScopeTest.frames(session, 1)
        let free = try XCTUnwrap(presenter.lastWindow)
        XCTAssertFalse(free.triggered)
        XCTAssertFalse(free.waiting)
        XCTAssertTrue(shell.accessibilitySummary.contains("no trigger"), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "trigger.level", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "trigger.mode", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        let kept = try XCTUnwrap(presenter.lastWindow)
        XCTAssertTrue(kept.triggered)
        XCTAssertTrue(shell.handle(control: "trigger.level", values: [0.9]).isAccepted)
        try ScopeTest.frames(session, 1)
        let waiting = try XCTUnwrap(presenter.lastWindow)
        XCTAssertTrue(waiting.waiting)
        XCTAssertEqual(waiting.startFrame, kept.startFrame, "the last triggered trace stays")
        XCTAssertTrue(shell.accessibilitySummary.contains("waiting"), shell.accessibilitySummary)
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
        XCTAssertEqual(presenter.lastPointCounts[1], 0, "no second trace for a mono source")
        XCTAssertLessThanOrEqual(presenter.lastTraceNodeCount, 1)
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

    func testXYPlotsTheScaledSamplePairsOfTheStereoTestSignal() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        XCTAssertEqual(try core(shell).state.display, .xy)
        for gainIndex in [1.0, 2.0] {    // ×1, then ×2 (0.5 × 2 reaches full scale)
            XCTAssertTrue(shell.handle(control: "gain.select", values: [gainIndex]).isAccepted)
            try ScopeTest.frames(session, 2)
            let window = try XCTUnwrap(presenter.lastWindow)
            let gain = try core(shell).state.gain
            XCTAssertEqual(window.channelCount, 2)
            XCTAssertTrue(presenter.lastShowsXY)
            XCTAssertEqual(presenter.lastXYPoints,
                           ScopeTrace.xyPoints(left: window.left, right: window.right, gain: gain,
                                               in: presenter.lastXYSquare),
                           "every point is (left × gain, right × gain) of one frame")
            XCTAssertEqual(presenter.lastXYPoints.count, window.sampleCount, "one point per frame")
            XCTAssertEqual(presenter.lastTraceNodeCount, 1, "one XY polyline")
            XCTAssertEqual(presenter.lastPointCounts, [0, 0])
            let square = presenter.lastXYSquare
            XCTAssertGreaterThan(square.side, 0)
            for point in presenter.lastXYPoints {
                XCTAssertTrue(point.x >= square.x && point.x <= square.x + square.side
                              && point.y >= square.y && point.y <= square.y + square.side)
            }
        }
        XCTAssertNil(presenter.mirror.displayNote)
        XCTAssertEqual(presenter.mirror.display, .xy)
        XCTAssertTrue(presenter.mirror.status.hasPrefix("XY view, 2 channels, "), presenter.mirror.status)
        XCTAssertTrue(shell.accessibilitySummary.contains(
            "2 channels, XY view, left 1 kHz against right 1.5 kHz (2 : 3), 1 ms per division"),
            shell.accessibilitySummary)

        // Back to the waveform: two polylines again.
        XCTAssertTrue(shell.handle(control: "display.select", values: [0]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertFalse(presenter.lastShowsXY)
        XCTAssertTrue(presenter.lastXYPoints.isEmpty)
        XCTAssertEqual(presenter.lastTraceNodeCount, 2)
        XCTAssertTrue(shell.accessibilitySummary.contains("2 channels, waveform view, "), shell.accessibilitySummary)
        session.close()
    }

    func testAMonoSourceInXYFallsBackWithTheMarkAndAStereoSourceShowsXYAgain() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: ScopeTest.monoFileSources)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(presenter.lastShowsXY, "the stereo test signal shows XY")

        // A mono source while XY is chosen: the waveform with the mark, and the view stays XY.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mono.wav")
        XCTAssertTrue(presenter.chooseFile(url: url))
        XCTAssertEqual(try core(shell).state.source, .file)
        XCTAssertEqual(presenter.activeChannelCount, 1)
        try ScopeTest.frames(session, 2)
        let mono = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(mono.channelCount, 1)
        XCTAssertFalse(presenter.lastShowsXY, "a mono source never enters XY")
        XCTAssertTrue(presenter.lastXYPoints.isEmpty)
        XCTAssertGreaterThan(presenter.lastPointCounts[0], 0, "the waveform is drawn")
        XCTAssertEqual(presenter.lastPointCounts[1], 0)
        XCTAssertEqual(presenter.lastTraceNodeCount, 1)
        XCTAssertEqual(try core(shell).state.display, .xy, "the chosen view stays XY")
        XCTAssertEqual(presenter.mirror.displayNote, "XY needs two channels")
        XCTAssertTrue(presenter.mirror.status.hasPrefix("XY needs two channels, 1 channel, "), presenter.mirror.status)
        XCTAssertTrue(shell.accessibilitySummary.contains("1 channel, XY needs two channels, waveform view, "),
                      shell.accessibilitySummary)

        // Back to a stereo source without a new view choice: XY again.
        XCTAssertEqual(presenter.useTestSignal(), .accepted)
        try ScopeTest.frames(session, 2)
        let stereo = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(stereo.channelCount, 2)
        XCTAssertTrue(presenter.lastShowsXY)
        XCTAssertEqual(presenter.lastXYPoints.count, stereo.sampleCount)
        XCTAssertLessThanOrEqual(presenter.lastTraceNodeCount, 2)
        XCTAssertNil(presenter.mirror.displayNote)
        XCTAssertTrue(shell.accessibilitySummary.contains("2 channels, XY view, "), shell.accessibilitySummary)
        session.close()
    }

    func testTheSpectrumReadsTheOneKilohertzTestSineAndIgnoresTheGain() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        XCTAssertEqual(try core(shell).state.display, .spectrum)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.stereoBuffer.totalFrames, 8_192, "the double wrote its frames at start only")
        let readout = try XCTUnwrap(presenter.lastReadout)
        XCTAssertEqual(readout.validity, .valid)
        let frequency = try XCTUnwrap(readout.frequency)
        XCTAssertLessThanOrEqual(abs(frequency - 1_000), 48_000.0 / 4_096, "within one bin")
        let level = try XCTUnwrap(readout.levelDB)
        XCTAssertLessThanOrEqual(abs(level - 20 * log10(0.5)), 1.5, "about −6 dBFS")
        XCTAssertTrue(readout.text.hasPrefix("peak "), readout.text)
        XCTAssertTrue(readout.text.hasSuffix(" dBFS, relative to full scale"), readout.text)

        // One polyline, at most one point per pixel column; no waveform or XY trace.
        XCTAssertGreaterThan(presenter.lastSpectrumColumns, 0)
        XCTAssertGreaterThan(presenter.lastSpectrumPointCount, 1)
        XCTAssertLessThanOrEqual(presenter.lastSpectrumPointCount, presenter.lastSpectrumColumns)
        XCTAssertEqual(presenter.lastTraceNodeCount, 1)
        XCTAssertFalse(presenter.lastShowsXY)
        XCTAssertEqual(presenter.lastPointCounts, [0, 0])

        // The status and the description carry the readout verbatim.
        XCTAssertTrue(presenter.mirror.status.hasPrefix("spectrum view, left channel, " + readout.text),
                      presenter.mirror.status)
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.contains("2 channels, spectrum view, left channel, "), summary)
        XCTAssertTrue(summary.contains(readout.text), summary)
        XCTAssertEqual(presenter.lastReadout, readout, "the description analyses the same frames")

        // The spectrum is not scaled by the display gain.
        XCTAssertTrue(shell.handle(control: "gain.select", values: [4]).isAccepted)
        XCTAssertEqual(try core(shell).state.gain, 10)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.lastReadout, readout, "gain ×10 leaves the readout unchanged")
        XCTAssertTrue(shell.accessibilitySummary.contains(readout.text))
        session.close()
    }

    func testTheSpectrumSaysFillingBeforeFourThousandNinetySixFrames() async throws {
        let sources = ScopeBlockSources(initialFrames: 1_024)
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.stereoBuffer.totalFrames, 1_024)
        let readout = try XCTUnwrap(presenter.lastReadout)
        XCTAssertEqual(readout.validity, .filling)
        XCTAssertNil(readout.frequency)
        XCTAssertNil(readout.levelDB)
        XCTAssertEqual(readout.text, "filling")
        XCTAssertTrue(shell.accessibilitySummary.contains("spectrum view, left channel, "), shell.accessibilitySummary)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(", filling."), shell.accessibilitySummary)

        // Once 4,096 frames are written the readout carries a value.
        try XCTUnwrap(sources.last).advance(3_072)
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.lastReadout?.validity, .valid)
        session.close()
    }

    func testTheSpectrumOfAFlatLineSaysNoSignal() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: ScopeTest.flatSources)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        // The real-time flat source writes 1,024 frames at start and the rest at real-time pace (about 64 ms more).
        let reached = try await ScopeTest.frames(session, until: { presenter.lastReadout?.validity == .noSignal },
                                                 limit: 60)
        XCTAssertTrue(reached, "readout: \(String(describing: presenter.lastReadout))")
        XCTAssertNil(presenter.lastReadout?.frequency)
        XCTAssertNil(presenter.lastReadout?.levelDB)
        XCTAssertTrue(presenter.mirror.status.hasPrefix("spectrum view, left channel, no signal"),
                      presenter.mirror.status)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(", no signal."), shell.accessibilitySummary)
        session.close()
    }

    func testTheSpectrumReadoutFollowsTheSweep() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        try ScopeTest.frames(session, 1)
        let sweep = try XCTUnwrap(sources.last)
        XCTAssertEqual(sweep.framesWritten, 8_192)
        let early = try XCTUnwrap(presenter.lastReadout)
        XCTAssertEqual(early.validity, .valid)
        let first = try XCTUnwrap(early.frequency)

        // 0.3 s of source time later (14,400 frames at 48 kHz) the peak sits higher.
        sweep.advance(14_400)
        try ScopeTest.frames(session, 1)
        let late = try XCTUnwrap(presenter.lastReadout)
        XCTAssertEqual(late.validity, .valid)
        let second = try XCTUnwrap(late.frequency)
        XCTAssertGreaterThan(second, first + early.binWidth, "the readout rises with the sweep (\(first) → \(second))")
        session.close()
    }

    // MARK: Feature 064 — freeze, cursors, pinch

    func testAFrozenWindowStaysIdenticalWhileFramesArriveAndUnfreezingResumesTheNewest() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [2]).isAccepted, "the sweep changes every window")
        try ScopeTest.frames(session, 1)
        XCTAssertNil(presenter.heldWindow)
        XCTAssertTrue(presenter.setFrozen(true).isAccepted)
        XCTAssertTrue(try core(shell).state.frozen)
        try ScopeTest.frames(session, 1)
        let held = try XCTUnwrap(presenter.heldWindow)
        XCTAssertGreaterThan(held.sampleCount, 0)
        let source = try XCTUnwrap(sources.last)
        let writtenBefore = source.framesWritten
        for frame in 0..<60 {
            source.advance(1_024)
            try ScopeTest.frames(session, 1)
            XCTAssertEqual(presenter.heldWindow, held, "frame \(frame)")
            let shown = try XCTUnwrap(presenter.lastWindow)
            XCTAssertEqual(shown.left, held.left, "frame \(frame)")
            XCTAssertEqual(shown.right, held.right, "frame \(frame)")
            XCTAssertEqual(shown.startFrame, held.startFrame)
            XCTAssertEqual(shown.sampleRate, held.sampleRate)
            XCTAssertEqual(shown.channelCount, held.channelCount)
        }
        XCTAssertGreaterThanOrEqual(source.framesWritten - writtenBefore, 1_024, "the input kept running")
        let live = try XCTUnwrap(presenter.lastLiveWindow)
        XCTAssertGreaterThan(live.startFrame, held.startFrame, "acquisition continued behind the freeze")
        XCTAssertTrue(presenter.mirror.status.hasPrefix("frozen at 48,000 Hz, 2 channels, "), presenter.mirror.status)
        XCTAssertTrue(shell.accessibilitySummary.contains(", frozen at 48,000 Hz, 2 channels."),
                      shell.accessibilitySummary)

        // Unfreezing resumes live drawing from the newest samples.
        XCTAssertTrue(presenter.setFrozen(false).isAccepted)
        source.advance(1_024)
        try ScopeTest.frames(session, 1)
        XCTAssertNil(presenter.heldWindow)
        let resumed = try XCTUnwrap(presenter.lastWindow)
        XCTAssertEqual(resumed, presenter.lastLiveWindow)
        XCTAssertGreaterThan(resumed.startFrame, live.startFrame)
        XCTAssertFalse(shell.accessibilitySummary.contains("frozen"))
        session.close()
    }

    func testFreezingAnEmptyWindowIsRefusedWithAMessage() async throws {
        let sources = ScopeBlockSources(initialFrames: 0)
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.lastLiveWindow?.sampleCount, 0)
        XCTAssertEqual(presenter.setFrozen(true), .rejected(.rule(code: ScopeRule.nothingToFreeze)))
        XCTAssertEqual(presenter.mirror.message, "Nothing to freeze yet")
        XCTAssertFalse(try core(shell).state.frozen)
        // Once samples exist the freeze is taken and the message goes.
        try XCTUnwrap(sources.last).advance(1_024)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(presenter.setFrozen(true).isAccepted)
        XCTAssertNil(presenter.mirror.message)
        try ScopeTest.frames(session, 1)
        XCTAssertNotNil(presenter.heldWindow)
        session.close()
    }

    func testAChangeOfSourceReleasesTheFreezeAndAWaveformChangeKeepsIt() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertNotNil(presenter.heldWindow)
        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [1]).isAccepted)
        await ScopeTest.settle()
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(try core(shell).state.frozen, "a waveform change keeps the freeze")
        XCTAssertNotNil(presenter.heldWindow)

        XCTAssertTrue(shell.handle(control: "source.select", values: [2]).isAccepted)
        XCTAssertNil(presenter.heldWindow, "the held window goes at once")
        await ScopeTest.settle()
        XCTAssertFalse(try core(shell).state.frozen, "the presenter sent freeze.set 0")
        try ScopeTest.frames(session, 1)
        XCTAssertEqual(presenter.activeKey, .microphone)
        XCTAssertNil(presenter.heldWindow)
        XCTAssertEqual(presenter.lastWindow, presenter.lastLiveWindow, "the new source shows live")
        session.close()
    }

    func testCursorsOnePeriodApartReadThePeriodAndTheFrequency() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "cursors.show", values: [1]).isAccepted)
        let cases: [(frequency: Int, timebase: Int, hertz: Double, time: String, text: String)] = [
            (0, 5, 100, "10.0 ms", "100 Hz"), (1, 4, 440, "2.27 ms", "440 Hz"), (2, 3, 1_000, "1.00 ms", "1,000 Hz"),
        ]
        for entry in cases {
            XCTAssertTrue(shell.handle(control: "signal.frequency", values: [Double(entry.frequency)]).isAccepted)
            XCTAssertTrue(shell.handle(control: "timebase.select", values: [Double(entry.timebase)]).isAccepted)
            let state = try core(shell).state
            let span = 10 * state.secondsPerDivision
            let a = 0.2, b = 0.2 + 1 / entry.hertz / span
            XCTAssertTrue(shell.handle(control: "cursor.a", values: [a]).isAccepted)
            XCTAssertTrue(shell.handle(control: "cursor.b", values: [b]).isAccepted)
            try ScopeTest.frames(session, 1)
            let window = try XCTUnwrap(presenter.lastWindow)
            XCTAssertEqual(window.sampleRate, 48_000)
            let spanSamples = Int((span * 48_000).rounded())
            let expected = ScopeReadout.time(a: a, b: b, spanSeconds: Double(spanSamples) / 48_000,
                                             sampleRate: 48_000)
            XCTAssertEqual(expected.time, entry.time)
            XCTAssertEqual(expected.frequency, entry.text)
            let readout = try XCTUnwrap(presenter.lastCursorReadout)
            XCTAssertEqual(readout, "A–B \(entry.time), \(entry.text); level 0.50 of full scale (−6.0 dBFS)")
            XCTAssertEqual(presenter.mirror.cursorReadout, readout)
            XCTAssertEqual(presenter.lastCursorLineCount, 3, "A, B and the level line")
            XCTAssertTrue(shell.accessibilitySummary.hasSuffix(", cursors " + readout + "."), shell.accessibilitySummary)
        }
        // Hidden cursors: no readout and no lines.
        XCTAssertTrue(shell.handle(control: "cursors.show", values: [0]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertNil(presenter.lastCursorReadout)
        XCTAssertNil(presenter.mirror.cursorReadout)
        XCTAssertEqual(presenter.lastCursorLineCount, 0)
        session.close()
    }

    func testTheLevelCursorOnAClippedValueReadsAtOrBeyondFullScale() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "gain.select", values: [4]).isAccepted)
        XCTAssertTrue(shell.handle(control: "cursors.show", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "cursor.level", values: [1]).isAccepted)
        try ScopeTest.frames(session, 2)
        XCTAssertEqual(presenter.lastWindow?.clipped, true, "×10 clips the 0.5 sine")
        let readout = try XCTUnwrap(presenter.lastCursorReadout)
        XCTAssertTrue(readout.hasSuffix("; level at or beyond full scale"), readout)
        XCTAssertTrue(shell.handle(control: "cursor.level", values: [-1]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertTrue(try XCTUnwrap(presenter.lastCursorReadout).hasSuffix("; level at or beyond full scale"))
        session.close()
    }

    func testTheSpectrumFrequencyCursorReadsItsColumnWithTheBinWidthAndLevel() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "cursors.show", values: [1]).isAccepted)
        // The 1 kHz test sine's place on the log axis from 20 Hz to 24 kHz.
        let position = log10(1_000.0 / 20) / log10(24_000.0 / 20)
        XCTAssertTrue(shell.handle(control: "cursor.frequency", values: [position]).isAccepted)
        try ScopeTest.frames(session, 1)
        let readout = try XCTUnwrap(presenter.lastCursorReadout)
        XCTAssertTrue(readout.hasPrefix("frequency "), readout)
        XCTAssertTrue(readout.contains(" Hz ± 11.7 Hz at "), readout)
        XCTAssertTrue(readout.hasSuffix(" dBFS"), readout)
        XCTAssertEqual(presenter.lastCursorLineCount, 1)
        XCTAssertEqual(presenter.mirror.cursorReadout, readout)
        XCTAssertTrue(shell.accessibilitySummary.contains(", cursor " + readout), shell.accessibilitySummary)
        session.close()
    }

    func testThePinchStepsTheTimebaseOncePerDoublingClampedAtTheEnds() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let view = Vec2(160, 120)
        func pinch(from start: Double, to distances: [Double]) {
            shell.handlePointer(ScopeTest.touch(1, .began, 0, 60), viewSize: view)
            shell.handlePointer(ScopeTest.touch(2, .began, start, 60), viewSize: view)
            for distance in distances {
                shell.handlePointer(ScopeTest.touch(2, .moved, distance, 60), viewSize: view)
            }
            shell.handlePointer(ScopeTest.touch(2, .ended, distances.last ?? start, 60), viewSize: view)
            shell.handlePointer(ScopeTest.touch(1, .ended, 0, 60), viewSize: view)
        }
        XCTAssertEqual(try core(shell).state.timebaseIndex, 3, "1 ms/div")
        pinch(from: 100, to: [200])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 2, "×2: 0.5 ms/div")
        pinch(from: 100, to: [200, 400])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 0, "×4: two more steps, 0.1 ms/div")
        pinch(from: 100, to: [200, 400])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 0, "clamped at 0.1 ms/div")
        pinch(from: 400, to: [200])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 1, "×0.5: one step up")
        pinch(from: 400, to: [200, 100])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 3, "×0.25: two steps up")
        pinch(from: 400, to: [300])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 3, "×0.75 is no step")
        XCTAssertTrue(shell.handle(control: "timebase.select", values: [5]).isAccepted)
        pinch(from: 400, to: [200, 100])
        XCTAssertEqual(try core(shell).state.timebaseIndex, 5, "clamped at 5 ms/div")

        // In the spectrum view pinch does nothing and says why.
        XCTAssertTrue(shell.handle(control: "timebase.select", values: [3]).isAccepted)
        XCTAssertTrue(shell.handle(control: "display.select", values: [2]).isAccepted)
        let digest = try shell.engine.digest()
        pinch(from: 100, to: [200, 400])
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(shell.presenter.mirror.hint, ScopePresenter.spectrumPinchHint)
        session.close()
    }

    func testOneFingerDragsTheNearestCursor() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session)
        let view = Vec2(160, 120)
        func x(_ fraction: Double) -> Double { view.x * ScopePresenter.inset + fraction * view.x * 0.88 }
        func y(_ level: Double) -> Double { view.y * ScopePresenter.inset + (1 - level) / 2 * view.y * 0.88 }
        // Hidden cursors: a drag changes nothing.
        let digest = try shell.engine.digest()
        shell.handlePointer(ScopeTest.touch(1, .began, x(0.6), y(0)), viewSize: view)
        shell.handlePointer(ScopeTest.touch(1, .ended, x(0.6), y(0)), viewSize: view)
        XCTAssertEqual(try shell.engine.digest(), digest)

        XCTAssertTrue(shell.handle(control: "cursors.show", values: [1]).isAccepted)
        shell.handlePointer(ScopeTest.touch(1, .began, x(0.7), y(0)), viewSize: view)
        XCTAssertEqual(shell.presenter.dragTarget, .b, "B (0.75) is nearest")
        shell.handlePointer(ScopeTest.touch(1, .moved, x(0.9), y(-0.5)), viewSize: view)
        shell.handlePointer(ScopeTest.touch(1, .ended, x(0.9), y(-0.5)), viewSize: view)
        var state = try core(shell).state
        XCTAssertEqual(state.cursorB, 0.9, accuracy: 1e-9)
        XCTAssertEqual(state.cursorA, 0.25, "the target stays the one chosen at touch-down")
        shell.handlePointer(ScopeTest.touch(1, .began, x(0.5), y(0.45)), viewSize: view)
        XCTAssertEqual(shell.presenter.dragTarget, .level, "the level line (0.5) is nearest")
        shell.handlePointer(ScopeTest.touch(1, .moved, x(0.5), y(-0.25)), viewSize: view)
        shell.handlePointer(ScopeTest.touch(1, .ended, x(0.5), y(-0.25)), viewSize: view)
        state = try core(shell).state
        XCTAssertEqual(state.levelCursor, -0.25, accuracy: 1e-9)
        session.close()
    }

    func testARestoredFrozenSnapshotFreezesTheNextWindow() async throws {
        let sources = ScopeBlockSources()
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, factory: sources.factory)
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "cursors.show", values: [1]).isAccepted)
        let snapshot = try shell.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 3)
        XCTAssertTrue(shell.handle(control: "freeze.set", values: [0]).isAccepted)
        try ScopeTest.frames(session, 1)
        XCTAssertNil(shell.presenter.heldWindow)
        try shell.restore(snapshot)
        try ScopeTest.frames(session, 1)
        XCTAssertNotNil(shell.presenter.heldWindow, "the restored freeze holds the next window")
        session.close()

        // In a new session too.
        let next = ExperienceSession()
        let restored = try await ScopeTest.open(next, factory: ScopeBlockSources().factory)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        XCTAssertTrue(try core(restored).state.frozen)
        try ScopeTest.frames(next, 1)
        let held = try XCTUnwrap(restored.presenter.heldWindow)
        XCTAssertGreaterThan(held.sampleCount, 0)
        XCTAssertNotNil(restored.presenter.lastCursorReadout)
        next.close()
    }
}
