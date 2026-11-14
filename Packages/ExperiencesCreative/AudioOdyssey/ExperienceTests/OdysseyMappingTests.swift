// OdysseyMappingTests — feature 056 (A07-P03) T-A07-303 (FR-A07-311, FR-A07-312, FR-A07-320, FR-A07-330; SC-A07-304
// to SC-A07-306; stories 2 and 3). What the music moves, short runs only (each test under 10 s, frames of 1/60 s, no
// wall-clock assertion): on the adapter core, `mapping.set` changes only the current world's mapping, the other worlds
// keep theirs across world switches and `mapping.reset` restores every default; a pulse on one envelope channel raises
// only the responses mapped to it, within bounds and step limits, in every world; the schema-1 and schema-2 examples
// migrate through `SnapshotMigrationCheck`. In the one app's session host (with source doubles; the microphone is
// never started): the presenter's response is exactly the drawn world's `WorldResponse` driven by the world's mapping
// of its `AudioEnvelope`, a low tone mapped to the primary raises it, each world applies its primary scale through one
// model matrix (tunnel and star corridor radial, landscape vertical swell); and five source switches keep the host
// (`hostsAlive == 1`, the same render host) and the journey's distance and speed.
import Foundation
import Testing
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

private let odysseyID = ExperienceID(rawValue: OdysseyCore.experienceID)!

/// The envelope after `frames` frames of 1/60 s in which only `channel` carries signal (the overall channel cannot
/// be pulsed on its own; it is the mean of low, mid and high).
private func pulsed(_ channel: EnvelopeChannel, frames: Int) -> AudioEnvelope {
    var envelope = AudioEnvelope()
    var bands = [Float](repeating: 0, count: 16)
    var flux: Float = 0
    switch channel {
    case .low: for i in 0..<4 { bands[i] = 1 }
    case .mid: for i in 4..<10 { bands[i] = 1 }
    case .high: for i in 10..<16 { bands[i] = 1 }
    case .transient, .overall: flux = 1
    }
    for k in 0..<frames {
        envelope.update(bandEnergies: bands, flux: flux, onset: channel == .transient && k == 0,
                        time: Double(k + 1) / 60, elapsed: 1.0 / 60)
    }
    return envelope
}

@Suite struct OdysseyMappingCoreTests {
    @Test func mappingsAreKeptPerWorldAndResetRestoresTheDefaults() async throws {
        var engine = ExperienceEngine<OdysseyCore>(id: odysseyID)
        try await engine.prepare(seed: 7)
        try engine.activate()
        let start = try engine.digest()
        // Tunnel: width ← highs, high sensitivity.
        #expect(engine.handle(control: "mapping.set", values: [0, 2, 2]).isAccepted)
        let tunnel = WorldMapping(primary: ChannelMapping(channel: .high, sensitivity: .high),
                                  light: ChannelMapping(channel: .overall))
        #expect(try #require(engine.core).state.mapping(for: .tunnel) == tunnel)
        #expect(try #require(engine.core).state.mapping(for: .landscape) == .defaults(for: .landscape))
        #expect(try #require(engine.core).state.mapping(for: .starCorridor) == .defaults(for: .starCorridor))
        #expect(try engine.digest() != start)
        // Landscape: light ← beats, low sensitivity; the tunnel keeps its own.
        #expect(engine.handle(control: "world.select", values: [1]).isAccepted)
        #expect(engine.handle(control: "mapping.set", values: [1, 3, 0]).isAccepted)
        let landscape = WorldMapping(primary: ChannelMapping(channel: .mid),
                                     light: ChannelMapping(channel: .transient, sensitivity: .low))
        #expect(try #require(engine.core).state.mapping(for: .landscape) == landscape)
        #expect(try #require(engine.core).state.mapping(for: .tunnel) == tunnel)
        // Switching back restores the tunnel's mapping.
        #expect(engine.handle(control: "world.select", values: [0]).isAccepted)
        let state = try #require(engine.core).state
        #expect(state.mapping(for: state.world) == tunnel)
        #expect(state.mapping(for: .landscape) == landscape)
        // Out-of-range values change nothing.
        let before = try engine.digest()
        #expect(engine.handle(control: "mapping.set", values: [0, 5, 0]) == .rejected(.outOfRange(index: 1)))
        #expect(engine.handle(control: "mapping.set", values: [0, 0, 3]) == .rejected(.outOfRange(index: 2)))
        #expect(try engine.digest() == before)
        // Reset: every world back to its default.
        #expect(engine.handle(control: "mapping.reset").isAccepted)
        #expect(try #require(engine.core).state.mappings == WorldMapping.allDefaults)
        // The mappings travel in the snapshot.
        #expect(engine.handle(control: "mapping.set", values: [1, 1, 2]).isAccepted)
        let snapshot = try engine.snapshot()
        var other = ExperienceEngine<OdysseyCore>(id: odysseyID)
        try await other.prepare(seed: 3)
        try other.activate()
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        #expect(try #require(other.core).state.mappings == #require(engine.core).state.mappings)
        #expect(try other.digest() == engine.digest())
    }

