// StarlitCartoucheRendererPurityTests — feature 453 (R02-G16-03) T-R02G1603-005 (FR-R02G1603-003, 005; clarifications
// Q1, Q4, Q5, renderer purity). Everything the renderer and the panel may do with the adapter — read snapshots at any
// presentation time (negative and non-finite ones included), read them repeatedly, change the quality tier, choose any
// destination and wait, step the host — leaves the adapter's digest, its play and the kernel's verdict (stage, failure
// and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_453: random legs, odd stars and waits, undo,
// redo and choices on certified levels 1, 21, 41, 61, 81 and 91, each from its opening or with all but the last leg of
// its certified plan flown). Every snapshot's star positions are the kernel's positions at the play's beat, recomputed
// independently from the orbits (`orbit[beat mod length]`), its legs, their departure and arrival positions, strokes
// and report are the kernel's, so the drawn stars (any tier, any time, any choice) are never a drawn value. Two
// snapshots of equal states at different times differ only in `time`. The six levels are certified once and reused, so
// the run stays short. Explicit types, plain loops, single-literal comments.
@testable import StarlitCartoucheCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct StarlitCartoucheRendererPurityTests {
    typealias Core = StarlitCartoucheExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + StarlitCartouchePlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// The lattice position of `star` at `beat`, computed here from its orbit (independent of the kernel's).
    static func orbitPosition(_ star: StarlitCartoucheStar, _ beat: Int) -> StarlitCartoucheVector {
        star.orbit[beat % star.orbit.count]
    }

    /// Checks that `snapshot` copies the play of `core` and that its positions, legs and report are the kernel's,
    /// recomputed independently from the orbits.
    static func expectMirrors(_ snapshot: StarlitCartoucheSceneSnapshot, _ core: Core) {
        let play: StarlitCartouchePlay = core.play
        let level: StarlitCartoucheLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.chosenStar == core.chosenStar && snapshot.chosenWait == core.chosenWait)
        #expect(snapshot.stars == level.stars && snapshot.beat == play.beat && snapshot.star == play.star)
        #expect(snapshot.positions.count == level.stars.count)
        for index in level.stars.indices {
            let star: StarlitCartoucheStar = level.stars[index]
            #expect(snapshot.positions[index] == orbitPosition(star, play.beat), "the drawn star is the kernel's")
            #expect(snapshot.positions[index] == star.position(at: play.beat))
        }
        #expect(snapshot.legs == play.legs && snapshot.drawn == play.drawn.sorted())
        for index in play.legs.indices {
            let leg: StarlitCartoucheLeg = play.legs[index]
            #expect(snapshot.departures[index] == orbitPosition(level.stars[leg.from], leg.depart))
            #expect(snapshot.arrivals[index] == orbitPosition(level.stars[leg.to], leg.arrive))
        }
        for index in level.hazards.indices {
            let hazard: StarlitCartoucheHazard = level.hazards[index]
            #expect(snapshot.active[index] == (hazard.from <= play.beat && play.beat <= hazard.to))
        }
        #expect(snapshot.report == play.report && snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: StarlitCartoucheSceneSnapshot, _ b: StarlitCartoucheSceneSnapshot) {
        #expect(a.stars == b.stars && a.positions == b.positions && a.corridors == b.corridors)
        #expect(a.hazards == b.hazards && a.active == b.active && a.legs == b.legs)
        #expect(a.departures == b.departures && a.arrivals == b.arrivals && a.drawn == b.drawn)
        #expect(a.symbol == b.symbol && a.star == b.star && a.beat == b.beat && a.beacon == b.beacon)
        #expect(a.deadline == b.deadline && a.chosenStar == b.chosenStar && a.chosenWait == b.chosenWait)
        #expect(a.report == b.report && a.stage == b.stage && a.failure == b.failure && a.failedLeg == b.failedLeg)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly legs to the level's stars, sometimes odd stars and waits, undo, redo and
    /// choices.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.level.stars.count
        switch random.int(0...13) {
        case 0...6:
            let star: Double = Double(random.int(0...(count - 1)))
            let wait: Double = Double(random.int(0...3))
            return ExperienceAction(control: "route.fly", values: [star, wait], step: 0)
        case 7:
            let star: Double = Double(random.int(0...11))
            let wait: Double = Double(random.int(0...8))
            return ExperienceAction(control: "route.fly", values: [star, wait], step: 0)
        case 8, 9:
            return ExperienceAction(control: "play.undo", step: 0)
        case 10:
            return ExperienceAction(control: "play.redo", step: 0)
        default:
            let star: Double = Double(random.int(0...11))
            let wait: Double = Double(random.int(0...8))
            return ExperienceAction(control: "route.choose", values: [star, wait], step: 0)
        }
    }

    @Test func testStarlitCartoucheRendererpurityBoundary() async throws {
        // Direct example: level 1 after its first certified leg, read at the boundary times, every tier and choice.
        var core: Core = try await Core.prepare(seed: 0)
        let leg = ExperienceAction(control: "route.fly", values: [4, 1], step: 0)
        #expect(core.apply(leg) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: StarlitCartoucheSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for star in 0..<core.play.level.stars.count where star != core.play.star {
            for wait in Core.waitRange {
                let choose = ExperienceAction(control: "route.choose", values: [Double(star), Double(wait)], step: 0)
                #expect(core.apply(choose) == .accepted)
                Self.expectMirrors(core.snapshot(time: 1), core)
                #expect(try Self.digest(core) == before && core == copy)
            }
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last leg of its certified plan flown, so
        // that many samples are one leg from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let legs: [StarlitCartoucheAction] = try Core.generated(number: number).plan.legs
            for action in legs.dropLast() {
                guard case let .leg(star, wait) = action else { continue }
                let adapter = ExperienceAction(control: "route.fly", values: [Double(star), Double(wait)], step: 0)
                #expect(prepared.apply(adapter) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_453)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var chosenOthers: Int = 0
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
            let records: [StarlitCartoucheRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two choices (the current one at every tier, then a random other star of the level with a random wait at a
            // random tier): the digest, the play and the verdict hold.
            let count: Int = core.play.level.stars.count
            var other: Int = random.int(0...(count - 2))
            if other >= core.play.star { other += 1 }
            let choices: [(star: Int, wait: Int)] = [(core.chosenStar, core.chosenWait), (other, random.int(0...8))]
            for (position, choice) in choices.enumerated() {
                let values: [Double] = [Double(choice.star), Double(choice.wait)]
                let choose = ExperienceAction(control: "route.choose", values: values, step: 0)
                #expect(core.apply(choose) == .accepted)
                if choice.star != copy.chosenStar || choice.wait != copy.chosenWait { chosenOthers += 1 }
                var first: StarlitCartoucheSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.chosenStar == choice.star && snapshot.chosenWait == choice.wait)
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
            // The ship's own star and a star the level lacks are refused and change nothing.
            let chosenBefore: (star: Int, wait: Int) = (core.chosenStar, core.chosenWait)
            let refusal: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.choice))
            let own = ExperienceAction(control: "route.choose", values: [Double(core.play.star), 0], step: 0)
            #expect(core.apply(own) == refusal)
            if count < 12 {
                let missing = ExperienceAction(control: "route.choose", values: [Double(count), 0], step: 0)
                #expect(core.apply(missing) == refusal)
            }
            #expect(core.chosenStar == chosenBefore.star && core.chosenWait == chosenBefore.wait)
            // Read again at the same time: the same snapshot.
            let again: StarlitCartoucheSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == records)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && chosenOthers > 100, "the samples spread over plays and choices")
        #expect(won + failed > 0, "the samples include decided plays")
    }
}
