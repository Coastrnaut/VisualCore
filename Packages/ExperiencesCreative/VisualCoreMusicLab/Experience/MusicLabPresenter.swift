// MusicLabPresenter — feature 047 (A06-P01) T-A06-104 (FR-A06-101–105, FR-A06-121, FR-A06-122). Draws VisualCore Music
// Lab through the host only (the host's context and registry, VisualCore's `PrimitiveRenderer`; no context of its
// own) and owns everything that is not state: the active `AudioSource`, the `SampleRingBuffer` it writes into, the
// picked file and the microphone permission.
//
//   - Source lifecycle: `sync(_:)` makes the running source match the core's selection. It runs on every draw and on
//     every description (the shell describes the core after each accepted action, so a switch takes effect at once).
//     Sources run only between `setup` and `teardown` (leaving the experience destroys the host, whose teardown stops
//     the source and releases the microphone) and not while the app is in the background (the host is paused then, so
//     the presenter stops the source on `didEnterBackground` and the next draw restarts it). Each start gets a fresh
//     ring buffer, so no sample of the previous source is drawn. At most one source runs: the previous one is stopped
//     before the next starts, so rapid switches end with exactly the last choice running.
//   - Demo: `DemoAudioSource(signal: DemoSignal(seed: demoSeed, mode:))`; a new seed or mode restarts it.
//   - File: `chooseFile(url:)` opens the picked file (security-scoped access held while it is the picked file) before
//     anything changes; an undecodable file leaves the previous source playing and shows a message. Only then is
//     `source.file` sent; the name is display state (see MusicLabCore, "file name decision").
//   - Microphone: `chooseMicrophone()` mirrors the permission into the core first (`permission.mirror`), so denied or
//     restricted access is refused by the core's rule (`a06.permission-denied`) with the previous source playing and
//     a message with the way to Settings; not determined is accepted, the system is asked once, and a refusal falls
//     back to the demo signal. The microphone source starts only while the permission is granted.
//   - Drawing: the latest 1,024 samples as a polyline across the view (amplitude × 0.4 of the view height around a
//     dim centre line) on a dark background; fewer samples than 1,024 are drawn right-aligned over silence.
import Foundation
import SwiftUI
import UIKit
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreMusicLabCore
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the display copy of the state (with the file name), the status line and a message.
@MainActor
@Observable
final class MusicLabMirror {
    /// The core's state with the picked file's name recorded; nil before the first description.
    var state: MusicLabState?
    /// The status line: "Demo signal", the file's name or "Microphone".
    var status = SourceKind.demo.displayName
    /// A plain message (a refused permission, an unplayable file, a stopped source); nil when all is well.
    var message: String?
    /// Whether the message concerns microphone access that only Settings can change.
    var showsSettingsLink = false
    /// Whether the system permission request is open.
    var isRequestingPermission = false
}

/// How the presenter makes its sources; tests replace the file and microphone sources with doubles.
struct MusicLabSourceFactory {
    /// The demo source for a signal.
    var demo: @MainActor (DemoSignal) -> any AudioSource
    /// The file source for a picked URL; throws for a file the system cannot decode.
    var file: @MainActor (URL) throws -> any AudioSource
    /// The microphone source behind a permission.
    var microphone: @MainActor (any MicrophonePermission) -> any AudioSource

    /// The VisualCoreAudio sources.
    static var system: MusicLabSourceFactory {
        MusicLabSourceFactory(demo: { DemoAudioSource(signal: $0) },
                              file: { try FileAudioSource(url: $0) },
                              microphone: { MicrophoneAudioSource(permission: $0) })
    }
}

/// The presenter of VisualCore Music Lab.
@MainActor
final class MusicLabPresenter: ExperiencePresenter {
    typealias Core = MusicLabCore

