// ScopePresenter — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121, FR-A08-122, FR-A08-130; clarifications
// 2–4; edge cases). Draws Oscilloscope Studio through the host only (the host's context and registry, VisualCore's
// `PrimitiveRenderer` with a `Camera2D`; no context of its own) and owns everything that is not state: the running
// source, the buffer it writes into, the picked file, the microphone permission and the `ScopeAcquisition`.
//
//   - Sources: `sync(_:)` makes the running source match the core's selection on every draw and description (the shell
//     describes the core after each accepted action, so a change takes effect at once). The test signal is a
//     `TestSignalAudioSource` of `testSignal(for:)` (the state's waveform and frequency, amplitude 0.5, the sweep from
//     100 Hz to 10 kHz over 2 s, two channels with the right at 1.5 × the left frequency) and a chosen file a
//     `StereoFileAudioSource`; both write into a `StereoSampleBuffer` of 16,384 frames. The microphone is the shared
//     mono `MicrophoneAudioSource` writing into a `SampleRingBuffer` of 16,384 samples and is read as one channel.
//     Every start gets a fresh buffer and resets the acquisition, so no sample of the previous source (or of the time
//     before a pause) is ever drawn; at most one source runs. A change of source, waveform or frequency restarts it
//     (the sweep ignores the frequency, so a frequency change leaves a running sweep alone).
//   - Microphone (`chooseMicrophone()`): granted sends `source.select 2`; not determined asks the system once and sends
//     it only when allowed; denied or restricted sends nothing, keeps the previous source and shows a message with the
//     way to Settings and the offer of the test signal. A restored microphone selection without access is answered
//     with `source.select 0` after the current frame (never from inside it).
//   - File (`chooseFile(url:)`): the file is opened first (`StereoFileAudioSource` holds its security-scoped access
//     while it lives); an undecodable or moved file keeps the previous source and shows a message with the offer of
//     the test signal. Only then is `source.select 1` sent. The file's name is display state, never core state.
//   - Lifecycle: sources run only between `setup` and `teardown`, never in the background, and not while the
//     experience is suspended: the shell's lifecycle (handed in by `OscilloscopeStudioExperience.make`) is checked on
//     every draw and description and by a 0.1 s main-run-loop watch while the scene is set up, so a suspension stops
//     the source and the return starts it again on a fresh buffer with the acquisition reset.
//   - Drawing: per frame one `SignalWindow` from `ScopeAcquisition` (triggered on channel 0, at most 4,096 samples per
//     channel), a 10 × 8 division grid inside a 6 % inset (the centre lines brighter) and the trace of channel 0 (and of
//     channel 1 in a second colour when the source carries two). The values are `displayValues(channel:gain:)` (× gain,
//     clamped to full scale, so a clipped trace runs along the plot edge); the window's `clipped` flag is reported in
//     the description. (Since A08-P02 the traces are decimated polylines; see below.)
//   - Description: "Oscilloscope Studio: test signal, sine 1 kHz, 2 channels, waveform view, 1 ms per division, gain
//     ×1, triggered rising at 0, not clipping." (source, signal, channels, view since A08-P02, timebase, gain, trigger
//     state, clipping).
//   - Privacy: nothing is recorded, stored or sent; the microphone is never played to the speaker.
//
// Feature 062 (A08-P02) T-A08-206 (FR-A08-210–213; story 1 scenarios 1–3; story 2 scenario 4; clarifications 2–4):
//   - Waveform view: each channel is ONE `.polyline` scene node per frame (no per-segment shapes). The window's
//     `displayValues(channel:gain:)` are reduced by `MinMaxDecimator` to the pixel columns of the trace area (the
//     grid's pixel width, 1…4,096; a partial window covers only its share of the span, so it is drawn from the left
//     without stretching) and drawn as the zig-zag of `ScopeTrace.waveformPoints` (min then max per column): at most
//     two points per column, every peak on screen. The world is pixels from the centre with y up, the same direction
//     as `TracePoint`'s y, so no flip is needed. A channel with a clipped sample is drawn in the clip colour.
//   - XY view (`state.display == .xy`): when the window has two channels, one polyline of `ScopeTrace.xyPoints` of the
//     window's (left × gain, right × gain) pairs inside the largest square centred in the grid; the second trace node
//     is empty. A mono window keeps the waveform view and shows the mark "XY needs two channels" (the controls'
//     `display.status` and the trace status) and says so; the chosen view stays XY, so a stereo source shows XY again
//     without a new choice.
//   - Description: the view is named after the channels ("waveform view", "XY view" and, with the stereo test
//     signal, "left 1 kHz against right 1.5 kHz (2 : 3)"; "XY needs two channels" for a mono window in XY).
//
// Feature 063 (A08-P03) T-A08-303 (FR-A08-301–305, FR-A08-320; story 1; clarifications 2–5; edge cases):
//   - Spectrum view (`state.display == .spectrum`): every drawn frame (and every description) reads the newest 4,096
//     frames of the left (or only) channel from the running source's buffer (`StereoSampleBuffer.latestFrames` or the
//     microphone ring's `latest`), with the buffer's total as the written-frame count; fewer frames are zero-padded by
//     the analyser and the readout says "filling". ONE `SpectrumAnalyzer(size: 4096)` is created on first use and kept.
//     The spectrum is not triggered and not scaled by the display gain. `SpectrumReadout.make` gives the peak readout
//     ("peak 1,000 Hz at −6.0 dBFS, relative to full scale") or the reason none is shown ("no signal", "clipping,
//     level not valid", "filling").
//   - Drawing: the grid nodes carry the spectrum grid instead of the 10 × 8 divisions: vertical lines at the decade
//     marks (100 Hz, 1 kHz, 10 kHz below Nyquist) and at the plot's left and right edges, horizontal lines at the level
//     marks (0 to −100 dBFS every 20 dB); the unused grid nodes are empty. The curve is one `.polyline` of
//     `SpectrumView.points` of the strongest bin per pixel column of the plot (y-up, like the waveform), in the clip
//     colour while the window clips; the second trace node is empty.
//   - Status text and description: "Spectrum view, left channel, <readout>, …" in `trace.status` and "…, 2 channels,
//     spectrum view, left channel, <axes>, <readout>." spoken ("1 channel, spectrum view, …" for a mono source). Levels
//     are always relative to full scale; nothing claims a calibrated measurement.
import Foundation
import SwiftUI
import UIKit
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

