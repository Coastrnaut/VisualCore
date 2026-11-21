// ColorfallCanyonsRendererPurityTests — feature 343 (R02-G05-03) T-R02G0503-005 (FR-R02G0503-003, 005; SC-R02G0503-002;
// clarification Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any
// presentation time (non-finite ones included), change the quality tier, step the host — leaves the adapter's digest,
// its state, the kernel's verdict (stage and failure) and the fluid unchanged, over 200 seeded snapshots (seed 2_343:
// random carves, valve toggles, time steps, undo and redo on certified levels of bands 1 and 2); every snapshot copies
// the kernel's fields exactly; two snapshots of equal states at different times differ only in `time`. Four certified
// levels are generated once and reused, so the run stays short.
@testable import ColorfallCanyonsCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ColorfallCanyonsRendererPurityTests {
    typealias Core = ColorfallCanyonsExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage and, when it failed, why.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + (core.play.failure?.rawValue ?? "-")
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly.
    static func expectMirrors(_ snapshot: ColorfallCanyonsSceneSnapshot, _ core: Core) {
        let play: ColorfallCanyonsPlay = core.play
        let level: ColorfallCanyonsLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.columns == level.columns && snapshot.rows == level.rows)
        #expect(snapshot.heights == play.fluid.heights && snapshot.grounds == level.grounds)
        #expect(snapshot.masses == play.fluid.masses && snapshot.basins == level.basins)
        #expect(snapshot.springs.map(\.cell) == level.springs.map(\.cell))
        #expect(snapshot.springs.map(\.color) == level.springs.map(\.color))
        #expect(snapshot.springs.map(\.open) == play.fluid.valves)
        #expect(snapshot.springs.map(\.supplyLeft) == play.fluid.supplies)
        var downhill: [Int?] = []
        for cell in 0..<level.cellCount { downhill.append(play.fluid.downhill(of: cell, level: level)) }
        #expect(snapshot.downhill == downhill)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.tick == play.fluid.tick && snapshot.tickLimit == level.tickLimit)
        #expect(snapshot.remaining == play.remaining)
        #expect(snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: ColorfallCanyonsSceneSnapshot, _ b: ColorfallCanyonsSceneSnapshot) {
        #expect(a.columns == b.columns && a.rows == b.rows && a.heights == b.heights && a.grounds == b.grounds)
        #expect(a.springs == b.springs && a.basins == b.basins && a.masses == b.masses && a.downhill == b.downhill)
        #expect(a.stage == b.stage && a.failure == b.failure && a.tick == b.tick && a.tickLimit == b.tickLimit)
        #expect(a.remaining == b.remaining && a.levelNumber == b.levelNumber)
    }

    @Test func testColorfallCanyonsRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "time.step", values: [6], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let fluid: ColorfallCanyonsFluid = core.play.fluid
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? time : 0))
            #expect(try Self.digest(core) == before && core.play.fluid == fluid)
        }
        // Non-finite times read as time 0.
        #expect(core.snapshot(time: .nan) == core.snapshot(time: 0))
        #expect(core.snapshot(time: .infinity) == core.snapshot(time: 0))
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy && core.play.fluid == fluid)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Four certified levels of bands 1 and 2, generated once.
        let numbers: [Int] = [1, 9, 23, 37]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_343)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // A few seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...6) {
                let kind: Int = random.int(0...9)
                let action: ExperienceAction
                switch kind {
                case 0...2:
                    let cell: Double = Double(random.int(0...(core.play.level.cellCount - 1)))
                    action = ExperienceAction(control: "canyon.carve", values: [cell], step: 0)
                case 3:
                    action = ExperienceAction(control: "canyon.valve", values: [Double(random.int(0...2))], step: 0)
                case 4...6:
                    action = ExperienceAction(control: "time.step", values: [Double(random.int(1...600))], step: 0)
                case 7:
                    action = ExperienceAction(control: "play.undo", step: 0)
                default:
                    action = ExperienceAction(control: "play.redo", step: 0)
                }
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let fluid: ColorfallCanyonsFluid = core.play.fluid
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: ColorfallCanyonsSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core)
                #expect(snapshot.time == time + Double(tier))
                if let first {
                    // Equal states at different times: only `time` differs.
                    Self.expectSameButTime(first, snapshot)
                    #expect(first != snapshot)
                } else {
                    first = snapshot
                }
                core.update(step: 1)
            }
            let odd: [Double] = [.nan, .infinity, -.infinity]
            _ = core.snapshot(time: odd[random.int(0...2)])
            core.setQualityTier(random.int(0...2))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.fluid == fluid)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && ended > 5, "accepted \(accepted) playing \(playing) ended \(ended)")
    }
}
