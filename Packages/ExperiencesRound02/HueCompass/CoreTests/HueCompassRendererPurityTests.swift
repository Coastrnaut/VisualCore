// HueCompassRendererPurityTests — feature 333 (R02-G04-03) T-R02G0403-005 (FR-R02G0403-003; SC-R02G0403-002;
// clarification Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any
// presentation time, change the quality tier, step the host — leaves the adapter's digest, its state and the kernel's
// verdict (stage and failure) unchanged, over 200 seeded snapshots (seed 2_333: random turns, probes, undo, redo and
// occasional selections on certified levels); every snapshot copies the kernel's fields exactly and carries the target
// only once the play has ended, so no snapshot of a playing level has one; two levels identical except the target give
// equal snapshots while playing under the same turns, undo and redo (a probe's clue depends on the target by design, so
// the twins are compared without probes). Four certified levels are generated once and reused, so the run stays short.
@testable import HueCompassCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct HueCompassRendererPurityTests {
    typealias Core = HueCompassExperienceCore

    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage and, when it failed, why.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + (core.play.failure?.rawValue ?? "-")
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly, the target only once the play has ended.
    static func expectMirrors(_ snapshot: HueCompassSceneSnapshot, _ core: Core) {
        let play: HueCompassPlay = core.play
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.bearing == play.bearing)
        #expect(snapshot.offset == play.level.offset && snapshot.fog == play.level.fog)
        #expect(snapshot.bearingTolerance == play.level.bearingTolerance)
        #expect(snapshot.bandTolerance == play.level.bandTolerance)
        #expect(snapshot.clues == play.clues && snapshot.selection == play.selection)
        #expect(snapshot.stage == play.stage)
        if play.stage == .playing {
            #expect(snapshot.target == nil)
        } else {
            #expect(snapshot.target == play.level.target)
        }
        #expect(snapshot.time.isFinite)
    }

    @Test func testHueCompassRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "compass.turn", values: [6], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: HueCompassSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.target == nil)
            #expect(try Self.digest(core) == before)
        }
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Four certified levels (the tutorial and later bands), generated once.
        let numbers: [Int] = [1, 13, 42, 64]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_333)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // A few seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...5) {
                let kind: Int = random.int(0...9)
                let action: ExperienceAction
                switch kind {
                case 0...4:
                    action = ExperienceAction(control: "compass.turn", values: [Double(random.int(-48...48))], step: 0)
                case 5, 6:
                    action = ExperienceAction(control: "compass.probe", step: 0)
                case 7:
                    action = ExperienceAction(control: "play.undo", step: 0)
                case 8:
                    action = ExperienceAction(control: "play.redo", step: 0)
                default:
                    let values: [Double] = [Double(random.int(0...95)), Double(random.int(0...23))]
                    action = ExperienceAction(control: "compass.select", values: values, step: 0)
                }
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: HueCompassSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core)
                core.update(step: 1)
            }
            core.setQualityTier(random.int(0...2))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 50 && ended > 5)
    }

    @Test func twoLevelsDifferingOnlyInTheTargetGiveEqualSnapshotsWhilePlaying() async throws {
        let numbers: [Int] = [1, 50, 100]
        var random = SeededRandom(seed: 2_333)
        for number in numbers {
            let base: HueCompassLevel = try Core.level(number: number)
            // Another target, still farther from the start than the bearing tolerance and distinct from the first.
            var other: Int = (base.target + 37) % 96
            while other == base.target
                || HueCompassWheel.bearingDistance(base.start, other) <= base.bearingTolerance {
                other = (other + 1) % 96
            }
            let twin = try HueCompassLevel(id: base.id, seed: base.seed, band: base.band, offset: base.offset,
                                           fog: base.fog, target: other, start: base.start,
                                           bearingTolerance: base.bearingTolerance,
                                           bandTolerance: base.bandTolerance, allowance: base.allowance,
                                           tutorial: base.tutorial)
            #expect(twin.target != base.target && twin.fingerprint != base.fingerprint)
            let firstPlay: HueCompassPlay = try Core.freshPlay(of: base)
            let secondPlay: HueCompassPlay = try Core.freshPlay(of: twin)
            var first = Core(levelNumber: number, play: firstPlay, openingNumber: number, openingPlay: firstPlay)
            var second = Core(levelNumber: number, play: secondPlay, openingNumber: number, openingPlay: secondPlay)
            #expect(first.snapshot(time: 0) == second.snapshot(time: 0))
            for step in 0..<30 {
                let kind: Int = random.int(0...5)
                let action: ExperienceAction
                switch kind {
                case 0...3:
                    action = ExperienceAction(control: "compass.turn", values: [Double(random.int(-48...48))], step: 0)
                case 4:
                    action = ExperienceAction(control: "play.undo", step: 0)
                default:
                    action = ExperienceAction(control: "play.redo", step: 0)
                }
                let a: ActionResult = first.apply(action)
                let b: ActionResult = second.apply(action)
                #expect(a == b, "level \(number) step \(step)")
                let time: Double = Double(step) * 0.25
                let left: HueCompassSceneSnapshot = first.snapshot(time: time)
                let right: HueCompassSceneSnapshot = second.snapshot(time: time)
                #expect(left.stage == .playing && left.target == nil)
                #expect(left == right, "level \(number) step \(step)")
            }
            // Once the play ends, each snapshot shows its own target.
            let miss: ExperienceAction = ExperienceAction(control: "compass.select",
                                                          values: [Double((base.target + 48) % 96),
                                                                   Double((base.targetBand + 12) % 24)], step: 0)
            #expect(first.apply(miss) == .accepted && second.apply(miss) == .accepted)
            #expect(first.snapshot(time: 0).target == base.target && second.snapshot(time: 0).target == other)
        }
    }
}
