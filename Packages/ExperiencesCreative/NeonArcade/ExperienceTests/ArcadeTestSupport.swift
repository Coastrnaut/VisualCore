// ArcadeTestSupport — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121). Shared helpers of the Neon Arcade
// experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels of a
// frame and counting the pixels two frames differ in.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
enum ArcadeTest {
    /// The experience id `a10.neon-arcade`.
    static var id: ExperienceID { NeonArcadeExperience.id ?? ExperienceID(rawValue: "a10.unknown")! }

    /// Opens Neon Arcade in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at `size`
    /// points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 7, snapshot: ExperienceSnapshot? = nil,
                     reduceMotion: Bool = false,
                     size: CGSize = CGSize(width: 90, height: 160)) async throws -> ExperienceShell<ArcadePresenter> {
        let id = self.id
        var made: ExperienceShell<ArcadePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = NeonArcadeExperience.make(id: id, reduceMotion: reduceMotion)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        try frames(session, 1)
        return shell
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
