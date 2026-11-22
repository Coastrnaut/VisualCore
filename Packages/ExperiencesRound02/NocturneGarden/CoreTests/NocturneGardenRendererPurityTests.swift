// NocturneGardenRendererPurityTests — feature 383 (R02-G09-03) T-R02G0903-005 (FR-R02G0903-002, 003, 005; clarification
// Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation time
// (non-finite ones included), read them repeatedly, change the quality tier, step the host — leaves the adapter's
// digest, its state and the kernel's verdict (stage and failure) unchanged, over 200 seeded snapshots (fixture seed
// 2_383: random plants, moves, resizes, removals, sun changes, undo and redo on certified levels 1, 21, 41, 61 and 81);
// every snapshot copies the kernel's fields exactly; two snapshots of equal states at different times differ only in
// `time`. The five levels are certified once and reused, so the run stays short. Explicit types, plain loops.
@testable import NocturneGardenCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct NocturneGardenRendererPurityTests {
    typealias Core = NocturneGardenExperienceCore

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
        case .leak(let move): text += "leak \(move)"
        case .budget: text += "budget"
        case nil: text += "-"
        }
        return text
    }

    /// Checks that `snapshot` copies the kernel's state of `core` exactly.
    static func expectMirrors(_ snapshot: NocturneGardenSceneSnapshot, _ core: Core) {
        let play: NocturneGardenPlay = core.play
        let level: NocturneGardenLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.width == level.width && snapshot.height == level.height)
        #expect(snapshot.target == level.target.sorted() && snapshot.forbidden == level.forbidden.sorted())
        #expect(snapshot.shadow == play.mask.cells.sorted())
        #expect(snapshot.leaking == play.mask.cells.intersection(level.forbidden).sorted())
        #expect(snapshot.blooms == play.blooms && snapshot.sun == play.elevation)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.moves == play.moves && snapshot.budget == level.budget)
        #expect(snapshot.sizes == level.sizes.sorted() && snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: NocturneGardenSceneSnapshot, _ b: NocturneGardenSceneSnapshot) {
        #expect(a.width == b.width && a.height == b.height && a.target == b.target && a.forbidden == b.forbidden)
        #expect(a.shadow == b.shadow && a.leaking == b.leaking && a.blooms == b.blooms && a.sizes == b.sizes)
        #expect(a.sun == b.sun && a.stage == b.stage && a.failure == b.failure)
        #expect(a.moves == b.moves && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly legal operands of its level, sometimes odd ones.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let play: NocturneGardenPlay = core.play
        let level: NocturneGardenLevel = play.level
        let sizes: [Int] = level.sizes.sorted()
        let elevations: [Int] = level.elevations.sorted()
        let column: Double = Double(random.int(0...(level.width - 1)))
        let row: Double = Double(random.int(0...(level.height - 1)))
        let size: Double = Double(sizes[random.int(0...(sizes.count - 1))])
        let bloom: Double = Double(random.int(0...max(0, play.blooms.count - 1)))
        switch random.int(0...11) {
        case 0...3:
            let kind: Double = Double(random.int(0...5))
            return ExperienceAction(control: "bloom.plant", values: [kind, column, row, size], step: 0)
        case 4:
            return ExperienceAction(control: "bloom.move", values: [bloom, column, row], step: 0)
        case 5:
            return ExperienceAction(control: "bloom.resize", values: [bloom, size], step: 0)
        case 6:
            return ExperienceAction(control: "bloom.remove", values: [bloom], step: 0)
        case 7, 8:
            let elevation: Double = Double(elevations[random.int(0...(elevations.count - 1))])
            return ExperienceAction(control: "sun.set", values: [elevation], step: 0)
        case 9, 10:
            return ExperienceAction(control: "play.undo", step: 0)
        default:
            return ExperienceAction(control: "play.redo", step: 0)
        }
    }

    @Test func testNocturneGardenRendererpurityBoundary() async throws {
        // Direct example: a prepared level with one bloom read at the boundary times and every tier (clamped ones
        // included).
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "bloom.plant", values: [0, 4, 0, 2], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: time)
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
        // Five certified levels, certified once.
        let numbers: [Int] = [1, 21, 41, 61, 81]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_383)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...12) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: NocturneGardenSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: time + Double(tier))
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
            // Odd times change nothing either.
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
