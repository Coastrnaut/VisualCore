// LissajousLabyrinthRendererPurityTests — feature 313 (R02-G02-03) T-R02G0203-005 (FR-R02G0203-003; clarification Q5;
// R2-G02-INV-10 renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation
// time, change the quality tier, step the host — leaves the adapter's digest, its state and the kernel's verdict
// unchanged, over 200 seeded snapshots (seed 2_313: random dial actions on certified levels); every snapshot copies the
// kernel's fields exactly (level, dials, stage, verdict == `LissajousLabyrinthLap.verdict`, visit ticks). Eight certified
// levels are generated once and reused, so the run stays short.
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct LissajousLabyrinthRendererPurityTests {
    typealias Core = LissajousLabyrinthExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly; `verdict` and `visits` are the kernel's
    /// (`LissajousLabyrinthLap.verdict` and the terminal's visit ticks for the play's dials).
    static func expectMirrors(_ snapshot: LissajousLabyrinthSceneSnapshot, _ core: Core,
                              verdict: LissajousLabyrinthVerdict, visits: [Int]) {
        let play: LissajousLabyrinthPlay = core.play
        #expect(snapshot.level == play.level)
        #expect(snapshot.dials == play.dials)
        #expect(snapshot.stage == play.stage)
        #expect(snapshot.verdict == verdict)
        #expect(snapshot.visits == visits)
    }

    /// The kernel's verdict and visit ticks for the dials of `core`.
    static func kernel(_ core: Core) -> (verdict: LissajousLabyrinthVerdict, visits: [Int]) {
        let play: LissajousLabyrinthPlay = core.play
        return (LissajousLabyrinthLap.verdict(play.dials, level: play.level),
                LissajousLabyrinthTerminal(play.dials, level: play.level).visits)
    }

    @Test func testLissajousLabyrinthRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: (verdict: LissajousLabyrinthVerdict, visits: [Int]) = Self.kernel(core)
        let lapSeconds: Double = Double(LissajousLabyrinthLap.ticks) / LissajousLabyrinthSceneSnapshot.headTicksPerSecond
        let times: [Double] = [0, lapSeconds - 0.001, lapSeconds, -1, .infinity, .nan]
        for time in times {
            let snapshot: LissajousLabyrinthSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core, verdict: expected.verdict, visits: expected.visits)
            #expect(snapshot.headTick >= 0 && snapshot.headTick < LissajousLabyrinthLap.ticks)
            #expect(try Self.digest(core) == before)
        }
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.kernel(core).verdict == expected.verdict && Self.kernel(core).visits == expected.visits)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Eight certified levels (tutorial and every band), generated once.
        let numbers: [Int] = [1, 4, 13, 32, 42, 64, 99, 100]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_313)
        var accepted: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // A few seeded dial actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...4) {
                let dial: Int = random.int(0...3)
                let range: ClosedRange<Int> = Core.dialOrder[dial].range
                let values: [Double] = [Double(dial), Double(random.int(range))]
                if core.apply(ExperienceAction(control: "dial.set", values: values, step: 0)).isAccepted {
                    accepted += 1
                }
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: (verdict: LissajousLabyrinthVerdict, visits: [Int]) = Self.kernel(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: LissajousLabyrinthSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core, verdict: expected.verdict, visits: expected.visits)
                core.update(step: 1)
            }
            core.setQualityTier(random.int(0...2))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.kernel(core).verdict == expected.verdict)
        }
        #expect(accepted > 100)
    }
}
