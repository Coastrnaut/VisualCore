// ReplayTests — feature 075 (A10-P01) T-A10-103 (FR-A10-112; clarification 4; research D4; SC-A10-102). Input replay,
// host-free and short: a replay is a seed plus a list of (step, steering value) entries; playing 12 recorded steering
// inputs over 1,200 steps twice gives the identical run (score, lives, event count and the events themselves); saving
// the run as JSON with the generator state halfway and restoring both continues to the same run; another seed gives a
// different run; events keep the last 256 while the event count keeps the total.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct ReplayTests {
    private let catalog = ArcadeCatalog.bundled

    /// Twelve recorded steering inputs: (step at which it applies, value).
    private static let inputs: [(step: Int, value: Double)] = [
        (0, 0.6), (45, -0.3), (120, -1.0), (210, 0.25), (300, 1.0), (390, 0.0),
        (480, -0.75), (600, 0.5), (720, -0.2), (850, 0.9), (990, -1.0), (1100, 0.35),
    ]

    /// Plays the recorded inputs from `seed` for `steps` steps, starting from `run` and `random` when given.
    private func play(seed: UInt64, steps: ClosedRange<Int> = 0...1199, run start: GameRun? = nil,
                      random startRandom: SeededRandom? = nil) -> (GameRun, SeededRandom) {
        var run = start ?? GameRun.new()
        var random = startRandom ?? SeededRandom(seed: seed)
        for step in steps {
            for input in Self.inputs where input.step == step { GameSimulation.steer(&run, value: input.value) }
            GameSimulation.advance(&run, catalog: catalog, random: &random)
        }
        return (run, random)
    }

    @Test func replayingTheSameInputsTwiceGivesTheSameRun() {
        #expect(Self.inputs.count == 12)
        var totalEvents = 0
        for seed: UInt64 in [7, 2026, 31_337] {
            let (a, randomA) = play(seed: seed)
            let (b, randomB) = play(seed: seed)
            #expect(a.score == b.score && a.lives == b.lives)
            #expect(a.eventCount == b.eventCount && a.events == b.events)
            #expect(a == b && randomA == randomB)
            #expect(a.over || a.step == 1200)
            #expect(a.nextObjectId > 0)
            #expect(a.validate().isEmpty)
            totalEvents += a.eventCount
        }
        #expect(totalEvents > 0)   // the replays include contacts, so the event comparison is not vacuous
    }

    @Test func savingAndRestoringHalfwayContinuesTheSameRun() throws {
        let (whole, wholeRandom) = play(seed: 2026)
        let (half, halfRandom) = play(seed: 2026, steps: 0...599)
        let savedRun = try JSONEncoder().encode(half)
        let savedRandom = try JSONEncoder().encode(halfRandom.state)
        let restoredRun = try JSONDecoder().decode(GameRun.self, from: savedRun)
        let restoredRandom = try SeededRandom(restoring: JSONDecoder().decode(SeededRandom.State.self,
                                                                              from: savedRandom))
        let (continued, continuedRandom) = play(seed: 2026, steps: 600...1199, run: restoredRun,
                                                random: restoredRandom)
        #expect(continued == whole && continuedRandom == wholeRandom)
    }

    @Test func anotherSeedGivesAnotherRun() {
        #expect(play(seed: 7).0 != play(seed: 8).0)
    }

    @Test func eventsKeepTheLast256AndCountEveryEvent() {
        var game = GameRun.new()
        var random = SeededRandom(seed: 1)
        for i in 0..<300 {
            game.objects = [FallingObject(id: i, contentId: "glow-orb", kind: .orb, position: Vec2(4.5, 1.5),
                                          velocity: Vec2(0, -4), radius: 0.25, value: 10)]
            game.nextObjectId = i + 1
            game.step = 0   // stay before the first spawn step
            GameSimulation.advance(&game, catalog: catalog, random: &random)
        }
        #expect(game.eventCount == 300 && game.events.count == 256)
        #expect(game.events.first?.objectId == 44 && game.events.last?.objectId == 299)
        #expect(game.score == 3000)
    }
}