    /// The ring buffer's capacity in samples (a third of a second at 48 kHz).
    nonisolated static let ringCapacity = 16_384
    /// The number of newest samples drawn per frame.
    nonisolated static let drawnSampleCount = 1_024
    /// The drawn amplitude of a full-scale sample, as a share of the view height (feature 048: the waveform keeps the
    /// band 10 %…50 % of the height from the top, so its centre sits 30 % from the top).
    static let amplitudeShare = 0.2
    /// The waveform centre's offset above the view centre, as a share of the height.
    static let waveCentreShare = 0.2
    /// The spectrum bars' band, as shares of the height from the top (58 %…90 %).
    static let barsTopShare = 0.58, barsBottomShare = 0.90
    /// The width share left at the right edge for the level and beat meters.
    static let metersShare = 0.12
    /// The bar, level and beat colours.
    nonisolated static let barColor = Vec4(0.45, 0.6, 1.0, 1), levelColor = Vec4(0.4, 0.95, 0.55, 1),
                           peakColor = Vec4(1.0, 0.9, 0.4, 1), beatColor = Vec4(1.0, 0.45, 0.6, 1)
    /// The analysis window in samples (the drawn window).
    nonisolated static let analysisSize = 1_024
    /// The waveform's line width in pixels.
    static let lineWidth = 2.0
    /// The background colour (dark blue-black).
    nonisolated static let background: (red: Float, green: Float, blue: Float) = (0.02, 0.02, 0.05)
    /// The waveform colour.
    nonisolated static let waveColor = Vec4(0.35, 0.85, 1.0, 1)
    /// The centre line colour.
    nonisolated static let centreColor = Vec4(0.22, 0.24, 0.3, 1)
    /// The RMS below which the level is "quiet" (−40 dBFS) and below which it is "medium" (−20 dBFS).
    static let quietRMS: Float = 0.01, mediumRMS: Float = 0.1

    /// The message when microphone access is off.
    static let deniedMessage = "Microphone access is off. Allow it for VisualCore in Settings, or use the demo signal or a file."
    /// The message when a picked file cannot be played.
    static let undecodableMessage = "This file can't be played. Choose a WAV, AIFF, CAF, M4A or MP3 file."
    /// The message when a restored session's file is no longer reachable.
    static let fileGoneMessage = "Choose the audio file again to play it."

    /// What runs (or should run): the demo with its seed and mode, the picked file (by pick number) or the microphone.
    enum SourceKey: Equatable {
        case demo(seed: UInt64, mode: Int)
        case file(pick: Int)
        case microphone
    }

    /// A picked, opened file.
    private struct PickedFile {
        let url: URL
        let name: String
        let pick: Int
        let source: any AudioSource
        let accessing: Bool
    }

    let experienceID: ExperienceID
    let mirror = MusicLabMirror()
    /// The microphone permission (the system's by default; a double in tests).
    let permission: any MicrophonePermission
    let factory: MusicLabSourceFactory
    /// The port of the shell, set by `VisualCoreMusicLabExperience.make`; the presenter sends the actions of the file
    /// and microphone choices through it.
    weak var port: ExperienceActionPort?

    /// The buffer of the running source (a fresh one per start).
    private(set) var ring = SampleRingBuffer(capacity: MusicLabPresenter.ringCapacity)
    /// The running source, if any.
    private(set) var activeSource: (any AudioSource)?
    /// What `activeSource` was started for.
    private(set) var activeKey: SourceKey?
    /// A key whose start failed; not retried until the selection changes.
    private var failedKey: SourceKey?
    private var pickedFile: PickedFile?
    private var pickCount = 0
    /// True between `setup` and `teardown`.
    private(set) var isLive = false
    private var isBackgrounded = false
    private var fallbackScheduled = false
    private var observers: [NSObjectProtocol] = []
    /// The core of the last draw or description.
    private(set) var lastCore: MusicLabCore?

    /// The samples drawn by the last frame (oldest first; at most 1,024).
    private(set) var lastDrawnSamples: [Float] = []
    /// The ring buffer's total written count read right after the last frame's samples.
    private(set) var lastDrawnTotalWritten = 0
    private var scratch = [Float](repeating: 0, count: MusicLabPresenter.drawnSampleCount)

