// CelestialEclipseLabRendererPurityTests — feature 463 (R02-G17-03) T-R02G1703-005 (FR-R02G1703-003, 005;
// SC-R02G1703-002; clarifications Q1, Q4, Q5, renderer purity). Everything the renderer and the panel may do with the
// adapter — read snapshots at any presentation time (negative and non-finite ones included), read them repeatedly,
// change the quality tier, choose any body, show any tick, step the host — leaves the adapter's digest, its play and
// the kernel's verdict (stage, failure and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_463:
// random phase changes, odd bodies and offsets, runs, undo, redo, choices and shown ticks on certified levels 1, 21,
// 41, 61, 81 and 91, each from its opening or with all but the last change of its certified plan made). Every
// snapshot's body positions are the kernel's positions at the shown tick for the current phases, recomputed
// independently from the orbits (`orbit[(tick + phase) mod period]`); its eclipses are the kernel's computation
// (`CelestialEclipseLabSceneSnapshot.eclipses`, the strict overlap and depth order of `CelestialEclipseLabSky`), their
// pairs exactly the predicted intervals under way at the shown tick and their classes the kernel's class of that tick;
// its intervals, matched count and failure are the kernel's timeline, so the drawn bodies and crescents (any tier, any
// time, any choice, any shown tick) are never a drawn value. Two snapshots of equal states at different times differ
// only in `time`. The six levels are certified once and reused, so the run stays short. Explicit types, plain loops,
// single-literal comments.
@testable import CelestialEclipseLabCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct CelestialEclipseLabRendererPurityTests {
    typealias Core = CelestialEclipseLabExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + CelestialEclipseLabPlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// The lattice position of `body` at `tick` with `phase`, computed here from its orbit (independent of the
    /// kernel's).
    static func orbitPosition(_ body: CelestialEclipseLabBody, _ tick: Int,
                              _ phase: Int) -> CelestialEclipseLabVector {
        body.orbit[(tick + phase) % body.period]
    }

    /// The (front, back) pairs of the predicted intervals under way at `tick`, ordered by front, then back.
    static func pairsUnderWay(_ intervals: [CelestialEclipseLabInterval], _ tick: Int) -> [[Int]] {
        var pairs: [[Int]] = []
        for interval in intervals where interval.first <= tick && tick <= interval.last {
            pairs.append([interval.front, interval.back])
        }
        pairs.sort { ($0[0], $0[1]) < ($1[0], $1[1]) }
        return pairs
    }

    /// Checks that `snapshot` copies the play of `core` and that its positions, eclipses and timeline are the
    /// kernel's, the positions and eclipse pairs recomputed independently.
    static func expectMirrors(_ snapshot: CelestialEclipseLabSceneSnapshot, _ core: Core) {
        let play: CelestialEclipseLabPlay = core.play
        let level: CelestialEclipseLabLevel = play.level
        let tick: Int = core.shownTick
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownTick == tick)
        #expect(snapshot.chosenBody == core.chosenBody && snapshot.horizon == level.horizon)
        #expect(snapshot.bodies == level.bodies && snapshot.phases == play.phases)
        #expect(snapshot.positions.count == level.bodies.count)
        for index in level.bodies.indices {
            let body: CelestialEclipseLabBody = level.bodies[index]
            let phase: Int = play.phases[index]
            #expect(snapshot.positions[index] == orbitPosition(body, tick, phase), "the drawn body is the kernel's")
            #expect(snapshot.positions[index] == body.position(at: tick, phase: phase))
        }
        let eclipses: [CelestialEclipseLabEclipse] = CelestialEclipseLabSceneSnapshot.eclipses(
            level, phases: play.phases, tick: tick)
        #expect(snapshot.eclipses == eclipses)
        var drawnPairs: [[Int]] = []
        for eclipse in snapshot.eclipses {
            drawnPairs.append([eclipse.front, eclipse.back])
            let front: CelestialEclipseLabBody = level.bodies[eclipse.front]
            let back: CelestialEclipseLabBody = level.bodies[eclipse.back]
            let d2: Int = snapshot.positions[eclipse.front]
                .projectedSquaredDistance(to: snapshot.positions[eclipse.back])
            let reach: Int = front.radius + back.radius
            #expect(d2 < reach * reach, "an eclipse is a strict overlap")
            let visibility: CelestialEclipseLabVisibility = CelestialEclipseLabSky.visibility(
                front: front, back: back, squaredDistance: d2)
            #expect(eclipse.visibility == visibility, "the drawn class is the kernel's class of the tick")
        }
        #expect(drawnPairs == pairsUnderWay(play.timeline.intervals, tick), "the drawn eclipses are the kernel's")
        #expect(snapshot.target == level.target && snapshot.intervals == play.timeline.intervals)
        #expect(snapshot.matched == play.timeline.matched)
        #expect(snapshot.failure == (play.failure ?? play.timeline.failure) && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: CelestialEclipseLabSceneSnapshot, _ b: CelestialEclipseLabSceneSnapshot) {
        #expect(a.bodies == b.bodies && a.phases == b.phases && a.positions == b.positions)
        #expect(a.eclipses == b.eclipses && a.target == b.target && a.intervals == b.intervals)
        #expect(a.matched == b.matched && a.failure == b.failure && a.shownTick == b.shownTick)
        #expect(a.horizon == b.horizon && a.chosenBody == b.chosenBody && a.stage == b.stage)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly phase changes of the level's bodies, sometimes odd bodies and offsets, runs,
    /// undo, redo, choices and shown ticks.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let level: CelestialEclipseLabLevel = core.play.level
        switch random.int(0...13) {
        case 0...5:
            let body: Int = random.int(0...(level.bodies.count - 1))
            let offset: Int = random.int(0...(level.bodies[body].period - 1))
            return ExperienceAction(control: "orbit.phase", values: [Double(body), Double(offset)], step: 0)
        case 6:
            let body: Double = Double(random.int(0...5))
            let offset: Double = Double(random.int(0...23))
            return ExperienceAction(control: "orbit.phase", values: [body, offset], step: 0)
        case 7, 8:
            return ExperienceAction(control: "play.undo", step: 0)
        case 9:
            return ExperienceAction(control: "play.redo", step: 0)
        case 10:
            return ExperienceAction(control: "clock.run", step: 0)
        case 11:
            return ExperienceAction(control: "orbit.choose", values: [Double(random.int(0...5))], step: 0)
        default:
            return ExperienceAction(control: "clock.show", values: [Double(random.int(0...47))], step: 0)
        }
    }

    @Test func testCelestialEclipseLabRendererpurityBoundary() async throws {
        // Direct example: level 1 after its first certified change, read at the boundary times, every tier, every
        // body and every tick.
        var core: Core = try await Core.prepare(seed: 0)
        let change = ExperienceAction(control: "orbit.phase", values: [1, 2], step: 0)
        #expect(core.apply(change) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for body in 0..<core.play.level.bodies.count {
            let choose = ExperienceAction(control: "orbit.choose", values: [Double(body)], step: 0)
            #expect(core.apply(choose) == .accepted)
            Self.expectMirrors(core.snapshot(time: 1), core)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for tick in 0..<core.play.level.horizon {
            let show = ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
            #expect(core.apply(show) == .accepted)
            let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 1)
            Self.expectMirrors(snapshot, core)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last change of its certified plan made, so
        // that many samples are one change from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let changes: [CelestialEclipseLabAction] = try Core.generated(number: number).plan.actions
            for action in changes.dropLast() {
                guard case let .phase(body, offset) = action else { continue }
                let adapter = ExperienceAction(control: "orbit.phase", values: [Double(body), Double(offset)], step: 0)
                #expect(prepared.apply(adapter) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_463)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var chosenOthers: Int = 0
        var withEclipses: Int = 0
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
            let records: [CelestialEclipseLabRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two presentations (the current one at every tier, then a random body of the level with a random tick of
            // the horizon at a random tier): the digest, the play and the verdict hold.
            let count: Int = core.play.level.bodies.count
            let horizon: Int = core.play.level.horizon
            let current: (body: Int, tick: Int) = (core.chosenBody, core.shownTick)
            let other: (body: Int, tick: Int) = (random.int(0...(count - 1)), random.int(0...(horizon - 1)))
            let presentations: [(body: Int, tick: Int)] = [current, other]
            for (position, presentation) in presentations.enumerated() {
                let choose = ExperienceAction(control: "orbit.choose", values: [Double(presentation.body)], step: 0)
                let show = ExperienceAction(control: "clock.show", values: [Double(presentation.tick)], step: 0)
                #expect(core.apply(choose) == .accepted)
                #expect(core.apply(show) == .accepted)
                if presentation.body != current.body || presentation.tick != current.tick { chosenOthers += 1 }
                var first: CelestialEclipseLabSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.chosenBody == presentation.body && snapshot.shownTick == presentation.tick)
                    #expect(snapshot.time == time + Double(tier))
                    if let first {
                        // Equal states at different times and tiers: only `time` differs.
                        Self.expectSameButTime(first, snapshot)
                        #expect(first != snapshot)
                    } else {
                        // The first tier's snapshot is checked against the kernel; the others equal it but in time.
                        Self.expectMirrors(snapshot, core)
                        if !snapshot.eclipses.isEmpty { withEclipses += 1 }
                        first = snapshot
                    }
                    core.update(step: 1)
                }
                #expect(try Self.digest(core) == before && core == copy)
            }
            // A body the level lacks and a tick past the horizon are refused and change nothing.
            let presented: (body: Int, tick: Int) = (core.chosenBody, core.shownTick)
            if count < 6 {
                let missing = ExperienceAction(control: "orbit.choose", values: [Double(count)], step: 0)
                #expect(core.apply(missing) == .rejected(.rule(code: CelestialEclipseLabExperienceRule.choice)))
            }
            let late = ExperienceAction(control: "clock.show", values: [Double(horizon)], step: 0)
            #expect(core.apply(late) == .rejected(.rule(code: CelestialEclipseLabExperienceRule.tick)))
            #expect(core.chosenBody == presented.body && core.shownTick == presented.tick)
            // Read again at the same time: the same snapshot.
            let again: CelestialEclipseLabSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == records)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 150 && playing > 30 && chosenOthers > 100, "the samples spread over plays and choices")
        #expect(won + failed > 0, "the samples include decided plays")
        #expect(withEclipses > 0, "the samples include eclipses under way")
    }
}
