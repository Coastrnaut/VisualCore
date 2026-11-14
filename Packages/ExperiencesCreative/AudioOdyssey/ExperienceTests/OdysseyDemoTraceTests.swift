// OdysseyDemoTraceTests — feature 057 (A07-P04) T-A07-404 (FR-A07-420; SC-A07-404; clarification 4).
// The demo fixture, short runs only (each test under 10 s, frames of 1/60 s, no wall-clock assertion):
//   - Pure: the real demo signal (`DemoSignal(seed: 7, mode: .sequence)` at 48 kHz) is rendered 800 samples per frame
//     (48 kHz ÷ 60 fps) into a rolling 1,024-sample window and analysed by `FeatureExtractor(size: 1024, sampleRate:
//     48_000, bandCount: 16)` at time i/60 and elapsed 1/60 for 120 frames; `DemoResponseTrace` run twice with each
//     world's default mapping gives the same trace (≤ 1e-6) and the primary rises by at least 25% of its range in
//     every world. Measured on 2026-11-14 with the default melody (`.sequence`): tunnel 0.997, landscape 1.000, star
//     corridor 0.417.
//   - Host: the experience is opened twice in the one app's session host with the same seed and a demo source double
//     that plays the real `DemoSignal` the presenter hands to the factory, 800 samples before every one of 120 frames
//     drawn with `renderOneFrame` (fixed delta 1/60); the presenter's (primary, light) sequences of both runs agree
//     within 1e-6 and the primary rises above rest. The opening world is the tunnel, whose default mapping (low,
//     overall) reads band energies only; the host's frame time (wall clock) reaches only the onset flag, which the
//     tunnel's mapping does not read, so the comparison is exact.
import Foundation
import Testing
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// Samples per frame: 48 kHz at 60 frames per second.
private let samplesPerFrame = 800
/// Frames of every run (two seconds).
private let traceFrames = 120
/// The fixed frame step.
private let traceStep = 1.0 / 60

/// The analysis frames of the real demo signal: band energies, spectral flux and onset flag of every frame.
private struct DemoFrames {
    var bands: [[Float]] = []
    var flux: [Float] = []
    var onsets: [Bool] = []

    /// Renders `frames` frames of `DemoSignal(seed:mode:)` into a rolling 1,024-sample window and analyses each.
    static func make(seed: UInt64 = 7, mode: DemoSignal.Mode = .sequence, frames: Int = traceFrames) -> DemoFrames? {
        guard let extractor = FeatureExtractor(size: 1_024, sampleRate: 48_000, bandCount: 16) else { return nil }
        var signal = DemoSignal(seed: seed, mode: mode, sampleRate: 48_000)
        var window = [Float](repeating: 0, count: 1_024)
        var block = [Float](repeating: 0, count: samplesPerFrame)
        var out = DemoFrames()
        for i in 0..<frames {
            block.withUnsafeMutableBufferPointer { signal.render(into: $0) }
            window.removeFirst(samplesPerFrame)
            window.append(contentsOf: block)
            let features = window.withUnsafeBufferPointer {
                extractor.analyze($0, time: Double(i) * traceStep, elapsed: traceStep)
            }
            out.bands.append(features.bandEnergies)
            out.flux.append(features.flux)
            out.onsets.append(features.onset)
        }
        return out
    }

    /// The response trace of `world` with its default mapping.
    func trace(_ world: JourneyWorld) -> [DemoResponseTrace.TracePoint] {
        DemoResponseTrace.run(bandFrames: bands, flux: flux, onsets: onsets, world: world,
                              mapping: WorldMapping.defaults(for: world), step: traceStep)
    }
}

@Suite struct OdysseyDemoTraceCoreTests {
    @Test func theRealDemoSignalGivesTheSameTraceTwiceInEveryWorld() throws {
        let first = try #require(DemoFrames.make())
        let second = try #require(DemoFrames.make())
        #expect(first.bands == second.bands && first.flux == second.flux && first.onsets == second.onsets,
                "the demo signal and the extractor are deterministic")
        for world in JourneyWorld.allCases {
            let a = first.trace(world)
            let b = second.trace(world)
            #expect(a.count == traceFrames, "\(world)")
            #expect(a.count == b.count, "\(world)")
            let delta = zip(a, b).map { max(abs($0.primary - $1.primary), abs($0.light - $1.light)) }.max() ?? 0
            #expect(delta <= 1e-6, "\(world): max |Δ| \(delta)")
            // The same frames run again through a fresh envelope and response give the same trace.
            #expect(first.trace(world) == a, "\(world)")
        }
    }

    @Test func theRealDemoSignalRaisesThePrimaryByAQuarterInEveryWorld() throws {
        let frames = try #require(DemoFrames.make())
        #expect(frames.onsets.contains(true), "the melody's note changes are onsets")
        for world in JourneyWorld.allCases {
            let trace = frames.trace(world)
            let rise = DemoResponseTrace.maxRise(trace, world: world)
            #expect(rise >= 0.25, "\(world): the demo melody (seed 7) rose \(rise) of the range within 120 frames")
            let upper = WorldResponse.maxPrimary(for: world)
            #expect(trace.allSatisfy { (0...upper).contains($0.primary) }, "\(world): the primary stays in bounds")
        }
    }
}

