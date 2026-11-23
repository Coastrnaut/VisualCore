// HarmonicBridgesRendererPurityTests — feature 413 (R02-G12-03) T-R02G1203-005 (FR-R02G1203-003, 005; clarification
// Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation time
// (negative and non-finite ones included), read them repeatedly, change the quality tier, step the host — leaves the
// adapter's digest, its state and the kernel's verdict (stage, failure and actions left) unchanged, over 200 seeded
// snapshots (fixture seed 2_413: random tunings, tests, odd strings and pegs, undo and redo on certified levels 1, 21,
// 41, 61, 81 and 100). Every snapshot's report is the kernel's exact report at the play's pegs: each swing, bridge and
// reached island equals the kernel's resonance and reachability, so a sample mark (swing against the threshold) and a
// bridge are the kernel's, and the drawn wave (modes and strengths, presentation only) cannot change either; the
// snapshot's modes are exactly the kernel's resonant modes. Two snapshots of equal states at different times differ only
// in `time`. The six levels are certified once and reused, so the run stays short. Explicit types, plain loops.
@testable import HarmonicBridgesCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct HarmonicBridgesRendererPurityTests {
    typealias Core = HarmonicBridgesExperienceCore

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
        case let .broken(step, string)?:
            var named: String = "none"
            if let string { named = String(string) }
            text += "broken \(step) " + named
        case let .budget(index)?: text += "budget \(index)"
        case nil: text += "-"
        }
        text += "/\(core.play.actionsLeft)"
        return text
    }

    /// Checks that `snapshot` copies the play of `core` and carries the kernel's exact report, so no drawn value can
    /// stand in for a swing, a sample mark, a bridge or a reached island.
    static func expectMirrors(_ snapshot: HarmonicBridgesSceneSnapshot, _ core: Core) {
        let play: HarmonicBridgesPlay = core.play
        let level: HarmonicBridgesLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.islands == level.islands && snapshot.strings == level.strings)
        #expect(snapshot.pegs == play.pegs)
        let exact: HarmonicBridgesReport = level.report(pegs: play.pegs)
        #expect(snapshot.report == play.report && snapshot.report == exact)
        #expect(snapshot.steps == level.steps.count)
        for step in 0..<level.steps.count {
            for string in 0..<level.strings.count {
                let resonance: HarmonicBridgesResonance = level.resonance(string, step: step, peg: play.pegs[string])
                let swing: [Int] = snapshot.report.swings[step][string]
                #expect(swing == resonance.swing, "swing \(step) \(string)")
                #expect(snapshot.isBridge(string, step: step) == resonance.bridge, "bridge \(step) \(string)")
                // The sample marks: filled exactly where the kernel's swing reaches the threshold.
                for sample in 0..<swing.count {
                    let filled: Bool = swing[sample] >= snapshot.threshold
                    #expect(filled == (resonance.swing[sample] >= level.threshold), "mark \(step) \(string) \(sample)")
                }
                // The wave's modes are the kernel's resonant modes (presentation only).
                let modes: [Int] = snapshot.modes[step][string].sorted()
                #expect(modes == resonance.resonatingModes, "modes \(step) \(string)")
                #expect(snapshot.strengths[step][string].count == snapshot.modes[step][string].count)
            }
            for island in 0..<level.islands.count {
                #expect(snapshot.isReached(island, step: step) == exact.reached[step][island], "reached \(island)")
            }
        }
        #expect(snapshot.threshold == level.threshold && snapshot.start == level.start && snapshot.goal == level.goal)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
        #expect(snapshot.shownStep >= 0 && snapshot.shownStep < max(1, snapshot.steps))
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: HarmonicBridgesSceneSnapshot, _ b: HarmonicBridgesSceneSnapshot) {
        #expect(a.islands == b.islands && a.strings == b.strings && a.pegs == b.pegs && a.report == b.report)
        #expect(a.modes == b.modes && a.strengths == b.strengths && a.threshold == b.threshold)
        #expect(a.start == b.start && a.goal == b.goal && a.stage == b.stage && a.failure == b.failure)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly tunings of the level's strings, sometimes a test, odd strings and pegs, undo
    /// and redo.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.level.strings.count
        switch random.int(0...11) {
        case 0...5:
            let string: Double = Double(random.int(0...(count - 1)))
            let peg: Double = Double(random.int(1...12))
            return ExperienceAction(control: "string.tune", values: [string, peg], step: 0)
        case 6:
            return ExperienceAction(control: "crossing.test", step: 0)
        case 7:
            let string: Double = Double(random.int(0...11))
            let peg: Double = Double(random.int(0...13))
            return ExperienceAction(control: "string.tune", values: [string, peg], step: 0)
        case 8, 9:
            return ExperienceAction(control: "play.undo", step: 0)
        default:
            return ExperienceAction(control: "play.redo", step: 0)
        }
    }

    @Test func testHarmonicBridgesRendererpurityBoundary() async throws {
        // Direct example: level 1 after one tuning, read at the boundary times and every tier.
        var core: Core = try await Core.prepare(seed: 0)
        let tune = ExperienceAction(control: "string.tune", values: [0, 3], step: 0)
        #expect(core.apply(tune) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: HarmonicBridgesSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once.
        let numbers: [Int] = [1, 21, 41, 61, 81, 100]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_413)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var withBridges: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...24) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            var bridges: Int = 0
            for count in core.play.report.bridgeCounts { bridges += count }
            if bridges > 0 { withBridges += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: HarmonicBridgesSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core)
                #expect(snapshot.time == time + Double(tier))
                // Read again at the same time: the same snapshot.
                #expect(core.snapshot(time: time + Double(tier)) == snapshot)
                if let first {
                    // Equal states at different times: only `time` differs.
                    Self.expectSameButTime(first, snapshot)
                    #expect(first != snapshot)
                } else {
                    first = snapshot
                }
                core.update(step: 1)
            }
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectMirrors(oddSnapshot, core)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && withBridges > 50,
                "accepted \(accepted) playing \(playing) bridges \(withBridges)")
        #expect(won + failed > 0, "won \(won) failed \(failed)")
    }
}