    private let clear = ClearColorScene(red: MusicLabPresenter.background.red, green: MusicLabPresenter.background.green,
                                        blue: MusicLabPresenter.background.blue)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "waveform")
    private let centre = SceneNode(id: "centre", z: 0, color: MusicLabPresenter.centreColor)
    private var segments: [SceneNode] = []
    private var bars: [SceneNode] = []
    private let levelNode = SceneNode(id: "level", z: 1, color: MusicLabPresenter.levelColor)
    private let peakNode = SceneNode(id: "peak", z: 2, color: MusicLabPresenter.peakColor)
    private let beatNode = SceneNode(id: "beat", z: 1, color: MusicLabPresenter.beatColor)

    /// The analysis of the running source (feature 048): made for its sample rate, reset on every source change.
    private(set) var extractor: FeatureExtractor?
    /// The features of the last frame (silence before the first).
    private(set) var lastFeatures = AudioFeatures.silent(bandCount: 16)
    /// The display heights of the last frame.
    private(set) var lastDisplay = AnalysisDisplay.silent(bandCount: 16)

    init(experienceID: ExperienceID, permission: any MicrophonePermission, factory: MusicLabSourceFactory = .system) {
        self.experienceID = experienceID
        self.permission = permission
        self.factory = factory
        root.add(centre)
        for index in 0..<(Self.drawnSampleCount - 1) {
            let node = SceneNode(id: "s\(index)", z: 1, color: Self.waveColor)
            root.add(node)
            segments.append(node)
        }
        for index in 0..<16 {
            let node = SceneNode(id: "b\(index)", z: 1, color: Self.barColor)
            root.add(node)
            bars.append(node)
        }
        root.add(levelNode)
        root.add(peakNode)
        root.add(beatNode)
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
        if let lastCore { sync(lastCore) }
    }

    func draw(_ core: MusicLabCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        if case .failed(let reason)? = activeSource?.state, mirror.message == nil {
            mirror.message = "The sound stopped: \(reason)"
        }
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        let count = ring.latest(Self.drawnSampleCount, into: &scratch)
        lastDrawnTotalWritten = ring.totalWritten
        let drawn = max(0, min(count, scratch.count))
        lastDrawnSamples = Array(scratch.prefix(drawn))
        analyze(drawn: drawn, frame: frame)
        layOut(width: width, height: height)
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
    }

    func teardown(_ context: RenderContext) {
        stopActive()
        isLive = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        primitives?.release()
        primitives = nil
        extractor = nil
    }

    /// Analyses the newest `drawn` samples of `scratch` once for this frame (feature 048, FR-A06-210, 211).
    private func analyze(drawn: Int, frame: FrameInfo) {
        let rate = activeSource?.sampleRate ?? 48_000
        if extractor == nil || extractor?.sampleRate != rate {
            extractor = FeatureExtractor(size: Self.analysisSize, sampleRate: rate)
        }
        guard let extractor else { return }
        scratch.withUnsafeBufferPointer { all in
            extractor.analyze(UnsafeBufferPointer(rebasing: all[0..<drawn]), time: frame.time, elapsed: frame.delta,
                              into: &lastFeatures)
        }
        let features = lastFeatures
        let bandDB = (0..<features.bandEnergies.count).map { features.bandDB($0) }
        lastDisplay = AnalysisDisplay(bandDB: bandDB, rmsDB: features.rmsDB, peakDB: features.peakDB,
                                      beat: features.beatEnergy)
    }

    /// Places the centre line and the 1,023 segments for a view of `width` × `height` pixels (world = pixels from
    /// the centre, y up): sample i of the newest 1,024 sits at x = −w/2 + i · w/1,023, y = clamp(s) · h · 0.4.
    private func layOut(width: Double, height: Double) {
        let waveY = height * Self.waveCentreShare
        centre.primitive = .line(Vec2(-width / 2, waveY), Vec2(width / 2, waveY), width: 1)
        let n = Self.drawnSampleCount
        let samples = lastDrawnSamples
        let offset = n - samples.count            // fewer samples: right-aligned over silence
        let dx = width / Double(n - 1)
        let amplitude = height * Self.amplitudeShare
        func y(_ i: Int) -> Double {
            let k = i - offset
            guard k >= 0, k < samples.count else { return 0 }
            let s = Double(samples[k])
            return waveY + (s.isFinite ? min(max(s, -1), 1) : 0) * amplitude
        }
        var previous = Vec2(-width / 2, y(0))
        for i in 1..<n {
            let point = Vec2(-width / 2 + Double(i) * dx, y(i))
            segments[i - 1].primitive = .line(previous, point, width: Self.lineWidth)
            previous = point
        }
        layOutAnalysis(width: width, height: height)
    }

    /// Places the 16 spectrum bars (58 %…90 % of the height from the top, left of the meters) and the level (with its
    /// peak mark) and beat meters (two right-edge columns over the same band) from `lastDisplay`. A zero height draws
    /// nothing (a line of zero length has no triangles).
    private func layOutAnalysis(width: Double, height: Double) {
        let bottom = height / 2 - height * Self.barsBottomShare
        let span = height * (Self.barsBottomShare - Self.barsTopShare)
        let barsWidth = width * (1 - Self.metersShare)
        let slot = barsWidth / Double(bars.count)
        let display = lastDisplay
        for (index, node) in bars.enumerated() {
            let x = -width / 2 + slot * (Double(index) + 0.5)
            let h = index < display.bars.count ? display.bars[index] * span : 0
            node.primitive = .line(Vec2(x, bottom), Vec2(x, bottom + h), width: slot * 0.7)
        }
        let column = width * Self.metersShare / 2
        let levelX = width / 2 - column * 1.5, beatX = width / 2 - column * 0.5
        levelNode.primitive = .line(Vec2(levelX, bottom), Vec2(levelX, bottom + display.level * span), width: column * 0.6)
        let peakY = bottom + display.peakMark * span
        peakNode.primitive = display.peakMark > 0
            ? .line(Vec2(levelX - column * 0.35, peakY), Vec2(levelX + column * 0.35, peakY), width: 2) : nil
        beatNode.primitive = .line(Vec2(beatX, bottom), Vec2(beatX, bottom + display.beat * span), width: column * 0.6)
    }

    // MARK: Sources

    /// Makes the running source match `core`'s selection (see the file header).
    func sync(_ core: MusicLabCore) {
        lastCore = core
        updateDisplay(core)
        guard isLive, !isBackgrounded else { return }
        let state = core.state
        let desired: SourceKey?
        switch state.source {
        case .demo:
            desired = .demo(seed: state.demoSeed, mode: state.demoMode)
        case .file:
            if let pickedFile {
                desired = .file(pick: pickedFile.pick)
            } else {
                desired = nil
                mirror.message = Self.fileGoneMessage
            }
        case .microphone:
            switch permission.state {
            case .granted:
                desired = .microphone
            case .notDetermined:
                desired = activeKey                   // the previous source plays while the system asks
                if !mirror.isRequestingPermission {
                    mirror.isRequestingPermission = true
                    Task { @MainActor [weak self] in await self?.finishPermissionRequest() }
                }
            case .denied, .restricted:
                desired = activeKey                   // the previous source keeps playing
                showDenied()
                scheduleDemoFallback()
            }
        }
        if desired != failedKey { failedKey = nil }
        guard desired != activeKey else { return }
        if let desired, desired == failedKey { return }     // a failed start is not retried every frame
        stopActive()
        if let desired { start(desired) }
    }

    /// Starts the source for `key` into a fresh ring buffer; a failure is shown and not retried for the same key.
    private func start(_ key: SourceKey) {
        let source: any AudioSource
        switch key {
        case .demo(let seed, let mode):
            source = factory.demo(DemoSignal(seed: seed, mode: DemoSignal.Mode(rawValue: mode) ?? .sequence))
        case .file:
            guard let pickedFile else { return }
            source = pickedFile.source
        case .microphone:
            source = factory.microphone(permission)
        }
        let buffer = SampleRingBuffer(capacity: Self.ringCapacity)
        do {
            try source.start(into: buffer)
            ring = buffer
            activeSource = source
            activeKey = key
            extractor?.reset()                                  // no beat of the previous source lingers
            if !mirror.showsSettingsLink { mirror.message = nil }   // a stale file or stop message goes
        } catch {
            failedKey = key
            mirror.message = Self.failureText(error)
            if case .permissionDenied? = error as? AudioSourceError {
                mirror.showsSettingsLink = true
            } else {
                mirror.showsSettingsLink = false
            }
        }
    }

    /// Stops the running source, if any.
    private func stopActive() {
        activeSource?.stop()
        activeSource = nil
        activeKey = nil
    }

    private func enterBackground() {
        isBackgrounded = true
        stopActive()
    }

    /// Opens the picked file at `url` and, when it decodes, selects the file source. An undecodable file changes
    /// nothing (the previous source keeps playing) and shows `undecodableMessage`. Returns whether the file was taken.
    @discardableResult
    func chooseFile(url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        let source: any AudioSource
        do {
            source = try factory.file(url)
        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
            mirror.message = Self.undecodableMessage
            mirror.showsSettingsLink = false
            return false
        }
        let previous = pickedFile
        pickCount += 1
        pickedFile = PickedFile(url: url, name: url.lastPathComponent, pick: pickCount, source: source,
                                accessing: accessing)
        mirror.message = nil
        mirror.showsSettingsLink = false
        guard let port, port.send("source.file").isAccepted else {
            pickedFile = previous
            if accessing { url.stopAccessingSecurityScopedResource() }
            return false
        }
        if let lastCore { sync(lastCore) }
        if let previous, previous.accessing { previous.url.stopAccessingSecurityScopedResource() }
        return true
    }

    /// Chooses the microphone (see the file header). Returns the core's answer to `source.microphone`.
    @discardableResult
    func chooseMicrophone() async -> ActionResult {
        guard let port else { return .rejected(.notActive(.inactive)) }
        let current = permission.state
        mirrorPermission(current)
        if current == .notDetermined { mirror.isRequestingPermission = true }
        let result = port.send("source.microphone")
        guard result.isAccepted else {
            mirror.isRequestingPermission = false
            if case .rejected(.rule(let code)) = result, code == MusicLabRule.permissionDenied { showDenied() }
            return result
        }
        mirror.message = nil
        mirror.showsSettingsLink = false
        if current == .notDetermined { await finishPermissionRequest() }
        return result
    }

    /// Asks the system once; granted starts the microphone, anything else falls back to the demo signal with the
    /// Settings message.
    private func finishPermissionRequest() async {
        let answer = await permission.request()
        mirror.isRequestingPermission = false
        mirrorPermission(answer)
        if answer == .granted {
            mirror.message = nil
            mirror.showsSettingsLink = false
            if let lastCore { sync(lastCore) }
        } else {
            showDenied()
            if lastCore?.state.source == .microphone { port?.send("source.demo") }
        }
    }

    /// Sends `permission.mirror` when the core's mirror differs from `state`.
    private func mirrorPermission(_ state: MicrophonePermissionState) {
        let access = Self.access(state)
        guard lastCore?.state.permission != access else { return }
        port?.send("permission.mirror", [Double(access.rawValue)])
    }

    /// A restored microphone selection without access: mirror the permission and go back to the demo signal, after
    /// the current description (never from inside it).
    private func scheduleDemoFallback() {
        guard !fallbackScheduled else { return }
        fallbackScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            fallbackScheduled = false
            mirrorPermission(permission.state)
            if lastCore?.state.source == .microphone { port?.send("source.demo") }
        }
    }

    private func showDenied() {
        mirror.message = Self.deniedMessage
        mirror.showsSettingsLink = true
    }

    /// The domain mirror of a system permission state.
    static func access(_ state: MicrophonePermissionState) -> MicrophoneAccess {
        switch state {
        case .notDetermined: .notDetermined
        case .granted: .granted
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    /// A plain message for a source that could not start.
    static func failureText(_ error: any Error) -> String {
        guard let error = error as? AudioSourceError else { return "The sound could not start." }
        if case .engineFailed(let reason) = error { return "The sound could not start: \(reason)" }
        if case .undecodable = error { return undecodableMessage }
        return deniedMessage
    }

    // MARK: Description

    /// Records the display copy of the state (with the picked file's name) and the status line.
    private func updateDisplay(_ core: MusicLabCore) {
        var display = core.state
        if display.source == .file, let pickedFile { display.recordFileName(pickedFile.name) }
        if mirror.state != display { mirror.state = display }
        let status = Self.statusText(display)
        if mirror.status != status { mirror.status = status }
    }

    /// "Demo signal", the file's name (or "Audio file") or "Microphone".
    static func statusText(_ state: MusicLabState) -> String {
        state.source == .file ? (state.fileName ?? SourceKind.file.displayName) : state.source.displayName
    }

    /// "quiet", "medium" or "loud" from the RMS of `samples` (−40 and −20 dBFS thresholds, as ``LevelWord``).
    static func levelText(_ samples: [Float]) -> String {
        guard !samples.isEmpty else { return "quiet" }
        var sum: Float = 0
        for s in samples where s.isFinite { sum += s * s }
        let rms = (sum / Float(samples.count)).squareRoot()
        return rms < quietRMS ? "quiet" : (rms < mediumRMS ? "medium" : "loud")
    }

    /// "Music Lab: <source>, level <quiet/medium/loud>[, beat]." from the last frame's features (feature 048,
    /// FR-A06-212). Also brings the running source in line with `core`.
    func describe(_ core: MusicLabCore) -> String {
        sync(core)
        let word = LevelWord.from(rmsDB: lastFeatures.rmsDB).rawValue
        return "Music Lab: \(mirror.status), level \(word)\(lastDisplay.isBeat ? ", beat" : "")."
    }

    /// One background probe in the top-left corner, outside the waveform's band (10 %…50 % of the height) and the bars.
    func probes(_ core: MusicLabCore) -> [FrameProbe] {
        [FrameProbe(name: "background", x: 0.04, y: 0.04, expected: "dark")].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MusicLabControls(port: port, presenter: self, mirror: mirror))
    }

    /// Every action has a native control; the permission mirror is sent by the Microphone button's flow.
    var nativeActions: Set<String> {
        ["source.demo", "source.microphone", "source.file", "demo.mode", "demo.reseed", "permission.mirror"]
    }
}
