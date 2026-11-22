// AmethystEscapeRendererPurityTests — feature 363 (R02-G07-03) T-R02G0703-005 (FR-R02G0703-002, 003, 006; clarifications
// Q4, Q5, renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation time
// (non-finite ones included), change the quality tier, step the host — leaves the adapter's digest, its state and the
// kernel's verdict (stage and failure) unchanged, over 200 seeded snapshots (seed 2_363: random rotations, advances, undo
// and redo on certified levels of bands 1 and 2); every snapshot copies the kernel's fields exactly; two snapshots of
// equal states at different times differ only in `time`. Four certified levels are generated once and reused, so the
// run stays short.
@testable import AmethystEscapeCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AmethystEscapeRendererPurityTests {
    typealias Core = AmethystEscapeExperienceCore

    /// The digest of `core` as the engine computes it.
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
    static func expectMirrors(_ snapshot: AmethystEscapeSceneSnapshot, _ core: Core) {
        let play: AmethystEscapePlay = core.play
        let level: AmethystEscapeLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.sectors == level.sectors)
        #expect(snapshot.shells.map(\.apertures) == level.shells.map(\.apertures))
        #expect(snapshot.shells.map(\.walls) == level.shells.map(\.walls))
        #expect(snapshot.shells.map(\.blocked) == level.shells.map(\.blocked))
        #expect(snapshot.shells.map(\.offset) == play.crystal.offsets)
        #expect(snapshot.pearl == play.crystal.pearl)
        let exit: Int = (level.exitGap + play.crystal.offsets[level.outermost]) % level.sectors
        #expect(snapshot.exitGap == exit)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.moves == play.moves && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: AmethystEscapeSceneSnapshot, _ b: AmethystEscapeSceneSnapshot) {
        #expect(a.sectors == b.sectors && a.shells == b.shells && a.pearl == b.pearl && a.exitGap == b.exitGap)
        #expect(a.stage == b.stage && a.failure == b.failure && a.moves == b.moves && a.budget == b.budget)
        #expect(a.levelNumber == b.levelNumber)
    }

    @Test func testAmethystEscapeRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times and every tier, clamped tiers included.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "shell.rotate", values: [1, 1], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? time : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        // Non-finite times read as time 0.
        #expect(core.snapshot(time: .nan) == core.snapshot(time: 0))
        #expect(core.snapshot(time: .infinity) == core.snapshot(time: 0))
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Four certified levels of bands 1 and 2, generated once.
        let numbers: [Int] = [1, 9, 23, 37]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_363)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...12) {
                let level: AmethystEscapeLevel = core.play.level
                let kind: Int = random.int(0...9)
                let action: ExperienceAction
                switch kind {
                case 0...4:
                    let shell: Double = Double(random.int(0...(level.shells.count - 1)))
                    let step: Double = random.int(0...1) == 0 ? -1 : 1
                    action = ExperienceAction(control: "shell.rotate", values: [shell, step], step: 0)
                case 5...7:
                    action = ExperienceAction(control: "pearl.advance", step: 0)
                case 8:
                    action = ExperienceAction(control: "play.undo", step: 0)
                default:
                    action = ExperienceAction(control: "play.redo", step: 0)
                }
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: AmethystEscapeSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: time + Double(tier))
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
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && ended > 5, "accepted \(accepted) playing \(playing) ended \(ended)")
    }
}
