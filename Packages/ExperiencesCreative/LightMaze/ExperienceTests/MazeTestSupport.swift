// MazeTestSupport — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121). Shared helpers of the Light Maze
// experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels of a
// frame (rows bottom-up, as the host reads them back), counting the pixels two frames differ in, finding pixels near a
// colour, and building snapshot envelopes and payloads.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias MazeFrame = (rgba: [UInt8], width: Int, height: Int)

@MainActor
enum MazeTest {
    /// The experience id `a13.light-maze`.
    static var id: ExperienceID { LightMazeExperience.id ?? ExperienceID(rawValue: "a13.unknown")! }

    /// Opens Light Maze in `session` (seed `seed`, optionally restoring `snapshot`, with `voiceOverRunning` and
    /// `announcementSink` replacing the system's when given), lays the view out at `size` points and draws one frame.
    /// The session holds the experience (`MazeExperience`); its shell is returned.
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 120, height: 100),
                     voiceOverRunning: (@MainActor () -> Bool)? = nil,
                     announcementSink: (any AnnouncementSink)? = nil) async throws -> ExperienceShell<MazePresenter> {
        let id = self.id
        var made: ExperienceShell<MazePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let experience = LightMazeExperience.make(id: id, voiceOverRunning: voiceOverRunning,
                                                      announcementSink: announcementSink)
            made = experience.shell
            return experience
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
    static func core(_ shell: ExperienceShell<MazePresenter>) throws -> MazeCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> MazeFrame {
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

    /// The number of pixels of `frame` within `tolerance` (per channel, of 255) of the colour `color` (channels 0…1).
    static func pixels(near color: Vec4, in frame: MazeFrame, tolerance: Int = 24) -> Int {
        let r = Int((color.x * 255).rounded()), g = Int((color.y * 255).rounded()), b = Int((color.z * 255).rounded())
        var count = 0
        var i = 0
        while i + 3 < frame.rgba.count {
            if abs(Int(frame.rgba[i]) - r) <= tolerance && abs(Int(frame.rgba[i + 1]) - g) <= tolerance
                && abs(Int(frame.rgba[i + 2]) - b) <= tolerance { count += 1 }
            i += 4
        }
        return count
    }

    /// The number of pixels two frames differ in (as ``differingPixels(_:_:)``) inside the square of half-size
    /// `radius` pixels around the pixel `center` (x from the left, y from the bottom).
    static func differingPixels(_ a: MazeFrame, _ b: MazeFrame, around center: Vec2, radius: Int) -> Int {
        guard a.rgba.count == b.rgba.count, a.width == b.width, a.height == b.height else { return -1 }
        let cx = Int(center.x.rounded(.down)), cy = Int(center.y.rounded(.down))
        var count = 0
        for y in (cy - radius)...(cy + radius) where y >= 0 && y < a.height {
            for x in (cx - radius)...(cx + radius) where x >= 0 && x < a.width {
                let i = (y * a.width + x) * 4
                if abs(Int(a.rgba[i]) - Int(b.rgba[i])) > 16 || abs(Int(a.rgba[i + 1]) - Int(b.rgba[i + 1])) > 16
                    || abs(Int(a.rgba[i + 2]) - Int(b.rgba[i + 2])) > 16 { count += 1 }
            }
        }
        return count
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func mazeDigest(_ core: MazeCore) throws -> String {
    var builder = DigestBuilder(domain: MazeCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A core holding `state`, prepared with `seed`, through the restore path.
func mazeCore(_ state: MazeState, seed: UInt64 = 1) throws -> MazeCore {
    try MazeCore.restore(payload: state.encoded(), seed: seed)
}

/// A snapshot envelope of Light Maze around `payload` with the fields of `saved` and schema `schema`.
func mazeEnvelope(_ payload: Data, like saved: ExperienceSnapshot, schema: Int = 1) throws -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: MazeCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                                  stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a maze state's JSON) with `change` applied to its top-level object, as JSON with sorted keys.
func mazePayload(_ payload: String, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
