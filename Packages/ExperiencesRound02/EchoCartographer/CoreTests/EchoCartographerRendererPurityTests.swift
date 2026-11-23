// EchoCartographerRendererPurityTests — feature 403 (R02-G11-03) T-R02G1103-005 (FR-R02G1103-003, 005; clarification
// Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any presentation time
// (negative and non-finite ones included), read them repeatedly, change the quality tier, step the host — leaves the
// adapter's digest, its state and the kernel's verdict (stage, failure and energy) unchanged, over 200 seeded snapshots
// (fixture seed 2_403: random pulses, claims, marks, odd cells, undo and redo on certified levels 1, 21, 41, 61, 81 and
// 100). Every snapshot holds only what the player knows: its knowledge equals the play's (which reveals only true
// walls and true open cells), so it holds no unknown wall, and its located cells are exactly the beacons the play has
// located, so it holds no unlocated beacon; two snapshots of equal states at different times differ only in `time`.
// The six levels are certified once and reused, so the run stays short. Explicit types, plain loops.
@testable import EchoCartographerCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct EchoCartographerRendererPurityTests {
    typealias Core = EchoCartographerExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure when it failed, and the energy left.
    static func verdict(_ core: Core) -> String {
        var text: String = core.play.stage.rawValue + "/"
        switch core.play.failure {
        case let .energy(index)?: text += "energy \(index)"
        case nil: text += "-"
        }
        text += "/\(core.play.energy)"
        return text
    }

    /// Checks that `snapshot` copies exactly what the player of `core` knows, and nothing hidden.
    static func expectMirrors(_ snapshot: EchoCartographerSceneSnapshot, _ core: Core) {
        let play: EchoCartographerPlay = core.play
        let level: EchoCartographerLevel = play.level
        let chamber: EchoCartographerChamber = level.chamber
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.width == chamber.width && snapshot.height == chamber.height)
        #expect(snapshot.knowledge == play.knowledge.cells && snapshot.entry == level.entry)
        // No unknown wall: every wall the snapshot holds is known to the play and a true wall; every open cell too.
        for index in 0..<snapshot.knowledge.count {
            let cell: EchoCartographerCell = chamber.cell(index)
            switch snapshot.knowledge[index] {
            case .wall: #expect(chamber.isWall(cell) && play.knowledge[index] == .wall, "wall \(index)")
            case .open: #expect(chamber.isOpen(cell) && play.knowledge[index] == .open, "open \(index)")
            case .unknown: #expect(play.knowledge[index] == .unknown, "unknown \(index)")
            }
        }
        // No unlocated beacon: the located cells are exactly the beacons the play located, in beacon order.
        var located: [EchoCartographerCell] = []
        for index in play.located.keys.sorted() { located.append(level.beacons[index]) }
        #expect(snapshot.located == located)
        for cell in snapshot.located { #expect(level.beacons.contains(cell)) }
        #expect(snapshot.located.count == play.located.count)
        #expect(snapshot.markers == play.markers && snapshot.lastEcho == play.lastEcho)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.energy == play.energy && snapshot.budget == level.energy && snapshot.time.isFinite)
        #expect(snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: EchoCartographerSceneSnapshot, _ b: EchoCartographerSceneSnapshot) {
        #expect(a.width == b.width && a.height == b.height && a.knowledge == b.knowledge && a.entry == b.entry)
        #expect(a.markers == b.markers && a.located == b.located && a.lastEcho == b.lastEcho)
        #expect(a.stage == b.stage && a.failure == b.failure && a.energy == b.energy && a.budget == b.budget)
        #expect(a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly pulses from known-open cells and claims, sometimes marks, odd cells, undo
    /// and redo.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let chamber: EchoCartographerChamber = core.play.level.chamber
        switch random.int(0...11) {
        case 0...3:
            var open: [Int] = []
            for index in 0..<chamber.cellCount where core.play.knowledge[index] == .open { open.append(index) }
            let cell: EchoCartographerCell = chamber.cell(open[random.int(0...(open.count - 1))])
            return ExperienceAction(control: "cell.pulse", values: [Double(cell.x), Double(cell.y)], step: 0)
        case 4...6:
            let x: Double = Double(random.int(0...(chamber.width - 1)))
            let y: Double = Double(random.int(0...(chamber.height - 1)))
            return ExperienceAction(control: "cell.claim", values: [x, y], step: 0)
        case 7:
            let x: Double = Double(random.int(0...(chamber.width - 1)))
            let y: Double = Double(random.int(0...(chamber.height - 1)))
            return ExperienceAction(control: "cell.mark", values: [x, y], step: 0)
        case 8:
            let controls: [String] = ["cell.pulse", "cell.claim", "cell.mark"]
            let x: Double = Double(random.int(0...15))
            let y: Double = Double(random.int(0...15))
            return ExperienceAction(control: controls[random.int(0...2)], values: [x, y], step: 0)
        case 9, 10:
            return ExperienceAction(control: "play.undo", step: 0)
        default:
            return ExperienceAction(control: "play.redo", step: 0)
        }
    }

    @Test func testEchoCartographerRendererpurityBoundary() async throws {
        // Direct example: level 1 after one pulse, read at the boundary times and every tier.
        var core: Core = try await Core.prepare(seed: 0)
        let pulse = ExperienceAction(control: "cell.pulse", values: [0, 3], step: 0)
        #expect(core.apply(pulse) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: EchoCartographerSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: EchoCartographerSceneSnapshot = core.snapshot(time: 0)
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
        var random = SeededRandom(seed: 2_403)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var withWalls: Int = 0
        var withLocated: Int = 0
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
            if core.play.knowledge.revealed.wall > 0 { withWalls += 1 }
            if !core.play.located.isEmpty { withLocated += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: EchoCartographerSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: EchoCartographerSceneSnapshot = core.snapshot(time: time + Double(tier))
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
            let oddSnapshot: EchoCartographerSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectMirrors(oddSnapshot, core)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && withWalls > 100 && withLocated > 5,
                "accepted \(accepted) playing \(playing) walls \(withWalls) located \(withLocated)")
        #expect(won + failed > 0, "won \(won) failed \(failed)")
    }
}
