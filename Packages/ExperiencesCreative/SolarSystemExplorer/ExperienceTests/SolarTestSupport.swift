// SolarTestSupport — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5). Shared helpers of the
// Solar System Explorer experience tests: opening the experience in the one app's session host, drawing frames,
// reading the pixels of a frame (rows bottom-up, as the host reads them back), counting the pixels two frames differ
// in, and building snapshot envelopes and payloads.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias SolarFrame = (rgba: [UInt8], width: Int, height: Int)

@MainActor
enum SolarTest {
    /// The experience id `a14.solar-system-explorer`.
    static var id: ExperienceID {
        SolarSystemExplorerExperience.id ?? ExperienceID(rawValue: "a14.unknown")!
    }

    /// Opens Solar System Explorer in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at
    /// `size` points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 240, height: 160)) async throws -> ExperienceShell<SolarPresenter> {
        let id = self.id
        var made: ExperienceShell<SolarPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = SolarSystemExplorerExperience.make(id: id)
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
    static func core(_ shell: ExperienceShell<SolarPresenter>) throws -> SolarCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> SolarFrame {
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

    /// The number of pixels two frames differ in (as ``differingPixels(_:_:)``) inside the square of half-size
    /// `radius` pixels around the pixel `center` (x from the left, y from the bottom).
    static func differingPixels(_ a: SolarFrame, _ b: SolarFrame, around center: Vec2, radius: Int) -> Int {
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

    /// The number of pixels of `frame` within `tolerance` (per channel, of 255) of the colour `color` (channels 0…1).
    static func pixels(near color: Vec4, in frame: SolarFrame, tolerance: Int = 24) -> Int {
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
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func solarDigest(_ core: SolarCore) throws -> String {
    var builder = DigestBuilder(domain: SolarCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A core holding `state`, prepared with `seed`, through the restore path.
func solarCore(_ state: SolarState, seed: UInt64 = 1) throws -> SolarCore {
    try SolarCore.restore(payload: state.encoded(), seed: seed)
}

/// A snapshot envelope of Solar System Explorer around `payload` with the fields of `saved` and schema `schema`.
func solarEnvelope(_ payload: Data, like saved: ExperienceSnapshot,
                   schema: Int = SolarState.schemaVersion) throws -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: SolarCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                                  stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a state's JSON) with `change` applied to its top-level object, as JSON with sorted keys.
func solarPayload(_ payload: String, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
