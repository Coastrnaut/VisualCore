// ParticleProfileTests — feature 037 (A04-P05) T-A04-508 (FR-A04-520; research D4; SC-A04-504). A scripted simulator
// session of Particle Universe (open, about 120 frames, close) prints one `PROFILE:` line: the session's performance
// record as JSON with `"source":"simulator"`. Simulator values are never device evidence. Hosted by the VisualCore app.
import XCTest
@testable import ParticleUniverseExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ParticleProfileTests: XCTestCase {
    func testAScriptedSessionPrintsOneProfileLine() async throws {
        let id = try XCTUnwrap(ParticleExperience.id)
        let session = ExperienceSession()
        let request = ExperienceOpenRequest(id: id, seed: ParticleCore.manifestSeed, snapshot: nil,
                                            refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("pu-profile-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "pu-profile-tests")!)
            return ParticleExperience.make(id: id, storage: storage, reduceMotion: false, reduceFlashing: false)
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        for _ in 0..<120 { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
        session.close()

        let record = try XCTUnwrap(session.lastPerformanceRecord, "the session builds a record when it closes")
        XCTAssertEqual(record.experience, ParticleCore.experienceID)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: record.encoded()) as? [String: Any])
        object["source"] = "simulator"
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("\n"), "one line")
        let line = "PROFILE: " + json
        print(line)

        let parsed = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(line.dropFirst("PROFILE: ".count).utf8)) as? [String: Any])
        XCTAssertEqual(parsed["source"] as? String, "simulator")
        XCTAssertEqual(parsed["experience"] as? String, "a04.particle-universe")
        XCTAssertNotNil(parsed["pacing"])
    }
}
