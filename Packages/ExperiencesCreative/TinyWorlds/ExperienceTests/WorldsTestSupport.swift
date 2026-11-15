// WorldsTestSupport — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121). Shared helpers of the Tiny Worlds
// experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels of a
// frame, counting the pixels two frames differ in, and building a core that holds a given world state. Feature 090
// (A12-P02) T-A12-205: the experience can be opened with Reduce Motion, a fixed system setting and a recording
// announcement sink with VoiceOver reported running, and frames can be drawn until the drawn view settles.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

@MainActor
enum WorldsTest {
    /// The experience id `a12.tiny-worlds`.
    static var id: ExperienceID { TinyWorldsExperience.id ?? ExperienceID(rawValue: "a12.unknown")! }

    /// Opens Tiny Worlds in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at `size`
    /// points and draws one frame. The system's Reduce Motion is reported off; `announcements`, when given, records
    /// what is spoken with VoiceOver reported running (otherwise VoiceOver is reported off).
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 120, height: 100), reduceMotion: Bool = false,
                     announcements: RecordingAnnouncementSink? = nil) async throws
        -> ExperienceShell<WorldsPresenter> {
        let id = self.id
        var made: ExperienceShell<WorldsPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let voiceOver = announcements != nil
            let shell = TinyWorldsExperience.make(id: id, reduceMotion: reduceMotion, systemReduceMotion: { false },
                                                  voiceOverRunning: { voiceOver },
                                                  announcementSink: announcements ?? RecordingAnnouncementSink())
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
    static func core(_ shell: ExperienceShell<WorldsPresenter>) throws -> WorldsCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// Draws frames (1/60 s each) until the drawn view has reached the state's view, at most 30 (0.5 s).
    static func settle(_ session: ExperienceSession, _ shell: ExperienceShell<WorldsPresenter>) throws {
        for _ in 0..<30 {
            try frames(session, 1)
            if shell.presenter.lastDrawnView == shell.engine.core?.view { return }
        }
        XCTFail("the drawn view did not settle within 0.5 s")
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

/// The digest of `core` as the engine computes it (the experience id as domain).
func worldsDigest(_ core: WorldsCore) throws -> String {
    var builder = DigestBuilder(domain: WorldsCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A core holding `state`, prepared with `seed`, through the restore path.
func worldsCore(_ state: WorldState, seed: UInt64 = 1) throws -> WorldsCore {
    try WorldsCore.restore(payload: state.encoded(), seed: seed)
}

/// A snapshot envelope of Tiny Worlds around `payload` with the fields of `saved` and schema `schema`.
func worldsEnvelope(_ payload: Data, like saved: ExperienceSnapshot, schema: Int = 1) throws -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: WorldsCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                           stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a world state's JSON) with `change` applied to its top-level object, as JSON with sorted keys.
func worldsPayload(_ payload: String, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
