// AuroraLoomRendererPurityTests — feature 303 (R02-G01-03) T-R02G0103-007 (FR-R02G0103-003; SC-R02G0103-002;
// R2-G01-INV-10 renderer purity). Everything the renderer can do with a snapshot — read it at any time, build the
// geometry and the camera at any tier and aspect, change the quality tier — leaves the adapter's digest, its state and
// the kernel's verdict unchanged, over 200 seeded snapshots; a direct boundary example and a seeded neighbouring check.
// (The GL side — drawing, a forced shader failure — is checked on the simulator in AuroraLoomFallbackTests.)
@testable import AuroraLoomCore
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@Suite struct AuroraLoomRendererPurityTests {
    typealias Core = AuroraLoomExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Everything a frame may do with `core`: snapshots at several times, geometry at every tier and two aspects.
    static func drawLikeTheRenderer(_ core: Core, time: Double) throws {
        let snapshot: AuroraLoomSceneSnapshot = core.snapshot(time: time)
        for tier in AuroraLoomTier.all {
            _ = try AuroraLoomSceneGeometry.ribbonMeshes(snapshot: snapshot, tier: tier)
        }
        for gate in 0..<4 {
            _ = AuroraLoomSceneGeometry.gateRing(gate: gate, snapshot: snapshot)
            _ = AuroraLoomSceneGeometry.marker(gate: gate, snapshot: snapshot)
            for ribbon in 0..<3 { _ = snapshot.lit(ribbon: ribbon, gate: gate) }
        }
        _ = AuroraLoomSceneGeometry.referenceSamples(snapshot: snapshot, aspect: 1.5, width: 96, height: 64,
                                                     segments: 32)
        _ = AuroraLoomSceneGeometry.camera(aspect: 0.5)
    }

    @Test func testAuroraLoomRendererpurityBoundary() async throws {
        // Direct example: a prepared level, drawn at the boundary times 0 and just under two periods.
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let verdict: Bool = AuroraLoomHarmony.wins(core.play.steps, level: core.play.level)
        let span: Double = Double(2 * core.play.level.period)
        let times: [Double] = [0, span - 0.001, span, -1, .infinity]
        for time in times {
            try Self.drawLikeTheRenderer(core, time: time)
            #expect(try Self.digest(core) == before)
        }
        for tier in [0, 1, 2, 3, -1] {
            core.setQualityTier(tier)
            try Self.drawLikeTheRenderer(core, time: 1)
            #expect(try Self.digest(core) == before)
        }
        #expect(AuroraLoomHarmony.wins(core.play.steps, level: core.play.level) == verdict)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        var random = SeededRandom(seed: 2_303)
        for _ in 0..<200 {
            var core: Core = try await Core.prepare(seed: random.next() % 100)
            // A few seeded moves so the snapshots differ from the start.
            for _ in 0..<random.int(0...3) {
                let values: [Double] = [Double(random.int(0...2)), Double(random.int(0...1)), Double(random.int(0...15))]
                _ = core.apply(ExperienceAction(control: "ribbon.move", values: values, step: 0))
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let verdict: Bool = AuroraLoomHarmony.wins(core.play.steps, level: core.play.level)
            core.setQualityTier(random.int(0...2))
            let snapshot: AuroraLoomSceneSnapshot = core.snapshot(time: Double(random.int(0...100_000)) / 7)
            _ = try AuroraLoomSceneGeometry.ribbonMeshes(snapshot: snapshot, tier: core.renderTier)
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(AuroraLoomHarmony.wins(core.play.steps, level: core.play.level) == verdict)
        }
    }
}