/// A permission double that never grants (the microphone is never started).
@MainActor
private final class DeniedPermission: MicrophonePermission {
    var state: MicrophonePermissionState = .denied

    func request() async -> MicrophonePermissionState { state }
}

/// A demo source double that plays the real `DemoSignal` the presenter hands to the factory, one frame's samples
/// (800 at 48 kHz) per `pump()`, so the samples follow the drawn frames instead of a timer.
@MainActor
private final class SteppedDemoSource: AudioSource {
    let label = "demo"
    var sampleRate: Double { signal.sampleRate }
    private(set) var state: AudioSourceState = .idle
    private var signal: DemoSignal
    private var buffer: SampleRingBuffer?
    private var block = [Float](repeating: 0, count: samplesPerFrame)

    init(_ signal: DemoSignal) { self.signal = signal }

    func start(into buffer: SampleRingBuffer) throws {
        self.buffer = buffer
        state = .running
    }

    func stop() {
        buffer = nil
        state = .idle
    }

    func pump() {
        guard let buffer else { return }
        block.withUnsafeMutableBufferPointer { signal.render(into: $0) }
        block.withUnsafeBufferPointer { buffer.write($0) }
    }
}

/// Every demo source the factory made, in order, with the signal it was given.
@MainActor
private final class SteppedDemoLog {
    var made: [SteppedDemoSource] = []
    var signals: [DemoSignal] = []

    var factory: OdysseySourceFactory {
        OdysseySourceFactory(demo: { [unowned self] signal in
                                 signals.append(signal)
                                 let source = SteppedDemoSource(signal)
                                 made.append(source)
                                 return source
                             },
                             file: { _ in throw CocoaError(.fileReadUnsupportedScheme) },
                             microphone: { _ in SteppedDemoSource(DemoSignal(seed: 0, mode: .silence)) })
    }
}

@MainActor
final class OdysseyDemoTraceHostTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    /// Opens the experience with seed 7 and the stepped demo source, draws 120 frames (one frame of demo samples
    /// before each) and returns the presenter's response after every frame.
    private func run() async throws -> (responses: [WorldResponse], signal: DemoSignal) {
        let session = ExperienceSession()
        let log = SteppedDemoLog()
        let id = self.id
        let factory = log.factory
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id, permission: DeniedPermission(), factory: factory,
                                                    reduceMotion: false, reduceFlashing: false)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        let host = try XCTUnwrap(session.renderHost)
        host.view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        host.view.layoutIfNeeded()
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let source = try XCTUnwrap(log.made.last, "the demo source plays first")
        XCTAssertEqual(log.made.count, 1)
        XCTAssertTrue(shell.presenter.activeSource === source)
        let signal = try XCTUnwrap(log.signals.last)
        var responses: [WorldResponse] = []
        for _ in 0..<traceFrames {
            source.pump()
            XCTAssertTrue(host.renderOneFrame(present: false))
            responses.append(shell.presenter.response)
        }
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(source.state, .idle, "closing stops the demo source")
        return (responses, signal)
    }

    func testTheHostRenderedDemoGivesTheSameResponseSequenceTwice() async throws {
        let first = try await run()
        let second = try await run()
        XCTAssertEqual(first.signal.seed, second.signal.seed)
        XCTAssertEqual(first.signal.mode, .sequence, "the default demo melody")
        XCTAssertEqual(first.signal.mode, second.signal.mode)
        XCTAssertEqual(first.responses.count, traceFrames)
        XCTAssertEqual(second.responses.count, traceFrames)
        var delta = 0.0
        for (a, b) in zip(first.responses, second.responses) {
            XCTAssertEqual(a.world, b.world)
            delta = max(delta, abs(a.primary - b.primary), abs(a.light - b.light))
        }
        XCTAssertLessThanOrEqual(delta, 1e-6, "max |Δ| between the two runs")
        let world = try XCTUnwrap(first.responses.first?.world)
        XCTAssertEqual(world, .tunnel, "the journey opens in the tunnel")
        let rest = WorldResponse(world: world, reduceMotion: false, reduceFlashing: false)
        let peak = first.responses.map(\.primary).max() ?? rest.primaryRest
        XCTAssertGreaterThan(peak, rest.primaryRest + 1e-3, "the demo lifts the primary above rest: peak \(peak)")
        let rise = (peak - rest.primaryRest) / (WorldResponse.maxPrimary(for: world) - rest.primaryRest)
        XCTAssertGreaterThanOrEqual(rise, 0.25, "host rise \(rise)")
    }
}
