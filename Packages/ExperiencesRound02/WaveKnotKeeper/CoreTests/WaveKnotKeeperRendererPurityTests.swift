// WaveKnotKeeperRendererPurityTests — feature 323 (R02-G03-03) T-R02G0303-005 (FR-R02G0303-003; SC-R02G0303-002;
// clarification Q5; R2-G03-INV-10 renderer purity). Everything the renderer may do with the adapter — read snapshots at
// any presentation time, change the quality tier, step the host — leaves the adapter's digest, its state and the
// kernel's verdict unchanged, over 200 seeded snapshots (seed 2_323: random point moves and selections on certified
// levels); every snapshot copies the kernel's fields exactly (level number, points, gates, target, projection summary,
// crossing marks, stage, selection, verdict == `WaveKnotKeeperLevel.wins`). Four certified levels are generated once and
// reused, so the run stays short.
@testable import WaveKnotKeeperCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct WaveKnotKeeperRendererPurityTests {
    typealias Core = WaveKnotKeeperExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for the rope of `core`: whether its projection matches the level's target.
    static func verdict(_ core: Core) -> Bool {
        core.play.level.wins(core.play.points)
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly.
    static func expectMirrors(_ snapshot: WaveKnotKeeperSceneSnapshot, _ core: Core, verdict: Bool) {
        let play: WaveKnotKeeperPlay = core.play
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.points == play.points)
        #expect(snapshot.gates == play.level.gates)
        #expect(snapshot.target == play.level.target)
        #expect(snapshot.summary == play.summary)
        #expect(snapshot.crossings == WaveKnotKeeperCrossingMark.marks(play.points))
        #expect(snapshot.stage == play.stage)
        #expect(snapshot.selected == core.selected)
        #expect(snapshot.matchesTarget == verdict)
        #expect(snapshot.time.isFinite)
    }

    @Test func testWaveKnotKeeperRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "point.select", values: [2], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: Bool = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: WaveKnotKeeperSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core, verdict: expected)
            #expect(snapshot.pulse >= 0 && snapshot.pulse <= 1)
            #expect(try Self.digest(core) == before)
        }
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy && core.selected == 2)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Four certified levels (the tutorial and later bands), generated once.
        let numbers: [Int] = [1, 13, 42, 64]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_323)
        var accepted: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // A few seeded moves so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...4) {
                let values: [Double] = [Double(random.int(0...(core.play.points.count - 1))), Double(random.int(0...5))]
                if core.apply(ExperienceAction(control: "point.move", values: values, step: 0)).isAccepted {
                    accepted += 1
                }
            }
            if random.int(0...1) == 1 {
                let point: Double = Double(random.int(0...(core.play.points.count - 1)))
                #expect(core.apply(ExperienceAction(control: "point.select", values: [point], step: 0)) == .accepted)
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: Bool = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: WaveKnotKeeperSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core, verdict: expected)
                core.update(step: 1)
            }
            core.setQualityTier(random.int(0...2))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.selected == copy.selected)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 100)
    }
}