/// What the controls show: the display fields of the scope, updated only when one of them changes.
@MainActor
@Observable
final class ScopeMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The chosen source.
    var source: ScopeSource = .testSignal
    /// The source as the status line names it: "Test signal", "Microphone" or the picked file's name.
    var sourceName = ScopeSource.testSignal.displayName
    /// The index of the test waveform.
    var waveformIndex = 0
    /// The index of the test frequency.
    var frequencyIndex = ScopeSettings.defaultFrequencyIndex
    /// The index of the gain.
    var gainIndex = ScopeSettings.defaultGainIndex
    /// The index of the timebase.
    var timebaseIndex = ScopeSettings.defaultTimebaseIndex
    /// The trigger level.
    var triggerLevel = 0.0
    /// The index of the trigger slope.
    var slopeIndex = 0
    /// The index of the trigger mode.
    var modeIndex = 0
    /// The trace status in words (channels, trigger state, clipping).
    var status = ""
    /// The chosen display mode (`display.select`).
    var display: ScopeDisplay = .waveform
    /// The mark shown while XY is chosen but the window has one channel ("XY needs two channels"); nil otherwise.
    var displayNote: String?
    /// A plain message (refused microphone access, an unplayable or moved file, a stopped source); nil when all is
    /// well.
    var message: String?
    /// Whether the message concerns microphone access that only Settings can change.
    var showsSettingsLink = false
    /// Whether the message offers the test signal instead.
    var offersTestSignal = false
    /// Whether the system permission request is open.
    var isRequestingPermission = false
}

/// How the presenter makes its sources; tests replace them with doubles.
struct ScopeSourceFactory {
    /// The test-signal source for a signal.
    var testSignal: @MainActor (TestSignal) -> any StereoAudioSource
    /// The file source for a picked URL; throws for a file the system cannot decode.
    var file: @MainActor (URL) throws -> any StereoAudioSource
    /// The microphone source behind a permission.
    var microphone: @MainActor (any MicrophonePermission) -> any AudioSource

    /// The VisualCoreAudio sources.
    static var system: ScopeSourceFactory {
        ScopeSourceFactory(testSignal: { TestSignalAudioSource(signal: $0) },
                           file: { try StereoFileAudioSource(url: $0) },
                           microphone: { MicrophoneAudioSource(permission: $0) })
    }
}

/// The error of a draw failed on purpose through `ScopePresenter.failNextDraw`.
enum ScopeDrawError: Error, Equatable {
    /// The draw was failed by the test seam.
    case injected
}

/// The presenter of Oscilloscope Studio.
@MainActor
final class ScopePresenter: ExperiencePresenter {
    typealias Core = ScopeCore

    /// The capacity of the two-channel buffer in frames (a window plus one window of lookback always fits).
    nonisolated static let bufferFrames = 16_384
    /// The capacity of the microphone's ring buffer in samples.
    nonisolated static let ringCapacity = 16_384
    /// The amplitude of the test signal (half of full scale).
    nonisolated static let testAmplitude = 0.5
    /// The right channel's frequency ratio of the test signal (2 : 3, the Lissajous figure of the XY view).
    nonisolated static let rightRatio = 1.5
    /// The sweep's start and end frequency and its duration.
    nonisolated static let sweepStart = 100.0, sweepEnd = 10_000.0, sweepDuration = 2.0
    /// The index of the sweep in the waveform table (the frequency picker is hidden for it).
    nonisolated static let sweepIndex = ScopeSettings.index(of: TestSignal.Waveform.sweep)
    /// The number of horizontal and vertical divisions of the grid.
    nonisolated static let horizontalDivisions = 10, verticalDivisions = 8
    /// The inset of the plot from each edge of the view, as a share of the width and the height.
    nonisolated static let inset = 0.06
    /// The trace and grid line widths in pixels.
    nonisolated static let traceWidth = 2.0, gridWidth = 1.0
    /// The background colour (dark blue-black).
    nonisolated static let background: (red: Float, green: Float, blue: Float) = (0.02, 0.03, 0.04)
    /// The grid colour and the brighter centre-line colour.
    nonisolated static let gridColor = Vec4(0.14, 0.18, 0.2, 1), axisColor = Vec4(0.26, 0.32, 0.36, 1)
    /// The trace colours of channel 0 (green) and channel 1 (amber).
    nonisolated static let traceColors = [Vec4(0.35, 1.0, 0.55, 1), Vec4(1.0, 0.75, 0.3, 1)]
    /// The colour of a segment touching a clipped sample (red).
    nonisolated static let clipColor = Vec4(1.0, 0.25, 0.25, 1)
    /// The most pixel columns of the waveform view (the window cap, `TimebaseWindow.maxSamples`).
    nonisolated static let maxColumns = 4_096
    /// The mark of a mono window in the XY view.
    static let xyNeedsStereo = "XY needs two channels"
    /// The words of the spectrum axes and marks (shown in the status text and spoken).
    static let spectrumAxesWords = "frequency 20 Hz to half the sample rate on a logarithmic axis with marks at 100 Hz, "
        + "1 kHz and 10 kHz, level 0 to \u{2212}100 dBFS with marks every 20 dB"
    /// The interval of the lifecycle watch in seconds.
    nonisolated static let watchInterval = 0.1

