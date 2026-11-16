// MoleculeTestSupport — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104) and feature 111
// (A15-P02) T-A15-205 (snapshot envelopes at schema 2; FR-A15-221). Shared helpers of
// the Molecular Explorer experience tests: opening the experience in the one app's session host with a real view size
// (a view without a frame size does not draw), drawing frames, reading the pixels of a frame (rows bottom-up, as the
// host reads them back), counting the pixels two frames differ in, and building snapshot envelopes and payloads.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias MoleculeFrame = (rgba: [UInt8], width: Int, height: Int)

/// Opening, drawing and reading Molecular Explorer in the session host.
@MainActor
enum MoleculeTest {
    /// The experience id `a15.molecular-explorer`.
    static var id: ExperienceID {
        MolecularExplorerExperience.id ?? ExperienceID(rawValue: "a15.unknown")!
    }

    /// Opens Molecular Explorer in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at
    /// `size` points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 240, height: 160)) async throws
        -> ExperienceShell<MoleculePresenter> {
        let id = self.id
        var made: ExperienceShell<MoleculePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = MolecularExplorerExperience.make(id: id)
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
    static func core(_ shell: ExperienceShell<MoleculePresenter>) throws -> MoleculeCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> MoleculeFrame {
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
    static func pixels(near color: Vec4, in frame: MoleculeFrame, tolerance: Int = 24) -> Int {
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
func moleculeDigest(_ core: MoleculeCore) throws -> String {
    var builder = DigestBuilder(domain: MoleculeCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A core holding `state`, prepared with `seed`, through the restore path.
func moleculeCore(_ state: MoleculeState, seed: UInt64 = 1) throws -> MoleculeCore {
    try MoleculeCore.restore(payload: state.encoded(), seed: seed)
}

/// A snapshot envelope of Molecular Explorer around `payload` with the fields of `saved` and schema `schema` (the
/// current schema 2 by default).
func moleculeEnvelope(_ payload: Data, like saved: ExperienceSnapshot, schema: Int = MoleculeState.schemaVersion) throws
    -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: MoleculeCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                                  stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a state's JSON) with `key` set to `value` (nil removes it) in its top-level object, as JSON with sorted
/// keys.
func moleculePayload(_ payload: String, key: String, value: Any?) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    object[key] = value
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
