// ChronoConstellatorRendererPurityTests — feature 353 (R02-G06-03) T-R02G0603-005 (FR-R02G0603-003, 005;
// SC-R02G0603-002; clarification Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots
// at any presentation time (non-finite ones included), change the quality tier, step the host — leaves the adapter's
// digest, its state, the kernel's verdict (stage and failure) and the timeline unchanged, over 200 seeded snapshots
// (seed 2_353: random phase changes, holds, releases, time steps, rewinds, undo and redo on certified levels of bands 1
// and 2); every snapshot copies the kernel's fields exactly; two snapshots of equal states at different times differ
// only in `time`. Four certified levels are generated once and reused, so the run stays short.
@testable import ChronoConstellatorCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ChronoConstellatorRendererPurityTests {
    typealias Core = ChronoConstellatorExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage and, when it failed, why.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + (core.play.failure?.code ?? "-")
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly.
    static func expectMirrors(_ snapshot: ChronoConstellatorSceneSnapshot, _ core: Core) {
        let play: ChronoConstellatorPlay = core.play
        let level: ChronoConstellatorLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.columns == level.columns && snapshot.rows == level.rows)
        #expect(snapshot.stars.map(\.loop) == level.stars.map(\.loop))
        #expect(snapshot.stars.map(\.target) == level.stars.map(\.target))
        #expect(snapshot.stars.map(\.cell) == play.positions)
        for star in snapshot.stars.indices {
            let history: [Int] = snapshot.stars[star].history
            let first: Int = max(0, play.tick - ChronoConstellatorTier.historyTicks)
            #expect(history.count == play.tick - first + 1)
            #expect(history.last == play.positions[star])
            #expect(history.first == play.timeline.position(star: star, at: first, level: level))
        }
        #expect(snapshot.phases == play.timeline.phases && snapshot.holds == play.timeline.holds)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.tick == play.tick && snapshot.tickLimit == level.tickLimit)
        #expect(snapshot.remaining == play.remaining)
        #expect(snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: ChronoConstellatorSceneSnapshot, _ b: ChronoConstellatorSceneSnapshot) {
        #expect(a.columns == b.columns && a.rows == b.rows && a.stars == b.stars && a.phases == b.phases)
        #expect(a.holds == b.holds && a.stage == b.stage && a.failure == b.failure && a.tick == b.tick)
        #expect(a.tickLimit == b.tickLimit && a.remaining == b.remaining && a.levelNumber == b.levelNumber)
    }

    @Test func testChronoConstellatorRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "time.step", values: [6], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let timeline: ChronoConstellatorTimeline = core.play.timeline
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? time : 0))
            #expect(try Self.digest(core) == before && core.play.timeline == timeline)
        }
        // Non-finite times read as time 0.
        #expect(core.snapshot(time: .nan) == core.snapshot(time: 0))
        #expect(core.snapshot(time: .infinity) == core.snapshot(time: 0))
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy && core.play.timeline == timeline)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Four certified levels of bands 1 and 2, generated once.
        let numbers: [Int] = [1, 9, 23, 37]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_353)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // A few seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...6) {
                let level: ChronoConstellatorLevel = core.play.level
                let star: Int = random.int(0...(level.stars.count - 1))
                let kind: Int = random.int(0...11)
                let action: ExperienceAction
                switch kind {
                case 0...2:
                    let phase: Double = Double(random.int(0...(level.stars[star].length - 1)))
                    action = ExperienceAction(control: "star.phase", values: [Double(star), phase], step: 0)
                case 3...4:
                    let start: Double = Double(random.int(1...40))
                    let length: Double = Double(random.int(1...8))
                    action = ExperienceAction(control: "star.hold", values: [Double(star), start, length], step: 0)
                case 5:
                    let start: Double = Double(random.int(1...40))
                    action = ExperienceAction(control: "star.release", values: [Double(star), start], step: 0)
                case 6...8:
                    action = ExperienceAction(control: "time.step", values: [Double(random.int(1...400))], step: 0)
                case 9:
                    action = ExperienceAction(control: "time.rewind", step: 0)
                case 10:
                    action = ExperienceAction(control: "play.undo", step: 0)
                default:
                    action = ExperienceAction(control: "play.redo", step: 0)
                }
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let timeline: ChronoConstellatorTimeline = core.play.timeline
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: ChronoConstellatorSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: time + Double(tier))
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
            #expect(core == copy && core.play.timeline == timeline)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && ended > 5, "accepted \(accepted) playing \(playing) ended \(ended)")
    }
}