    /// The message when microphone access is off.
    static let deniedMessage = "Microphone access is off. Allow it for VisualCore in Settings, or use the test signal."
    /// The message when a picked file cannot be played.
    static let undecodableMessage = "This file can't be played. Choose a WAV, AIFF, CAF, M4A or MP3 file, or use the test signal."
    /// The message when a restored session's file is no longer reachable.
    static let fileGoneMessage = "The audio file is no longer available. Choose it again, or use the test signal."

    /// What runs (or should run): the test signal of a waveform and frequency, the picked file or the microphone.
    enum SourceKey: Equatable {
        /// The test signal (`frequency` −1 for the sweep, which ignores it).
        case testSignal(waveform: Int, frequency: Int)
        /// The picked file by pick number.
        case file(pick: Int)
        /// The microphone.
        case microphone
    }

    /// A picked, opened file.
    private struct PickedFile {
        let name: String
        let pick: Int
        let source: any StereoAudioSource
    }

    let experienceID: ExperienceID
    let mirror = ScopeMirror()
    /// The microphone permission (the system's by default; a double in tests).
    let permission: any MicrophonePermission
    /// How the sources are made.
    let factory: ScopeSourceFactory
    /// The port of the shell, set by `OscilloscopeStudioExperience.make`; the presenter sends the source choices
    /// through it.
    weak var port: ExperienceActionPort?
    /// The shell's lifecycle state, set by `OscilloscopeStudioExperience.make`; nil means active.
    var lifecycle: (@MainActor () -> ExperienceLifecycleState?)?

    /// The two-channel buffer of the running test-signal or file source (a fresh one per start).
    private(set) var stereoBuffer = StereoSampleBuffer(capacityFrames: ScopePresenter.bufferFrames)
    /// The ring buffer of the running microphone (a fresh one per start).
    private(set) var ring = SampleRingBuffer(capacity: ScopePresenter.ringCapacity)
    /// The running test-signal or file source, if any.
    private(set) var activeStereo: (any StereoAudioSource)?
    /// The running microphone source, if any.
    private(set) var activeMono: (any AudioSource)?
    /// What the running source was started for.
    private(set) var activeKey: SourceKey?
    /// A key whose start failed; not retried until the selection changes.
    private var failedKey: SourceKey?
    private var pickedFile: PickedFile?
    private var pickCount = 0
    /// The acquisition of the windows (reset with every source start).
    let acquisition = ScopeAcquisition()

    /// True between `setup` and `teardown`.
    private(set) var isLive = false
    /// True while the shell is suspended (the source is stopped).
    private(set) var isSuspended = false
    private var isBackgrounded = false
    private var fallbackScheduled = false
    private var observers: [NSObjectProtocol] = []
    private var watch: Timer?
    /// The core of the last draw or description.
    private(set) var lastCore: ScopeCore?
    /// The window drawn by the last frame; nil before the first frame.
    private(set) var lastWindow: SignalWindow?
    /// The points of each channel's waveform polyline drawn by the last frame (at most two per pixel column; 0 for a
    /// channel not drawn, and for both channels in the XY view).
    private(set) var lastPointCounts = [0, 0]
    /// The pixel columns of the waveform trace area of the last frame (the decimation's column count).
    private(set) var lastColumns = 0
    /// The points of the XY polyline drawn by the last frame (empty unless the XY view was drawn).
    private(set) var lastXYPoints: [TracePoint] = []
    /// The XY square of the last frame in world pixels (x, y of the lower-left corner, side).
    private(set) var lastXYSquare: (x: Double, y: Double, side: Double) = (0, 0, 0)
    /// The trace nodes holding a shape after the last frame (at most two).
    private(set) var lastTraceNodeCount = 0
    /// Whether the last frame drew the XY view (XY chosen and a two-channel window).
    private(set) var lastShowsXY = false
    /// The peak readout of the last spectrum analysis (a drawn spectrum frame or a description in the spectrum view);
    /// nil before the first one and while no source runs.
    private(set) var lastReadout: SpectrumReadout?
    /// The points of the spectrum polyline drawn by the last spectrum frame (at most one per pixel column).
    private(set) var lastSpectrumPointCount = 0
    /// The pixel columns of the spectrum plot of the last spectrum frame.
    private(set) var lastSpectrumColumns = 0
    /// The number of starts of a source since the presenter was created (tests read it).
    private(set) var startCount = 0
    /// Set only by tests; the next draw throws `ScopeDrawError.injected` and clears the flag.
    var failNextDraw = false