    @Test func aPulseOnOneChannelRaisesOnlyTheResponsesMappedToIt() {
        let pulses: [EnvelopeChannel] = [.low, .mid, .high, .transient]
        for world in JourneyWorld.allCases {
            for pulse in pulses {
                for other in pulses where other != pulse {
                    for (primary, light) in [(pulse, other), (other, pulse)] {
                        let mapping = WorldMapping(primary: ChannelMapping(channel: primary),
                                                   light: ChannelMapping(channel: light))
                        var response = WorldResponse(world: world, reduceMotion: false, reduceFlashing: false)
                        var envelope = AudioEnvelope()
                        var bands = [Float](repeating: 0, count: 16)
                        var flux: Float = 0
                        switch pulse {
                        case .low: for i in 0..<4 { bands[i] = 1 }
                        case .mid: for i in 4..<10 { bands[i] = 1 }
                        case .high: for i in 10..<16 { bands[i] = 1 }
                        case .transient, .overall: flux = 1
                        }
                        var broken = 0
                        for k in 0..<40 {
                            envelope.update(bandEnergies: bands, flux: flux, onset: pulse == .transient && k == 0,
                                            time: Double(k + 1) / 60, elapsed: 1.0 / 60)
                            let previous = response
                            let targets = mapping.target(from: envelope)
                            response.update(primaryTarget: targets.primary, lightTarget: targets.light)
                            if !response.primaryRange.contains(response.primary)
                                || !response.lightRange.contains(response.light)
                                || abs(response.primary - previous.primary) > response.primaryStepLimit + 1e-12
                                || abs(response.light - previous.light) > response.lightStepLimit + 1e-12 {
                                broken += 1
                            }
                        }
                        let label = "\(world) pulse \(pulse), primary ← \(primary), light ← \(light)"
                        #expect(broken == 0, "\(label): bounds or steps broken \(broken) times")
                        if primary == pulse {
                            #expect(response.primary > response.primaryRest + 1e-6, "\(label): primary rose")
                            #expect(response.light == response.lightRest, "\(label): light stayed at rest")
                        } else {
                            #expect(response.light > response.lightRest + 1e-6, "\(label): light rose")
                            #expect(response.primary == response.primaryRest, "\(label): primary stayed at rest")
                        }
                    }
                }
            }
        }
        // The overall channel is derived: a pulse on low, mid or high raises a response mapped to it.
        for pulse in [EnvelopeChannel.low, .mid, .high] {
            let envelope = pulsed(pulse, frames: 20)
            #expect(envelope.overall > 0.2 && envelope.value(.overall) == envelope.overall, "\(pulse)")
            #expect(envelope.transient == 0, "\(pulse): no beat without flux")
        }
        #expect(pulsed(.transient, frames: 20).overall == 0, "a beat alone leaves the overall channel at rest")
    }

    @Test func theSchemaOneAndTwoExamplesMigrate() async throws {
        let one = try #require(OdysseyCore.schemaOneExample())
        let two = try #require(OdysseyCore.schemaTwoExample())
        #expect(one.version == 1 && two.version == 2)
        let problems = await SnapshotMigrationCheck.problems(for: OdysseyCore.self, id: odysseyID, examples: [one, two])
        #expect(problems.isEmpty, "\(problems)")
        // The schema-2 payload restored: the journey kept, the slow preset as target, the new fields at their defaults.
        var engine = ExperienceEngine<OdysseyCore>(id: odysseyID)
        try await engine.prepare(seed: 3)
        try engine.activate()
        try engine.restore(ExperienceSnapshot(data: two.snapshot))
        let state = try #require(engine.core).state
        #expect(state.world == .starCorridor && state.distance == 40.25 && state.speed == 1.5 && state.paused)
        #expect(state.source == .microphone)
        #expect(state.speedTarget == 2 && state.easing == .standard && !state.calmMotion)
        #expect(state.mappings == WorldMapping.allDefaults)
        #expect(try engine.digest().hex == two.expectedDigest)
        #expect(state.digestText.hasPrefix("a07.journey.v3|"))
    }
}

