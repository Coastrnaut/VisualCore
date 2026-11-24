// VoxelOrigamiRendererPurityTests — feature 443 (R02-G15-03) T-R02G1503-005 (FR-R02G1503-003, 005; clarifications
// Q4, Q5, renderer purity). Everything the renderer and the panel may do with the adapter — read snapshots at any
// presentation time (negative and non-finite ones included), read them repeatedly, change the quality tier, choose any
// hinge, step the host — leaves the adapter's digest, its play and the kernel's verdict (stage, failure and actions
// left) unchanged, over 200 seeded snapshots (fixture seed 2_443: random turns, odd hinges and steps, undo, redo and
// hinge choices on certified levels 1, 21, 41, 61, 81 and 91, each from its opening or with all but the last turn of
// its certified plan made). Every snapshot's cells are the kernel's pose cells, recomputed independently from the turns
// (`VoxelOrigamiLattice.pose`), its report is the kernel's exact shape report of those turns and its turnable hinges
// are the kernel's, so the drawn cubes (any tier, any time, any chosen hinge) are never a drawn value. Two snapshots of
// equal states at different times differ only in `time`. The six levels are certified once and reused, so the run
// stays short. Explicit types, plain loops, single-literal comments.
@testable import VoxelOrigamiCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct VoxelOrigamiRendererPurityTests {
    typealias Core = VoxelOrigamiExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure when it failed, and the actions left.
    static func verdict(_ core: Core) -> String {
        var text: String = core.play.stage.rawValue + "/"
        switch core.play.failure {
        case let .collision(hinge, moving, still, cell)?: text += "collision " + VoxelOrigamiPlay.text(hinge, moving,
                                                                                                         still, cell)
        case let .sweep(hinge, moving, still, cell)?: text += "sweep " + VoxelOrigamiPlay.text(hinge, moving, still,
                                                                                                 cell)
        case let .budget(index)?: text += "budget " + String(index)
        case nil: text += "-"
        }
        text += "/" + String(core.play.actionsLeft)
        return text
    }

    /// Checks that `snapshot` copies the play of `core` and that its cells, report and turnable hinges are the
    /// kernel's, recomputed independently from the turns.
    static func expectMirrors(_ snapshot: VoxelOrigamiSceneSnapshot, _ core: Core) {
        let play: VoxelOrigamiPlay = core.play
        let level: VoxelOrigamiLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.chosenHinge == core.chosenHinge)
        #expect(snapshot.cubes == level.cubes && snapshot.turns == play.turns)
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(level.cubes, turns: play.turns)
        #expect(snapshot.cells == pose.cells && snapshot.cells == play.pose.cells, "the drawn cubes are the cells")
        #expect(snapshot.orientations == pose.orientations)
        #expect(snapshot.report == play.report && snapshot.report == level.report(turns: play.turns))
        var turnable: [Int] = []
        for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: play.turns) { turnable.append(hinge) }
        #expect(snapshot.turnable == turnable)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: VoxelOrigamiSceneSnapshot, _ b: VoxelOrigamiSceneSnapshot) {
        #expect(a.cubes == b.cubes && a.cells == b.cells && a.orientations == b.orientations && a.turns == b.turns)
        #expect(a.turnable == b.turnable && a.chosenHinge == b.chosenHinge && a.target == b.target)
        #expect(a.report == b.report && a.stage == b.stage && a.failure == b.failure)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly turns of the level's hinges, sometimes odd hinges and steps, undo, redo and
    /// hinge choices.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.level.cubes.count
        switch random.int(0...13) {
        case 0...6:
            let hinge: Double = Double(random.int(1...(count - 1)))
            let step: Double = random.int(0...1) == 0 ? -1 : 1
            return ExperienceAction(control: "hinge.turn", values: [hinge, step], step: 0)
        case 7:
            let hinge: Double = Double(random.int(0...11))
            let step: Double = Double(random.int(-1...1))
            return ExperienceAction(control: "hinge.turn", values: [hinge, step], step: 0)
        case 8, 9:
            return ExperienceAction(control: "play.undo", step: 0)
        case 10:
            return ExperienceAction(control: "play.redo", step: 0)
        default:
            let hinge: Double = Double(random.int(0...11))
            return ExperienceAction(control: "hinge.choose", values: [hinge], step: 0)
        }
    }

    @Test func testVoxelOrigamiRendererpurityBoundary() async throws {
        // Direct example: level 1 after its first certified turn, read at the boundary times, every tier and hinge.
        var core: Core = try await Core.prepare(seed: 0)
        let turn = ExperienceAction(control: "hinge.turn", values: [4, -1], step: 0)
        #expect(core.apply(turn) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: VoxelOrigamiSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for hinge in 1..<core.play.level.cubes.count {
            let choose = ExperienceAction(control: "hinge.choose", values: [Double(hinge)], step: 0)
            #expect(core.apply(choose) == .accepted)
            Self.expectMirrors(core.snapshot(time: 1), core)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last turn of its certified plan made, so
        // that many samples are one turn from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let turns: [VoxelOrigamiAction] = try Core.generated(number: number).plan.turns
            for action in turns.dropLast() {
                guard case let .turn(hinge, step) = action else { continue }
                let adapter = ExperienceAction(control: "hinge.turn", values: [Double(hinge), Double(step)], step: 0)
                #expect(prepared.apply(adapter) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_443)
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
            let payload: [VoxelOrigamiRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two hinge choices (the current one at every tier, then a random one of the level at a random tier): the
            // digest, the play and the verdict hold.
            let count: Int = core.play.level.cubes.count
            let hinges: [Int] = [core.chosenHinge, random.int(1...(count - 1))]
            for (position, hinge) in hinges.enumerated() {
                let choose = ExperienceAction(control: "hinge.choose", values: [Double(hinge)], step: 0)
                #expect(core.apply(choose) == .accepted)
                if hinge != copy.chosenHinge { chosenOthers += 1 }
                var first: VoxelOrigamiSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    let snapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.chosenHinge == hinge && snapshot.time == time + Double(tier))
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
            // A hinge the level lacks is refused and changes nothing.
            let chosenBefore: Int = core.chosenHinge
            let missing = ExperienceAction(control: "hinge.choose", values: [Double(count)], step: 0)
            #expect(core.apply(missing) == .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge)))
            #expect(core.chosenHinge == chosenBefore)
            // Read again at the same time: the same snapshot.
            let again: VoxelOrigamiSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == payload)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && chosenOthers > 100, "the samples spread over plays and hinges")
        #expect(won + failed > 0, "the samples include decided plays")
    }
}
