// BackwardsAuroraRendererPurityTests — feature 393 (R02-G10-03) T-R02G1003-005 (FR-R02G1003-003, 005; clarification
// Q5, renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation time
// (non-finite ones included) and any chosen section (out-of-range ones included), read them repeatedly, change the
// quality tier, step the host — leaves the adapter's digest, its state and the kernel's verdict (stage and failure)
// unchanged, over 200 seeded snapshots (fixture seed 2_393: random reversals, undo and redo on certified levels 1, 21,
// 41, 61, 81 and 100); every snapshot copies the kernel's fields exactly (samples, matched, kinks = the bends above L,
// the tear seam from the failure, the section clamped to the wave); two snapshots of equal states at different times
// differ only in `time`. The six levels are certified once and reused, so the run stays short. Explicit types, plain
// loops.
@testable import BackwardsAuroraCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct BackwardsAuroraRendererPurityTests {
    typealias Core = BackwardsAuroraExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage and, when it failed, why.
    static func verdict(_ core: Core) -> String {
        var text: String = core.play.stage.rawValue + "/"
        switch core.play.failure {
        case let .tear(move, seam)?: text += "tear \(move) \(seam)"
        case .budget?: text += "budget"
        case nil: text += "-"
        }
        return text
    }

    /// Checks that `snapshot`, asked for with section [`start`, `end`], copies the kernel's state of `core` exactly.
    static func expectMirrors(_ snapshot: BackwardsAuroraSceneSnapshot, _ core: Core, start: Int, end: Int) {
        let play: BackwardsAuroraPlay = core.play
        let level: BackwardsAuroraLevel = play.level
        let wave: BackwardsAuroraWave = play.wave
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.samples == wave.samples && snapshot.target == level.target.samples)
        #expect(snapshot.checkpoints == level.checkpoints && snapshot.bendLimit == level.bendLimit)
        var matched: [Bool] = []
        for position in level.checkpoints { matched.append(wave.samples[position] == level.target.samples[position]) }
        #expect(snapshot.matched == matched)
        var kinks: [Int] = []
        for k in 1...(wave.count - 2) {
            let bend: Int = wave.samples[k - 1] - 2 * wave.samples[k] + wave.samples[k + 1]
            if abs(bend) > level.bendLimit { kinks.append(k) }
        }
        #expect(snapshot.kinks == kinks)
        var tear: Int? = nil
        if case let .tear(_, seam)? = play.failure { tear = seam }
        #expect(snapshot.tear == tear)
        let clampedStart: Int = min(max(start, 0), wave.count - 2)
        let clampedEnd: Int = min(max(end, clampedStart + 1), wave.count - 1)
        #expect(snapshot.sectionStart == clampedStart && snapshot.sectionEnd == clampedEnd)
        #expect(snapshot.sectionStart >= 0 && snapshot.sectionStart < snapshot.sectionEnd)
        #expect(snapshot.sectionEnd <= wave.count - 1)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.spent == play.spent && snapshot.budget == level.budget && snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: BackwardsAuroraSceneSnapshot, _ b: BackwardsAuroraSceneSnapshot) {
        #expect(a.samples == b.samples && a.target == b.target && a.checkpoints == b.checkpoints)
        #expect(a.matched == b.matched && a.bendLimit == b.bendLimit && a.kinks == b.kinks && a.tear == b.tear)
        #expect(a.sectionStart == b.sectionStart && a.sectionEnd == b.sectionEnd)
        #expect(a.stage == b.stage && a.failure == b.failure && a.spent == b.spent && a.budget == b.budget)
        #expect(a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly reversals of sections of its wave, sometimes odd ones, undo and redo.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.wave.count
        switch random.int(0...9) {
        case 0...6:
            let start: Int = random.int(0...(count - 2))
            let end: Int = random.int((start + 1)...min(count - 1, start + 6))
            return ExperienceAction(control: "wave.reverse", values: [Double(start), Double(end)], step: 0)
        case 7:
            let start: Double = Double(random.int(0...31))
            let end: Double = Double(random.int(0...31))
            return ExperienceAction(control: "wave.reverse", values: [start, end], step: 0)
        case 8:
            return ExperienceAction(control: "play.undo", step: 0)
        default:
            return ExperienceAction(control: "play.redo", step: 0)
        }
    }

    @Test func testBackwardsAuroraRendererpurityBoundary() async throws {
        // Direct example: level 1 after one reversal, read at the boundary times, odd sections and every tier.
        var core: Core = try await Core.prepare(seed: 0)
        let reverse = ExperienceAction(control: "wave.reverse", values: [0, 2], step: 0)
        #expect(core.apply(reverse) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        let starts: [Int] = [0, -4, 13, 40, 5, 2, 12, -1]
        let ends: [Int] = [1, -9, 13, 50, 3, 9, 99, 0]
        for index in times.indices {
            let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: starts[index],
                                                                       sectionEnd: ends[index], time: times[index])
            Self.expectMirrors(snapshot, core, start: starts[index], end: ends[index])
            #expect(snapshot.time == (times[index].isFinite ? times[index] : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        // Non-finite times read as time 0.
        let zero: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 0, sectionEnd: 1, time: 0)
        #expect(core.snapshot(sectionStart: 0, sectionEnd: 1, time: .nan) == zero)
        #expect(core.snapshot(sectionStart: 0, sectionEnd: 1, time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(sectionStart: 0, sectionEnd: 1, time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once.
        let numbers: [Int] = [1, 21, 41, 61, 81, 100]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_393)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        var torn: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...16) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            if case .tear? = core.play.failure { torn += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let start: Int = random.int(-4...35)
            let end: Int = random.int(-4...35)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: BackwardsAuroraSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: start, sectionEnd: end,
                                                                           time: time + Double(tier))
                Self.expectMirrors(snapshot, core, start: start, end: end)
                #expect(snapshot.time == time + Double(tier))
                // Read again at the same time: the same snapshot.
                #expect(core.snapshot(sectionStart: start, sectionEnd: end, time: time + Double(tier)) == snapshot)
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
            let oddSnapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: start, sectionEnd: end,
                                                                          time: odd[random.int(0...2)])
            Self.expectMirrors(oddSnapshot, core, start: start, end: end)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && ended > 5 && torn > 0,
                "accepted \(accepted) playing \(playing) ended \(ended) torn \(torn)")
    }
}