/// A microphone permission double: a fixed state and the answer the one request gives.
@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState = .granted
    func request() async -> MicrophonePermissionState { .granted }
}

/// A source double whose samples the test writes: `pump(amplitude:)` adds one frame's worth (800 samples at 48 kHz)
/// of an 80 Hz sine (inside the low bands) with the given amplitude.
@MainActor
private final class ToneSource: AudioSource {
    let label: String
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle
    private var buffer: SampleRingBuffer?
    private var phase = 0.0
    private var block = [Float](repeating: 0, count: 800)

    init(_ label: String) { self.label = label }

    func start(into buffer: SampleRingBuffer) throws {
        self.buffer = buffer
        state = .running
    }

    func stop() {
        buffer = nil
        state = .idle
    }

    func pump(amplitude: Float) {
        guard let buffer else { return }
        let step = 2 * Double.pi * 80 / sampleRate
        for i in block.indices {
            block[i] = amplitude * Float(sin(phase))
            phase += step
        }
        phase = phase.truncatingRemainder(dividingBy: 2 * Double.pi)
        block.withUnsafeBufferPointer { buffer.write($0) }
    }
}

/// Every source double the factory made, in order.
@MainActor
private final class ToneLog {
    var made: [ToneSource] = []

    var factory: OdysseySourceFactory {
        OdysseySourceFactory(demo: { [unowned self] _ in record("demo") },
                             file: { [unowned self] _ in record("file") },
                             microphone: { [unowned self] _ in record("microphone") })
    }

    private func record(_ label: String) -> ToneSource {
        let source = ToneSource(label)
        made.append(source)
        return source
    }
}