    private let clear = ClearColorScene(red: ScopePresenter.background.red, green: ScopePresenter.background.green,
                                        blue: ScopePresenter.background.blue)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "scope")
    private var gridNodes: [SceneNode] = []
    /// The two trace nodes (channel 0 or the XY trace, channel 1), reused every frame.
    private var traceNodes: [SceneNode] = []
    /// The spectrum analyser, created on first use and kept (one FFT setup for the presenter's life).
    private var analyzer: SpectrumAnalyzer?
    /// The read buffers of the spectrum (4,096 frames each, reused).
    private var spectrumLeft = [Float](repeating: 0, count: SpectrumReadout.frameSize)
    private var spectrumRight = [Float](repeating: 0, count: SpectrumReadout.frameSize)
    /// The magnitudes and sample rate of the last spectrum analysis (empty when none ran).
    private var lastMagnitudes: [Float] = []
    private var lastSpectrumRate = TestSignal.defaultSampleRate

    init(experienceID: ExperienceID, permission: any MicrophonePermission, factory: ScopeSourceFactory = .system) {
        self.experienceID = experienceID
        self.permission = permission
        self.factory = factory
        for index in 0..<(Self.horizontalDivisions + 1 + Self.verticalDivisions + 1) {
            let node = SceneNode(id: "g\(index)", z: 0, color: Self.gridColor)
            root.add(node)
            gridNodes.append(node)
        }
        for channel in 0..<2 {
            let node = SceneNode(id: "t\(channel)", z: 1 + channel, color: Self.traceColors[channel])
            root.add(node)
            traceNodes.append(node)
        }
    }

    /// The running source's sample rate (48 kHz when none runs).
    var activeSampleRate: Double { activeStereo?.sampleRate ?? activeMono?.sampleRate ?? TestSignal.defaultSampleRate }

    /// The running source's channel count: the stereo source's (1 or 2), 1 for the microphone, 0 when none runs.
    var activeChannelCount: Int {
        if let activeStereo { return min(max(activeStereo.channelCount, 1), 2) }
        return activeMono == nil ? 0 : 1
    }

    /// The test signal of `state`: its waveform and frequency (the sweep from 100 Hz to 10 kHz over 2 s), amplitude
    /// 0.5 at 48 kHz, two channels with the right at 1.5 × the left frequency.
    nonisolated static func testSignal(for state: ScopeState) -> TestSignal {
        if state.waveform == .sweep {
            return TestSignal(waveform: .sweep, frequency: sweepStart, amplitude: testAmplitude, channelCount: 2,
                              rightRatio: rightRatio, sweepEnd: sweepEnd, sweepDuration: sweepDuration)
        }
        return TestSignal(waveform: state.waveform, frequency: state.frequency, amplitude: testAmplitude,
                          channelCount: 2, rightRatio: rightRatio)
    }

    /// The key of the test signal of `state` (the sweep ignores the frequency).
    nonisolated static func testKey(for state: ScopeState) -> SourceKey {
        let waveform = ScopeSettings.index(of: state.waveform)
        return .testSignal(waveform: waveform, frequency: state.waveform == .sweep ? -1 : state.frequencyIndex)
    }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.enterBackground() }
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isBackgrounded = false }
            },
        ]
        watch?.invalidate()
        watch = Timer.scheduledTimer(withTimeInterval: Self.watchInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkLifecycle() }
        }
        checkLifecycle()
        if let lastCore { sync(lastCore) }
    }

    func draw(_ core: ScopeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw ScopeDrawError.injected
        }
        checkLifecycle()
        sync(core)
        if mirror.message == nil {
            if case .failed(let reason)? = activeStereo?.state ?? activeMono?.state {
                setMessage("The signal stopped: \(reason)", settings: false, offer: core.state.source != .testSignal)
            }
        }
        try clear.render(context, frame: frame)
        let window = acquire(core.state)
        lastWindow = window
        if core.state.display == .spectrum { analyseSpectrum() }
        updateStatus(core.state)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        layOut(width: width, height: height, window: window, state: core.state)
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
    }

    func teardown(_ context: RenderContext) {
        stopActive()
        isLive = false
        watch?.invalidate()
        watch = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        primitives?.release()
        primitives = nil
    }

    // MARK: Acquisition and drawing

    /// The window of the running source for `state` (an empty, partial window when nothing runs).
    private func acquire(_ state: ScopeState) -> SignalWindow {
        if let activeStereo {
            return acquisition.window(from: stereoBuffer, channelCount: activeStereo.channelCount,
                                      sampleRate: activeStereo.sampleRate, state: state)
        }
        if let activeMono {
            return acquisition.window(from: ring, sampleRate: activeMono.sampleRate, state: state)
        }
        return .empty(sampleRate: TestSignal.defaultSampleRate, channelCount: 1,
                      waiting: ScopeSettings.index(of: state.triggerMode) == 1, shortened: false)
    }

    /// Places the grid and the traces for a view of `width` × `height` pixels (world = pixels from the centre, y up).
    private func layOut(width: Double, height: Double, window: SignalWindow, state: ScopeState) {
        let plotWidth = width * (1 - 2 * Self.inset), plotHeight = height * (1 - 2 * Self.inset)
        let left = -plotWidth / 2, bottom = -plotHeight / 2
        var g = 0
        for i in 0...Self.horizontalDivisions {
            let x = left + Double(i) * plotWidth / Double(Self.horizontalDivisions)
            gridNodes[g].primitive = .line(Vec2(x, bottom), Vec2(x, bottom + plotHeight), width: Self.gridWidth)
            gridNodes[g].color = i == Self.horizontalDivisions / 2 ? Self.axisColor : Self.gridColor
            g += 1
        }
        for j in 0...Self.verticalDivisions {
            let y = bottom + Double(j) * plotHeight / Double(Self.verticalDivisions)
            gridNodes[g].primitive = .line(Vec2(left, y), Vec2(left + plotWidth, y), width: Self.gridWidth)
            gridNodes[g].color = j == Self.verticalDivisions / 2 ? Self.axisColor : Self.gridColor
            g += 1
        }
        let gain = state.gain
        for node in gridNodes { node.primitive = nil }
        if state.display == .spectrum {
            layOutSpectrum(rect: (x: left, y: bottom, width: plotWidth, height: plotHeight))
            lastTraceNodeCount = traceNodes.filter { $0.primitive != nil }.count
            return
        }
        if state.display == .xy, window.channelCount == 2 {
            let side = min(plotWidth, plotHeight)
            let square = (x: -side / 2, y: -side / 2, side: side)
            let points = ScopeTrace.xyPoints(left: window.left, right: window.right, gain: gain, in: square)
            traceNodes[0].primitive = points.isEmpty
                ? nil : Primitive.polyline(points.map(Self.vec), width: Self.traceWidth)
            traceNodes[0].color = window.clipped ? Self.clipColor : Self.traceColors[0]
            traceNodes[1].primitive = nil
            lastXYPoints = points
            lastXYSquare = square
            lastPointCounts = [0, 0]
            lastShowsXY = true
        } else {
            // The trace area: the share of the span the window covers, from the left edge of the grid.
            let span = window.sampleRate.isFinite && window.sampleRate > 0
                ? TimebaseWindow(secondsPerDivision: state.secondsPerDivision).sampleCount(sampleRate: window.sampleRate)
                : window.sampleCount
            let share = span > 0 ? min(Double(window.sampleCount) / Double(span), 1) : 1
            let rect = (x: left, y: bottom, width: plotWidth * share, height: plotHeight)
            let columns = min(max(Int(rect.width.rounded(.down)), 1), Self.maxColumns)
            let g32 = Float(gain)
            for channel in 0..<2 {
                let node = traceNodes[channel]
                guard channel < window.channelCount else {
                    node.primitive = nil
                    lastPointCounts[channel] = 0
                    continue
                }
                let reduced = MinMaxDecimator.reduce(window.displayValues(channel: channel, gain: gain),
                                                     columns: columns)
                let points = ScopeTrace.waveformPoints(reduced, in: rect)
                node.primitive = points.isEmpty
                    ? nil : Primitive.polyline(points.map(Self.vec), width: Self.traceWidth)
                let clipped = window.samples(channel: channel).contains { abs($0 * g32) > 1 }
                node.color = clipped ? Self.clipColor : Self.traceColors[channel]
                lastPointCounts[channel] = points.count
            }
            lastColumns = columns
            lastXYPoints = []
            lastShowsXY = false
        }
        lastTraceNodeCount = traceNodes.filter { $0.primitive != nil }.count
    }

    /// Analyses the newest 4,096 frames of the left (or only) channel of the running source with the one kept
    /// `SpectrumAnalyzer` and records the magnitudes and the readout (nil, with no magnitudes, while no source runs).
    private func analyseSpectrum() {
        let samples: [Float]
        let written: Int
        if activeStereo != nil {
            let n = stereoBuffer.latestFrames(SpectrumReadout.frameSize, left: &spectrumLeft, right: &spectrumRight)
            samples = Array(spectrumLeft[0..<n])
            written = stereoBuffer.totalFrames
        } else if activeMono != nil {
            let n = ring.latest(SpectrumReadout.frameSize, into: &spectrumLeft)
            samples = Array(spectrumLeft[0..<n])
            written = ring.totalWritten
        } else {
            lastMagnitudes = []
            lastReadout = nil
            return
        }
        if analyzer == nil { analyzer = SpectrumAnalyzer(size: SpectrumReadout.frameSize) }
        guard let analyzer else {
            lastMagnitudes = []
            lastReadout = nil
            return
        }
        let rate = activeSampleRate
        let magnitudes = analyzer.magnitudesDB(samples)
        lastMagnitudes = magnitudes
        lastSpectrumRate = rate
        lastReadout = SpectrumReadout.make(magnitudesDB: magnitudes, samples: samples, sampleRate: rate,
                                           writtenFrames: written)
    }

    /// Places the spectrum grid (decade and plot-edge verticals, level-mark horizontals) and the spectrum curve
    /// (one polyline, the strongest bin per pixel column) inside `rect` (world pixels, y up).
    private func layOutSpectrum(rect: (x: Double, y: Double, width: Double, height: Double)) {
        let columns = min(max(Int(rect.width.rounded(.down)), 1), SpectrumView.maximumWidth)
        var lines: [(Vec2, Vec2, Vec4)] = []
        lines.append((Vec2(rect.x, rect.y), Vec2(rect.x, rect.y + rect.height), Self.axisColor))
        lines.append((Vec2(rect.x + rect.width, rect.y), Vec2(rect.x + rect.width, rect.y + rect.height),
                      Self.axisColor))
        for mark in SpectrumView.decadeMarks(sampleRate: lastSpectrumRate, width: rect.width) {
            let x = rect.x + mark.x
            lines.append((Vec2(x, rect.y), Vec2(x, rect.y + rect.height), Self.gridColor))
        }
        for level in SpectrumView.levelMarks {
            let y = rect.y + (level - SpectrumView.floorDB) / -SpectrumView.floorDB * rect.height
            let edge = level == 0 || level == SpectrumView.floorDB
            lines.append((Vec2(rect.x, y), Vec2(rect.x + rect.width, y), edge ? Self.axisColor : Self.gridColor))
        }
        for (index, line) in lines.prefix(gridNodes.count).enumerated() {
            gridNodes[index].primitive = .line(line.0, line.1, width: Self.gridWidth)
            gridNodes[index].color = line.2
        }
        let reduced = SpectrumView.columns(magnitudesDB: lastMagnitudes, sampleRate: lastSpectrumRate,
                                           size: SpectrumReadout.frameSize, width: columns)
        let points = SpectrumView.points(reduced, in: rect, columnCount: columns)
        traceNodes[0].primitive = points.count < 2
            ? nil : Primitive.polyline(points.map(Self.vec), width: Self.traceWidth)
        traceNodes[0].color = lastReadout?.validity == .clipping ? Self.clipColor : Self.traceColors[0]
        traceNodes[1].primitive = nil
        lastSpectrumPointCount = traceNodes[0].primitive == nil ? 0 : points.count
        lastSpectrumColumns = columns
        lastPointCounts = [0, 0]
        lastXYPoints = []
        lastShowsXY = false
    }

    /// The world position of a trace point (the same pixel units, y up).
    nonisolated private static func vec(_ point: TracePoint) -> Vec2 { Vec2(point.x, point.y) }

    // MARK: Lifecycle

    /// Stops the source while the shell is suspended and starts it again (fresh buffer, acquisition reset) on return.
    func checkLifecycle() {
        let suspended = lifecycle?() == .suspended
        if suspended, !isSuspended {
            isSuspended = true
            stopActive()
        } else if !suspended, isSuspended {
            isSuspended = false
            if let lastCore { sync(lastCore) }
        }
    }

    private func enterBackground() {
        isBackgrounded = true
        stopActive()
    }

    // MARK: Sources

    /// Makes the running source match `core`'s selection (see the file header).
    func sync(_ core: ScopeCore) {
        lastCore = core
        updateDisplay(core)
        guard isLive, !isBackgrounded, !isSuspended else { return }
        let desired: SourceKey?
        switch core.state.source {
        case .testSignal:
            desired = Self.testKey(for: core.state)
        case .file:
            if let pickedFile {
                desired = .file(pick: pickedFile.pick)
            } else {
                desired = nil
                setMessage(Self.fileGoneMessage, settings: false, offer: true)
            }
        case .microphone:
            switch permission.state {
            case .granted:
                desired = .microphone
            case .notDetermined, .denied, .restricted:
                desired = activeKey                       // the previous source keeps running
                if permission.state != .notDetermined { showDenied() }
                scheduleTestSignalFallback()
            }
        }
        if desired != failedKey { failedKey = nil }
        guard desired != activeKey else { return }
        if let desired, desired == failedKey { return }     // a failed start is not retried every frame
        stopActive()
        if let desired { start(desired, state: core.state) }
    }

    /// Starts the source for `key` into a fresh buffer and resets the acquisition; a failure is shown and not retried
    /// for the same key.
    private func start(_ key: SourceKey, state: ScopeState) {
        do {
            switch key {
            case .testSignal:
                let source = factory.testSignal(Self.testSignal(for: state))
                let buffer = StereoSampleBuffer(capacityFrames: Self.bufferFrames)
                try source.start(into: buffer)
                stereoBuffer = buffer
                activeStereo = source
            case .file:
                guard let pickedFile else { return }
                let buffer = StereoSampleBuffer(capacityFrames: Self.bufferFrames)
                try pickedFile.source.start(into: buffer)
                stereoBuffer = buffer
                activeStereo = pickedFile.source
            case .microphone:
                let source = factory.microphone(permission)
                let buffer = SampleRingBuffer(capacity: Self.ringCapacity)
                try source.start(into: buffer)
                ring = buffer
                activeMono = source
            }
            activeKey = key
            startCount += 1
            acquisition.reset()
            lastWindow = nil
            if !mirror.showsSettingsLink { clearMessage() }    // a stale stop or file message goes
        } catch {
            failedKey = key
            setMessage(Self.failureText(error), settings: (error as? AudioSourceError) == .permissionDenied,
                       offer: key != Self.testKey(for: state))
        }
    }

    /// Stops the running source, if any (the microphone is released).
    private func stopActive() {
        activeStereo?.stop()
        activeMono?.stop()
        activeStereo = nil
        activeMono = nil
        activeKey = nil
    }

    /// Opens the picked file at `url` and, when it decodes, selects the file source. An undecodable file changes
    /// nothing (the previous source keeps running) and shows `undecodableMessage`. Returns whether the file was taken.
    @discardableResult
    func chooseFile(url: URL) -> Bool {
        let source: any StereoAudioSource
        do {
            source = try factory.file(url)
        } catch {
            setMessage(Self.undecodableMessage, settings: false, offer: true)
            return false
        }
        let previous = pickedFile
        pickCount += 1
        pickedFile = PickedFile(name: url.lastPathComponent, pick: pickCount, source: source)
        guard let port, port.send("source.select", [Double(ScopeSource.file.rawValue)]).isAccepted else {
            pickedFile = previous
            return false
        }
        clearMessage()
        if let lastCore { sync(lastCore) }
        return true
    }

    /// Chooses the microphone: granted sends `source.select 2`; not determined asks once and sends it when allowed;
    /// denied or restricted keeps the previous source, shows the message and offers the test signal. Returns the
    /// answer (`a08.permission-denied` when access is off).
    @discardableResult
    func chooseMicrophone() async -> ActionResult {
        guard let port else { return .rejected(.notActive(.inactive)) }
        var access = permission.state
        if access == .notDetermined {
            mirror.isRequestingPermission = true
            access = await permission.request()
            mirror.isRequestingPermission = false
        }
        guard access == .granted else {
            showDenied()
            return .rejected(.rule(code: ScopeRule.permissionDenied))
        }
        let result = port.send("source.select", [Double(ScopeSource.microphone.rawValue)])
        if result.isAccepted { clearMessage() }
        return result
    }

    /// What the source picker does for `source`: the test signal sends `source.select 0`, the microphone goes through
    /// `chooseMicrophone()`. Returns the answer, or nil for a file, which the controls pick first with the system file
    /// importer (then `chooseFile(url:)`).
    @discardableResult
    func pickSource(_ source: ScopeSource) async -> ActionResult? {
        switch source {
        case .testSignal:
            return useTestSignal()
        case .microphone:
            return await chooseMicrophone()
        case .file:
            return nil
        }
    }

    /// Selects the test signal (the offer after a refused microphone or an unplayable file).
    @discardableResult
    func useTestSignal() -> ActionResult {
        guard let port else { return .rejected(.notActive(.inactive)) }
        let result = port.send("source.select", [Double(ScopeSource.testSignal.rawValue)])
        if result.isAccepted { clearMessage() }
        return result
    }

    /// A restored microphone selection without access: back to the test signal after the current frame or
    /// description (never from inside it).
    private func scheduleTestSignalFallback() {
        guard !fallbackScheduled, port != nil else { return }
        fallbackScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            fallbackScheduled = false
            guard lastCore?.state.source == .microphone, permission.state != .granted else { return }
            _ = port?.send("source.select", [Double(ScopeSource.testSignal.rawValue)])
        }
    }

    private func showDenied() {
        setMessage(Self.deniedMessage, settings: true, offer: true)
    }

    private func clearMessage() {
        setMessage(nil, settings: false, offer: false)
    }

    /// Sets the message, the Settings link and the test-signal offer, each only when it changes (no redraw of the
    /// controls every frame).
    private func setMessage(_ message: String?, settings: Bool, offer: Bool) {
        if mirror.message != message { mirror.message = message }
        if mirror.showsSettingsLink != settings { mirror.showsSettingsLink = settings }
        if mirror.offersTestSignal != offer { mirror.offersTestSignal = offer }
    }

    /// A plain message for a source that could not start.
    static func failureText(_ error: any Error) -> String {
        guard let error = error as? AudioSourceError else { return "The signal could not start." }
        switch error {
        case .engineFailed(let reason): return "The signal could not start: \(reason)"
        case .undecodable: return undecodableMessage
        case .permissionDenied, .notDetermined: return deniedMessage
        }
    }

    // MARK: Description

    /// Records the display fields when one of them changed.
    private func updateDisplay(_ core: ScopeCore) {
        let state = core.state
        if !mirror.ready { mirror.ready = true }
        if mirror.source != state.source { mirror.source = state.source }
        let name = sourceName(state.source)
        if mirror.sourceName != name { mirror.sourceName = name }
        let waveform = ScopeSettings.index(of: state.waveform)
        if mirror.waveformIndex != waveform { mirror.waveformIndex = waveform }
        if mirror.frequencyIndex != state.frequencyIndex { mirror.frequencyIndex = state.frequencyIndex }
        if mirror.gainIndex != state.gainIndex { mirror.gainIndex = state.gainIndex }
        if mirror.timebaseIndex != state.timebaseIndex { mirror.timebaseIndex = state.timebaseIndex }
        if mirror.triggerLevel != state.triggerLevel { mirror.triggerLevel = state.triggerLevel }
        let slope = ScopeSettings.index(of: state.triggerSlope)
        if mirror.slopeIndex != slope { mirror.slopeIndex = slope }
        let mode = ScopeSettings.index(of: state.triggerMode)
        if mirror.modeIndex != mode { mirror.modeIndex = mode }
        if mirror.display != state.display { mirror.display = state.display }
    }

    /// Records the trace status of the last window when it changed.
    private func updateStatus(_ state: ScopeState) {
        let note = xyFallsBack(state) ? Self.xyNeedsStereo : nil
        if mirror.displayNote != note { mirror.displayNote = note }
        var status = Self.channelWords(activeChannelCount) + ", " + Self.triggerWords(lastWindow, state: state) + ", "
            + (lastWindow?.clipped == true ? "clipping" : "not clipping")
        if state.display == .xy { status = (note ?? "XY view") + ", " + status }
        if state.display == .spectrum {
            status = "spectrum view, " + spectrumChannelWords + ", " + readoutWords + ", " + Self.spectrumAxesWords
        }
        if mirror.status != status { mirror.status = status }
    }

    /// The analysed channel in words: "left channel" for a two-channel source, "1 channel" for a mono one, "no
    /// signal" while none runs.
    private var spectrumChannelWords: String {
        activeChannelCount == 2 ? "left channel" : Self.channelWords(activeChannelCount)
    }

    /// The peak readout in words (`SpectrumReadout.text`), "no signal" while no source runs.
    private var readoutWords: String { lastReadout?.text ?? "no signal" }

    /// The channel count the view is decided by: the last window's, or the running source's before the first window.
    private var viewChannelCount: Int { lastWindow?.channelCount ?? activeChannelCount }

    /// Whether XY is chosen but the window (or the running source) has fewer than two channels.
    private func xyFallsBack(_ state: ScopeState) -> Bool {
        state.display == .xy && viewChannelCount < 2
    }

    /// The view in words: "waveform view"; "XY view" (with the stereo test signal: "XY view, left 1 kHz against right
    /// 1.5 kHz (2 : 3)"); "XY needs two channels, waveform view" for a mono window in XY.
    private func viewWords(_ state: ScopeState) -> String {
        guard state.display == .xy else { return "waveform view" }
        if xyFallsBack(state) { return Self.xyNeedsStereo + ", waveform view" }
        guard state.source == .testSignal else { return "XY view" }
        return "XY view, " + Self.ratioWords(state)
    }

    /// The test signal's channels in words: "left 1 kHz against right 1.5 kHz (2 : 3)", "left 100 Hz to 10 kHz
    /// against right 150 Hz to 15 kHz (2 : 3)" for the sweep.
    nonisolated static func ratioWords(_ state: ScopeState) -> String {
        if state.waveform == .sweep {
            return "left \(frequencyWords(sweepStart)) to \(frequencyWords(sweepEnd)) against right "
                + "\(frequencyWords(sweepStart * rightRatio)) to \(frequencyWords(sweepEnd * rightRatio)) (2 : 3)"
        }
        return "left \(frequencyWords(state.frequency)) against right "
            + "\(frequencyWords(state.frequency * rightRatio)) (2 : 3)"
    }

    /// A frequency in words: "440 Hz", "660 Hz", "1 kHz", "1.5 kHz", "7.5 kHz" (hertz below 1 kHz, otherwise kilohertz
    /// with at most two decimals).
    nonisolated static func frequencyWords(_ hertz: Double) -> String {
        guard hertz.isFinite else { return "0 Hz" }
        if hertz < 1_000 {
            let r = hertz.rounded()
            return "\(Int(r)) Hz"
        }
        let k = (hertz / 10).rounded() / 100
        return k == k.rounded() ? "\(Int(k)) kHz" : "\(k) kHz"
    }

    /// "Test signal", "Microphone" or the picked file's name ("File" when none is open).
    private func sourceName(_ source: ScopeSource) -> String {
        source == .file ? (pickedFile?.name ?? ScopeSource.file.displayName) : source.displayName
    }

    /// The spoken source and signal: "test signal, sine 1 kHz", "test signal, sweep 100 Hz to 10 kHz",
    /// "file <name>", "microphone".
    private func spokenSource(_ state: ScopeState) -> String {
        switch state.source {
        case .testSignal: "test signal, " + Self.signalWords(state)
        case .file: "file " + (pickedFile?.name ?? "not available")
        case .microphone: "microphone"
        }
    }

    /// "sine 1 kHz", "square 440 Hz", "sweep 100 Hz to 10 kHz".
    nonisolated static func signalWords(_ state: ScopeState) -> String {
        let name = ScopeSettings.displayName(of: state.waveform).lowercased()
        return state.waveform == .sweep ? "\(name) 100 Hz to 10 kHz"
            : "\(name) \(ScopeSettings.frequencyName(state.frequencyIndex))"
    }

    /// "no signal", "1 channel", "2 channels".
    nonisolated static func channelWords(_ count: Int) -> String {
        switch count {
        case 0: "no signal"
        case 1: "1 channel"
        default: "\(count) channels"
        }
    }

    /// A trigger level in words: "0", "0.25", "-0.5" (two decimals at most).
    nonisolated static func levelWords(_ level: Double) -> String {
        guard level.isFinite else { return "0" }
        let r = (level * 100).rounded() / 100
        if r == 0 { return "0" }
        return r == r.rounded() ? String(Int(r)) : String(r)
    }

    /// The trigger state of `window` in words: "triggered rising at 0", "waiting for a rising trigger at 0" (normal
    /// mode), "no trigger" (auto mode, free-running), "filling" (fewer samples than the span) or "no samples yet";
    /// ", shortened span" is added when the span was capped.
    nonisolated static func triggerWords(_ window: SignalWindow?, state: ScopeState) -> String {
        let slope = ScopeSettings.displayName(of: state.triggerSlope).lowercased()
        let level = levelWords(state.triggerLevel)
        guard let window, window.sampleCount > 0 else { return "no samples yet" }
        let words: String
        if window.waiting {
            words = "waiting for a \(slope) trigger at \(level)"
        } else if window.partial {
            words = "filling"
        } else if window.triggered {
            words = "triggered \(slope) at \(level)"
        } else {
            words = "no trigger"
        }
        return window.shortened ? words + ", shortened span" : words
    }

    /// "Oscilloscope Studio: test signal, sine 1 kHz, 2 channels, waveform view, 1 ms per division, gain ×1, triggered
    /// rising at 0, not clipping." (in XY: "…, 2 channels, XY view, left 1 kHz against right 1.5 kHz (2 : 3), …"; a
    /// mono window in XY: "…, 1 channel, XY needs two channels, waveform view, …"; in the spectrum view: "…, 2
    /// channels, spectrum view, left channel, <axes>, peak 1,000 Hz at −6.0 dBFS, relative to full scale." with a
    /// fresh analysis, or the reason no peak is shown). Also brings the running source in line with `core`.
    func describe(_ core: ScopeCore) -> String {
        checkLifecycle()
        sync(core)
        let state = core.state
        if state.display == .spectrum {
            analyseSpectrum()
            let channels = Self.channelWords(activeChannelCount)
            let analysed = activeChannelCount == 2 ? ", left channel" : ""
            return "Oscilloscope Studio: \(spokenSource(state)), \(channels), spectrum view\(analysed), "
                + "\(Self.spectrumAxesWords), \(readoutWords)."
        }
        return "Oscilloscope Studio: \(spokenSource(state)), \(Self.channelWords(activeChannelCount)), "
            + "\(viewWords(state)), "
            + "\(ScopeSettings.timebaseName(state.timebaseIndex)), gain \(ScopeSettings.gainName(state.gainIndex)), "
            + "\(Self.triggerWords(lastWindow, state: state)), "
            + (lastWindow?.clipped == true ? "clipping" : "not clipping") + "."
    }

    /// One background probe in the top-left corner, outside the plot's 6 % inset.
    func probes(_ core: ScopeCore) -> [FrameProbe] {
        [FrameProbe(name: "background", x: 0.02, y: 0.02, expected: "dark")].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ScopeControls(port: port, presenter: self, mirror: mirror))
    }

    /// Every action has a native control.
    var nativeActions: Set<String> { Set(ScopeCore.actionIDs) }
}
