// ApsidesWorkshopRendererPurityTests — feature 473 (R02-G18-03) T-R02G1803-005 (FR-R02G1803-003, 005;
// SC-R02G1803-002; clarifications Q4, Q5, renderer purity). Everything the renderer and the panel may do with the
// adapter — read snapshots at any presentation time (negative and non-finite ones included), read them repeatedly,
// change the quality tier, show any tick, step the host — leaves the adapter's digest, its play and the kernel's
// verdict (stage, failure and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_473: random tunings
// of the knob and the size, odd steps, plays, undo, redo and shown ticks on certified levels 1, 21, 41, 61, 81 and 91,
// each from its opening or with all but the last tuning of its certified plan made). Every snapshot's positions are
// the kernel's report positions of the current orbit, recomputed independently from the orbit's steps
// (`ApsidesWorkshopSky.positions`); its orbiter is the position at the shown tick, its ghost loop the starting orbit's
// positions, its shares, apsis readings, deviations, met flags and failure the kernel's report, so the drawn orbit,
// wedges and gauges (any tier, any time, any shown tick) are never a drawn value. Two snapshots of equal states at
// different times differ only in `time`. The six levels are certified once and reused, so the run stays short.
// Explicit types, plain loops, single-literal comments. Modelled on CelestialEclipseLabRendererPurityTests
// (feature 463).
@testable import ApsidesWorkshopCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ApsidesWorkshopRendererPurityTests {
    typealias Core = ApsidesWorkshopExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + ApsidesWorkshopPlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// The adapter action of a kernel tuning.
    static func act(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        switch action {
        case let .periapsis(eccentricity, direction):
            ExperienceAction(control: "orbit.periapsis", values: [Double(eccentricity), Double(direction)], step: 0)
        case let .size(size):
            ExperienceAction(control: "orbit.size", values: [Double(size)], step: 0)
        case .play:
            ExperienceAction(control: "orbit.play", step: 0)
        }
    }

    /// Checks that `snapshot` copies the play of `core` and that its positions, readings and gauges are the kernel's,
    /// the positions recomputed independently from the orbit's steps.
    static func expectMirrors(_ snapshot: ApsidesWorkshopSceneSnapshot, _ core: Core) {
        let play: ApsidesWorkshopPlay = core.play
        let level: ApsidesWorkshopLevel = play.level
        let report: ApsidesWorkshopReport = play.report
        let tick: Int = core.shownTick
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownTick == tick)
        #expect(snapshot.period == level.period && snapshot.orbit == play.orbit)
        let recomputed: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(play.orbit, period: level.period).points
        #expect(snapshot.positions.count == level.period)
        #expect(snapshot.positions == report.positions, "the drawn orbit is the kernel's positions")
        #expect(snapshot.positions == recomputed, "the drawn orbit is the orbit's own positions")
        #expect(snapshot.orbiter == report.positions[tick], "the drawn orbiter is the kernel's position at the tick")
        let ghost: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(level.orbit, period: level.period).points
        #expect(snapshot.ghost == ghost)
        #expect(snapshot.shares == report.shares && snapshot.shares == ApsidesWorkshopSky.shares(recomputed))
        #expect(snapshot.periapsisSector == play.orbit.periapsisSector)
        #expect(snapshot.periapsisDistance == play.orbit.periapsisDistance)
        #expect(snapshot.apoapsisSector == play.orbit.apoapsisSector)
        #expect(snapshot.apoapsisDistance == play.orbit.apoapsisDistance)
        #expect(snapshot.planets == level.planets && snapshot.gauges.count == level.targets.count)
        for index in level.targets.indices {
            let gauge: ApsidesWorkshopGauge = snapshot.gauges[index]
            #expect(gauge.target == level.targets[index] && gauge.deviation == report.deviations[index])
            #expect(gauge.met == (index < report.met))
        }
        #expect(snapshot.failure == (play.failure ?? report.failure) && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: ApsidesWorkshopSceneSnapshot, _ b: ApsidesWorkshopSceneSnapshot) {
        #expect(a.orbit == b.orbit && a.positions == b.positions && a.ghost == b.ghost && a.orbiter == b.orbiter)
        #expect(a.shares == b.shares && a.periapsisSector == b.periapsisSector)
        #expect(a.periapsisDistance == b.periapsisDistance && a.apoapsisSector == b.apoapsisSector)
        #expect(a.apoapsisDistance == b.apoapsisDistance && a.planets == b.planets && a.gauges == b.gauges)
        #expect(a.failure == b.failure && a.shownTick == b.shownTick && a.period == b.period)
        #expect(a.stage == b.stage && a.actionsLeft == b.actionsLeft && a.budget == b.budget)
        #expect(a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly tunings of the knob and the size, sometimes plays, undo, redo and shown
    /// ticks.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        switch random.int(0...12) {
        case 0...3:
            let eccentricity: Double = Double(random.int(ApsidesWorkshopOrbit.eccentricities))
            let direction: Double = Double(random.int(ApsidesWorkshopOrbit.directions))
            return ExperienceAction(control: "orbit.periapsis", values: [eccentricity, direction], step: 0)
        case 4...6:
            let size: Double = Double(random.int(ApsidesWorkshopOrbit.sizes))
            return ExperienceAction(control: "orbit.size", values: [size], step: 0)
        case 7, 8:
            return ExperienceAction(control: "play.undo", step: 0)
        case 9:
            return ExperienceAction(control: "play.redo", step: 0)
        case 10:
            return ExperienceAction(control: "orbit.play", step: 0)
        default:
            return ExperienceAction(control: "clock.show", values: [Double(random.int(0...47))], step: 0)
        }
    }

    @Test func testApsidesWorkshopRendererpurityBoundary() async throws {
        // Direct example: level 1 after its certified tuning, read at the boundary times, every tier and every tick.
        var core: Core = try await Core.prepare(seed: 0)
        let change = ExperienceAction(control: "orbit.periapsis", values: [0, 0], step: 0)
        #expect(core.apply(change) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for tick in 0..<core.play.level.period {
            let show = ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
            #expect(core.apply(show) == .accepted)
            let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 1)
            Self.expectMirrors(snapshot, core)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last tuning of its certified plan made, so
        // that many samples are one tuning from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let changes: [ApsidesWorkshopAction] = try Core.generated(number: number).plan.actions
            for action in changes.dropLast() {
                #expect(prepared.apply(Self.act(action)) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_473)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var shownOthers: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...8) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let records: [ApsidesWorkshopRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two presentations (the current tick at every tier, then a random tick of the period at a random tier):
            // the digest, the play and the verdict hold.
            let period: Int = core.play.level.period
            let current: Int = core.shownTick
            let other: Int = random.int(0...(period - 1))
            let presentations: [Int] = [current, other]
            for (position, presentation) in presentations.enumerated() {
                let show = ExperienceAction(control: "clock.show", values: [Double(presentation)], step: 0)
                #expect(core.apply(show) == .accepted)
                if presentation != current { shownOthers += 1 }
                var first: ApsidesWorkshopSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.shownTick == presentation)
                    #expect(snapshot.time == time + Double(tier))
                    if let first {
                        // Equal states at different times and tiers: only `time` differs.
                        Self.expectSameButTime(first, snapshot)
                        #expect(first != snapshot)
                    } else {
                        // The first tier's snapshot is checked against the kernel; the others equal it but in time.
                        Self.expectMirrors(snapshot, core)
                        first = snapshot
                    }
                    core.update(step: 1)
                }
                #expect(try Self.digest(core) == before && core == copy)
            }
            // A tick past the period is refused and changes nothing.
            let presented: Int = core.shownTick
            let late = ExperienceAction(control: "clock.show", values: [Double(period)], step: 0)
            #expect(core.apply(late) == .rejected(.rule(code: ApsidesWorkshopExperienceRule.tick)))
            #expect(core.shownTick == presented)
            // Read again at the same time: the same snapshot.
            let again: ApsidesWorkshopSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == records)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 150 && playing > 30 && shownOthers > 100, "the samples spread over plays and ticks")
        #expect(won + failed > 0, "the samples include decided plays")
    }
}