@MainActor
final class OdysseyMappingSessionTests: XCTestCase {
    private func open(_ session: ExperienceSession, log: ToneLog) async throws -> ExperienceShell<OdysseyPresenter> {
        let id = odysseyID
        let factory = log.factory
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id, permission: GrantedPermission(), factory: factory)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        return shell
    }

    private func core(_ shell: ExperienceShell<OdysseyPresenter>) throws -> OdysseyCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames, pumping the last source with `amplitude` before each, and checks after every frame that
    /// the presenter's response is a `WorldResponse` of the drawn world moved by exactly the targets of the world's
    /// mapping of the presenter's envelope (a shadow response updated alongside).
    private func frames(_ session: ExperienceSession, _ shell: ExperienceShell<OdysseyPresenter>, log: ToneLog,
                        _ count: Int, amplitude: Float, file: StaticString = #filePath, line: UInt = #line) throws {
        let host = try XCTUnwrap(session.renderHost)
        let presenter = shell.presenter
        for _ in 0..<count {
            var shadow = presenter.response
            log.made.last?.pump(amplitude: amplitude)
            XCTAssertTrue(host.renderOneFrame(present: false), file: file, line: line)
            let state = try core(shell).state
            if shadow.world != state.world {
                shadow = WorldResponse(world: state.world, reduceMotion: false, reduceFlashing: false)
            }
            let targets = state.mapping(for: state.world).target(from: presenter.envelope)
            shadow.update(primaryTarget: targets.primary, lightTarget: targets.light)
            XCTAssertEqual(presenter.response, shadow, "the response follows the world's mapping", file: file,
                           line: line)
        }
    }

    func testTheMappedLowToneRaisesThePrimaryAndEachWorldAppliesItsScale() async throws {
        let session = ExperienceSession()
        let log = ToneLog()
        let shell = try await open(session, log: log)
        let presenter = shell.presenter
        for world in JourneyWorld.allCases {
            XCTAssertTrue(shell.handle(control: "world.select", values: [Double(world.rawValue)]).isAccepted)
            // Primary ← bass (high sensitivity), light ← beats.
            XCTAssertTrue(shell.handle(control: "mapping.set", values: [0, 0, 2]).isAccepted)
            XCTAssertTrue(shell.handle(control: "mapping.set", values: [1, 3, 1]).isAccepted)
            try frames(session, shell, log: log, 2, amplitude: 0)
            let rest = presenter.response.primaryRest
            try frames(session, shell, log: log, 45, amplitude: 0.7)
            let response = presenter.response
            XCTAssertEqual(response.world, world)
            XCTAssertGreaterThan(response.primary, rest + 0.1 * (response.primaryRange.upperBound - rest),
                                 "\(world): the bass raised the primary")
            // One model matrix for every piece of the frame, with the response's primary scale.
            let state = try core(shell).state
            let rail = try XCTUnwrap(presenter.rail)
            let pose = rail.pose(at: state.distance)
            let origin = presenter.rebase.origin
            let expected: Mat4
            switch world {
            case .tunnel, .starCorridor:
                expected = OdysseyPresenter.breathingModel(scale: response.primaryScale, centre: pose.position,
                                                           direction: pose.direction, origin: origin)
            case .landscape:
                expected = OdysseyPresenter.swellModel(scale: response.primaryScale,
                                                       centre: pose.position - pose.up * WorldPieces.landscapeDrop,
                                                       up: pose.up, origin: origin)
            }
            XCTAssertEqual(presenter.lastModel, expected, "\(world)")
            XCTAssertGreaterThan(response.primaryScale, 1)
        }
        // The landscape swell scales along the local up only, about the strip's base.
        let centre = Vec3(4, -1, 2), up = Vec3(0, 1, 0), origin = Vec3(1, 1, 1)
        let swell = OdysseyPresenter.swellModel(scale: 1.5, centre: centre, up: up, origin: origin)
        func apply(_ p: Vec3) -> Vec3 {
            let v = swell * Vec4(p, 1)
            return Vec3(v.x, v.y, v.z)
        }
        XCTAssertEqual((apply(centre + Vec3(0, 2, 0)) - (centre + Vec3(0, 3, 0) - origin)).length, 0, accuracy: 1e-12)
        XCTAssertEqual((apply(centre + Vec3(5, 0, -3)) - (centre + Vec3(5, 0, -3) - origin)).length, 0,
                       accuracy: 1e-12, "1 across the up axis")
        XCTAssertEqual(OdysseyPresenter.swellModel(scale: 1, centre: centre, up: up, origin: origin),
                       Mat4.translation(-origin))
        XCTAssertTrue(shell.accessibilitySummary.contains("units per second"), shell.accessibilitySummary)
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testCalmMotionIsDescribedAndHalvesThePrimaryRange() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, log: ToneLog())
        XCTAssertTrue(shell.handle(control: "speed.set", values: [2.5]).isAccepted)
        XCTAssertTrue(shell.handle(control: "easing.select", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "comfort.calm", values: [1]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix(
            "Audio Odyssey: Tunnel, 2.5 units per second, gentle easing, calm motion, flying, "),
                      shell.accessibilitySummary)
        let response = shell.presenter.response
        XCTAssertTrue(response.reduceMotion, "in-app calm motion narrows the response like Reduce Motion")
        XCTAssertEqual(response.primaryRange.upperBound, WorldResponse.maxPrimary(for: .tunnel) / 2)
        XCTAssertEqual(shell.presenter.mirror.speedTarget, 2.5)
        XCTAssertEqual(shell.presenter.mirror.easing, .gentle)
        XCTAssertTrue(shell.presenter.mirror.calmMotion)
        session.close()
    }

    func testFiveSourceSwitchesKeepTheHostAndTheJourney() async throws {
        let session = ExperienceSession()
        let log = ToneLog()
        let shell = try await open(session, log: log)
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)
        try frames(session, shell, log: log, 30, amplitude: 0.3)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("odyssey-mapping.wav")
        var switches = 0
        for choice in ["microphone", "file", "demo", "file", "demo"] {
            let before = try core(shell).state
            XCTAssertGreaterThan(before.distance, 0)
            switch choice {
            case "microphone":
                let result = await presenter.chooseMicrophone()
                XCTAssertTrue(result.isAccepted)
            case "file":
                XCTAssertTrue(presenter.chooseFile(url: file))
            default:
                XCTAssertTrue(shell.handle(control: "source.demo").isAccepted)
            }
            switches += 1
            let after = try core(shell).state
            XCTAssertEqual(after.source.displayName.lowercased().hasPrefix(choice == "demo" ? "demo" : choice), true,
                           "\(choice): \(after.source)")
            XCTAssertEqual(after.distance, before.distance, "\(choice): the switch keeps the distance")
            XCTAssertEqual(after.speed, before.speed, "\(choice): the switch keeps the speed")
            XCTAssertEqual(after.speedTarget, before.speedTarget)
            XCTAssertEqual(after.world, before.world)
            XCTAssertEqual(after.seed, before.seed)
            XCTAssertEqual(session.hostsAlive, 1, choice)
            XCTAssertTrue(session.renderHost === host, "\(choice): the same drawing context")
            try frames(session, shell, log: log, 5, amplitude: 0.3)
            XCTAssertGreaterThan(try core(shell).state.distance, after.distance, "\(choice): the flight continues")
        }
        XCTAssertEqual(switches, 5)
        XCTAssertEqual(log.made.filter { $0.state == .running }.count, 1, "only the last source runs")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }
}
