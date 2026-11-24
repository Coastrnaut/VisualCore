// MoonlitMechanismRendererPurityTests — feature 433 (R02-G14-03) T-R02G1403-005 (FR-R02G1403-002, 005;
// clarification Q5, renderer purity). Everything the renderer and the panel may do with the adapter — read snapshots
// at any presentation time (negative and non-finite ones included), read them repeatedly, change the quality tier,
// show any key frame, step the host — leaves the adapter's digest, its play and the kernel's verdict (stage, failure
// and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_433: random turns, re-seats, lamp steps,
// runs, odd gears and steps, undo and redo on certified levels 1, 21, 41, 61, 81 and 100, each from its opening or with
// its witness's set-up made but not run). Every snapshot's cast is the kernel's cast cells of the shown key frame,
// recomputed independently from the gears' phases turned to that key frame (`MoonlitMechanismTrain.turned` and
// `cast`), and its report is the kernel's exact run of the play's set-up, so the drawn shadows (any tier, any time) are
// never a drawn value. Two snapshots of equal states at different times or tiers differ only in `time`. The six levels
// are certified once and reused, so the run stays short. Explicit types, plain loops, single-literal comments.
@testable import MoonlitMechanismCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MoonlitMechanismRendererPurityTests {
    typealias Core = MoonlitMechanismExperienceCore

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
        case let .jammed(child)?: text += "jammed " + String(child)
        case let .forbidden(frame, cell)?: text += "forbidden " + String(frame) + " " + String(cell)
        case let .missing(frame, count)?: text += "missing " + String(frame) + " " + String(count)
        case let .stray(frame, count)?: text += "stray " + String(frame) + " " + String(count)
        case let .budget(index)?: text += "budget " + String(index)
        case nil: text += "-"
        }
        text += "/" + String(core.play.actionsLeft)
        return text
    }

    /// Checks that `snapshot` copies the play of `core` at its shown key frame and that its cast is the kernel's cast
    /// cells of that key frame, recomputed independently from the set-up.
    static func expectMirrors(_ snapshot: MoonlitMechanismSceneSnapshot, _ core: Core) {
        let play: MoonlitMechanismPlay = core.play
        let level: MoonlitMechanismLevel = play.level
        let frame: Int = core.shownFrame
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownFrame == frame)
        #expect(snapshot.gears == level.gears && snapshot.setUpPhases == play.phases)
        #expect(snapshot.height == play.height && snapshot.lampHeights == level.lampHeights)
        #expect(snapshot.width == level.width && snapshot.rows == level.rows)
        #expect(snapshot.keyFrames == level.keyFrames && snapshot.forbidden == level.forbidden)
        let exact: MoonlitMechanismRunReport = level.run(phases: play.phases, height: play.height)
        #expect(snapshot.report == play.report && snapshot.report == exact)
        // The drawn gears and shadows: the set-up turned to the shown key frame, cast by the kernel's rule.
        let turned: [Int] = MoonlitMechanismTrain.turned(level.gears, phases: play.phases,
                                                         by: level.keyFrames[frame].turns)
        let cast: [Int] = MoonlitMechanismTrain.cast(level.gears, phases: turned, height: play.height,
                                                     width: level.width, rows: level.rows)
        #expect(snapshot.phases == turned, "the drawn phases are the kernel's at the shown key frame")
        #expect(snapshot.cast == cast && snapshot.cast == exact.frames[frame].cast, "the drawn shadows are the cast")
        #expect(snapshot.target == level.keyFrames[frame].target)
        let castSet: Set<Int> = Set(cast)
        var missing: [Int] = []
        for cell in level.keyFrames[frame].target where !castSet.contains(cell) { missing.append(cell) }
        #expect(snapshot.missingCells == missing && snapshot.missingCells.count == exact.frames[frame].missing)
        #expect(snapshot.strayCells.count == exact.frames[frame].stray)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: MoonlitMechanismSceneSnapshot, _ b: MoonlitMechanismSceneSnapshot) {
        #expect(a.gears == b.gears && a.phases == b.phases && a.setUpPhases == b.setUpPhases && a.height == b.height)
        #expect(a.shownFrame == b.shownFrame && a.cast == b.cast && a.target == b.target && a.report == b.report)
        #expect(a.stage == b.stage && a.failure == b.failure && a.forbidden == b.forbidden)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly turns, re-seats and lamp steps of the level, sometimes a run, odd gears and
    /// steps, undo and redo.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.level.gears.count
        switch random.int(0...14) {
        case 0...2:
            let step: Double = random.int(0...1) == 0 ? -1 : 1
            return ExperienceAction(control: "handle.turn", values: [step], step: 0)
        case 3...5:
            let gear: Double = Double(random.int(1...(count - 1)))
            let step: Double = random.int(0...1) == 0 ? -1 : 1
            return ExperienceAction(control: "gear.reseat", values: [gear, step], step: 0)
        case 6, 7:
            let step: Double = random.int(0...1) == 0 ? -1 : 1
            return ExperienceAction(control: "lamp.step", values: [step], step: 0)
        case 8:
            return ExperienceAction(control: "machine.run", step: 0)
        case 9:
            let gear: Double = Double(random.int(0...4))
            let step: Double = Double(random.int(-1...1))
            return ExperienceAction(control: "gear.reseat", values: [gear, step], step: 0)
        case 10, 11:
            return ExperienceAction(control: "play.undo", step: 0)
        case 12:
            return ExperienceAction(control: "play.redo", step: 0)
        default:
            let frame: Double = Double(random.int(0...5))
            return ExperienceAction(control: "frame.show", values: [frame], step: 0)
        }
    }

    @Test func testMoonlitMechanismRendererpurityBoundary() async throws {
        // Direct example: level 1 after its witness turn, read at the boundary times, every tier and both key frames.
        var core: Core = try await Core.prepare(seed: 0)
        let turn = ExperienceAction(control: "handle.turn", values: [1], step: 0)
        #expect(core.apply(turn) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: MoonlitMechanismSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        for frame in 0..<core.play.level.keyFrames.count {
            let show = ExperienceAction(control: "frame.show", values: [Double(frame)], step: 0)
            #expect(core.apply(show) == .accepted)
            Self.expectMirrors(core.snapshot(time: 1), core)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with its witness's set-up made (every action but the run),
        // so that many samples are one run from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 100]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            for action in try Core.generated(number: number).actions where action != .run {
                let adapter: ExperienceAction
                switch action {
                case let .turn(step):
                    adapter = ExperienceAction(control: "handle.turn", values: [Double(step)], step: 0)
                case let .reseat(gear, step):
                    adapter = ExperienceAction(control: "gear.reseat", values: [Double(gear), Double(step)], step: 0)
                case let .lamp(step):
                    adapter = ExperienceAction(control: "lamp.step", values: [Double(step)], step: 0)
                case .run:
                    continue
                }
                #expect(prepared.apply(adapter) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_433)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var laterFrames: Int = 0
        var nonEmptyCasts: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...16) {
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
            let payload: [MoonlitMechanismRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Every key frame of the level, at every tier: the digest, the play and the verdict hold.
            for frame in 0..<core.play.level.keyFrames.count {
                let show = ExperienceAction(control: "frame.show", values: [Double(frame)], step: 0)
                #expect(core.apply(show) == .accepted)
                if frame > 0 { laterFrames += 1 }
                var first: MoonlitMechanismSceneSnapshot? = nil
                for tier in 0..<Core.qualityTiers {
                    core.setQualityTier(tier)
                    let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: time + Double(tier))
                    Self.expectMirrors(snapshot, core)
                    if !snapshot.cast.isEmpty { nonEmptyCasts += 1 }
                    #expect(snapshot.time == time + Double(tier))
                    // Read again at the same time: the same snapshot.
                    #expect(core.snapshot(time: time + Double(tier)) == snapshot)
                    if let first {
                        // Equal states at different times and tiers: only `time` differs.
                        Self.expectSameButTime(first, snapshot)
                        #expect(first != snapshot)
                    } else {
                        first = snapshot
                    }
                    core.update(step: 1)
                }
                #expect(try Self.digest(core) == before && core == copy)
            }
            // A key frame the level lacks is refused and changes nothing.
            let shownBefore: Int = core.shownFrame
            let missing = ExperienceAction(control: "frame.show", values: [Double(core.play.level.keyFrames.count)],
                                           step: 0)
            if core.play.level.keyFrames.count <= Core.frameRange.upperBound {
                #expect(core.apply(missing) == .rejected(.rule(code: MoonlitMechanismExperienceRule.frame)))
            } else {
                #expect(!core.apply(missing).isAccepted)
            }
            #expect(core.shownFrame == shownBefore)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectMirrors(oddSnapshot, core)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == payload)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && laterFrames > 200, "the samples spread over plays and key frames")
        #expect(won + failed > 0 && nonEmptyCasts > 300, "the samples include decided plays and drawn shadows")
    }
}
