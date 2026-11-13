// ParticleSessionTests — feature 193 (UA-F07) T-U07-027 (FR-U07-003, FR-U07-011; SC-U07-003, SC-U07-011). The A04
// adapter inside the one app's session host on the simulator, with short runs only: open with the first frame and its
// probe, close without GPU objects across the families, suspension, a memory warning and a context recreation that
// keep the digest, repeated opens, a save and restore by replay, and a short replay's cost per step on this runtime.
// Hosted by the VisualCore app.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ParticleSessionTests: XCTestCase {
    private var id: ExperienceID { ParticleExperience.id ?? ExperienceID(rawValue: "a04.unknown")! }

    private func request(seed: UInt64 = ParticleCore.manifestSeed, snapshot: ExperienceSnapshot? = nil,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: snapshot != nil) {
            // A throwaway storage area (feature 036 A04-P04: the experience keeps its scene library there).
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("pu-session-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "pu-session-tests")!)
            let experience = ParticleExperience.make(id: id, storage: storage, reduceMotion: false, reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession) {
        guard let view = session.renderHost?.view else { return }
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
    }

    private func digest(_ experience: (any Experience)?) throws -> String {
        let shell = try XCTUnwrap(experience as? ExperienceShell<ParticlePresenter>)
        return try shell.engine.digest().hex
    }

    func testOpeningDrawsTheFirstFrameAndItsProbeMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let experience = try XCTUnwrap(session.experience)
        try experience.reset()
        XCTAssertEqual(try digest(experience), ParticleCore.initialDigest)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let probes = experience.frameProbes
        XCTAssertEqual(probes.count, 1, "the background above the fountain")
        let size = host.pixelSize
        let pixels = host.readPixels()
        for probe in probes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue,
                           probe.expected, probe.name)
        }
        XCTAssertTrue(experience.accessibilitySummary.hasPrefix("Particle scene: Fountain"), experience.accessibilitySummary)
    }

    func testCloseLeavesNoGPUObjectAcrossFamilies() async throws {
        let session = ExperienceSession()
        for family in 0..<EmitterFamily.allCases.count {
            var made: (any Experience)?
            let opened = await session.open(request { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let experience = try XCTUnwrap(made)
            if family > 0 { XCTAssertTrue(experience.handle(control: "family", values: [Double(family)]).isAccepted) }
            XCTAssertTrue(experience.handle(control: "trails", values: [1]).isAccepted)
            for _ in 0..<5 { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
            session.close()
            let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
            XCTAssertEqual(counts.objects, 0, "family \(family)")
            XCTAssertEqual(counts.leaked, 0, "family \(family)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testSuspensionMemoryWarningAndContextRecreationKeepTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(experience.handle(control: "force.place", values: [0.75, 0.25]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        session.setScenePhase(.background)
        let before = try digest(experience)
        session.setScenePhase(.active)
        XCTAssertEqual(try digest(experience), before, "no steps for the time away")
        session.handleMemoryWarning()
        XCTAssertEqual(try digest(experience), before)
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try digest(experience), before)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testTwentyOpensAndClosesLeaveNothingBehind() async throws {
        let session = ExperienceSession()
        for cycle in 0..<20 {
            let opened = await session.open(request(seed: UInt64(cycle)))
            XCTAssertEqual(opened, .running)
            layOut(session)
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testASavedStateRestoresByReplayAndAShortReplayGivesTheCostPerStep() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(experience.handle(control: "emitter.add", values: []).isAccepted)
        for _ in 0..<10 { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
        let snapshot = try experience.snapshot()
        let saved = try digest(experience)
        session.close()
        let restored = await session.open(request(snapshot: snapshot))
        XCTAssertEqual(restored, .running)
        // The open drew a frame, which may have run steps after the restore; the restore itself is checked on a
        // fresh engine below.
        var engine = ExperienceEngine<ParticleCore>(id: id)
        try await engine.prepare(seed: ParticleCore.manifestSeed)
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, saved)

        // A short replay (10 simulated seconds) on this runtime gives the cost per step (tests are short).
        let clock = ContinuousClock()
        let start = clock.now
        _ = try ParticleCore.replay(seed: 3, log: [], steps: 1_200)
        let elapsed = clock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        print("UA-F07 A04 replay on the simulator: 1200 steps in \(String(format: "%.3f", seconds)) s; "
              + "the 10 s limit holds about \(String(format: "%.1f", 10 / max(seconds, 1e-9) * 10 / 60)) simulated minutes")
        XCTAssertLessThan(seconds, 10)
    }
}
