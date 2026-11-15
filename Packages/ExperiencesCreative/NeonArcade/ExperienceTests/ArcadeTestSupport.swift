// ArcadeTestSupport — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121). Shared helpers of the Neon Arcade
// experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels of a
// frame and counting the pixels two frames differ in.
// Feature 077 (A10-P03) T-A10-304: the experience opens on the title screen, so `open` starts the game unless asked
// not to (a restored state keeps its screen); recording sound and haptic sinks and a feedback route over them.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// Records the sounds played and the stops (feature 077).
@MainActor
final class RecordingSoundSink: ArcadeSoundSink {
    private(set) var played: [String] = []
    private(set) var stops = 0
    func play(_ sound: ArcadeSound) { played.append(sound.id) }
    func stopAll() { stops += 1 }
}

/// Records the haptics played (feature 077).
@MainActor
final class RecordingHapticSink: HapticSink {
    private(set) var played: [HapticKind] = []
    func play(_ kind: HapticKind) { played.append(kind) }
}

@MainActor
enum ArcadeTest {
    /// The experience id `a10.neon-arcade`.
    static var id: ExperienceID { NeonArcadeExperience.id ?? ExperienceID(rawValue: "a10.unknown")! }

    /// A feedback route over `sink` whose clock moves one second per call (so the rate limit never drops one).
    static func feedback(_ sink: RecordingHapticSink) -> ExperienceFeedback {
        var now = 0.0
        return ExperienceFeedback(hapticSink: sink, clock: {
            now += 1
            return now
        }, voiceOverRunning: { false })
    }

    /// Opens Neon Arcade in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at `size`
    /// points, sends `run.start` when `start` is true and the experience shows the title screen, and draws one frame.
    /// Without a `soundSink` a recorder is used, so tests never play audio.
    static func openExperience(_ session: ExperienceSession, seed: UInt64 = 7, snapshot: ExperienceSnapshot? = nil,
                               reduceMotion: Bool = false, reduceFlashing: Bool = false,
                               soundSink: (any ArcadeSoundSink)? = nil, feedback: ExperienceFeedback? = nil,
                               start: Bool = true,
                               size: CGSize = CGSize(width: 90, height: 160)) async throws -> ArcadeExperience {
        let id = self.id
        var made: ArcadeExperience?
        let sound = soundSink ?? RecordingSoundSink()
        let route = feedback ?? self.feedback(RecordingHapticSink())
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let experience = NeonArcadeExperience.make(id: id, reduceMotion: reduceMotion,
                                                       reduceFlashing: reduceFlashing, soundSink: sound,
                                                       feedback: route)
            made = experience
            return experience
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, SessionOpenResult.running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let experience = try XCTUnwrap(made)
        if start, experience.shell.engine.core?.screen == .title {
            XCTAssertTrue(experience.handle(control: "run.start", values: []).isAccepted)
        }
        try frames(session, 1)
        return experience
    }

    /// The shell of ``openExperience(_:seed:snapshot:reduceMotion:reduceFlashing:soundSink:feedback:start:size:)``.
    static func open(_ session: ExperienceSession, seed: UInt64 = 7, snapshot: ExperienceSnapshot? = nil,
                     reduceMotion: Bool = false, start: Bool = true,
                     size: CGSize = CGSize(width: 90, height: 160)) async throws -> ExperienceShell<ArcadePresenter> {
        try await openExperience(session, seed: seed, snapshot: snapshot, reduceMotion: reduceMotion, start: start,
                                 size: size).shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<ArcadePresenter>) throws -> ArcadeCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back (each advances the host by 1/60 s, one simulation step).
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> (rgba: [UInt8], width: Int, height: Int) {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The number of pixels whose RGB differs by more than 16 in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if abs(Int(a[i]) - Int(b[i])) > 16 || abs(Int(a[i + 1]) - Int(b[i + 1])) > 16
                || abs(Int(a[i + 2]) - Int(b[i + 2])) > 16 { count += 1 }
            i += 4
        }
        return count
    }

    /// A pointer event of finger `id` at view point (`x`, `y`).
    static func touch(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, at time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: time)
    }
}
