// AquariumTestSupport — feature 068 (A09-P01) T-A09-103 (FR-A09-120, FR-A09-121). Shared helpers of the Digital
// Aquarium experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels
// of a frame and counting the pixels two frames differ in.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
enum AquariumTest {
    /// The experience id `a09.digital-aquarium`.
    static var id: ExperienceID { DigitalAquariumExperience.id ?? ExperienceID(rawValue: "a09.unknown")! }

    /// Opens Digital Aquarium in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at `size`
    /// points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 7, snapshot: ExperienceSnapshot? = nil,
                     reduceMotion: Bool = false,
                     size: CGSize = CGSize(width: 160, height: 90)) async throws -> ExperienceShell<AquariumPresenter> {
        let id = self.id
        var made: ExperienceShell<AquariumPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = DigitalAquariumExperience.make(id: id, reduceMotion: reduceMotion)
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
    static func core(_ shell: ExperienceShell<AquariumPresenter>) throws -> AquariumCore {
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
}
