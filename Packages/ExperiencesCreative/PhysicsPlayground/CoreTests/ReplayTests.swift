// ReplayTests — feature 082 (A11-P01) T-A11-103 (FR-A11-112; clarification 4; research D4; SC-A11-104). Input replay,
// host-free and short: a replay is a seed plus a list of (tick, action) entries (drops of a circle or a box, pause,
// single steps, resume and time-scale changes); playing it twice gives the identical encoded world and generator;
// saving the world as JSON with the generator state halfway and restoring both continues to the same world; another
// seed gives a different world.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct ReplayTests {
    private let catalog = MaterialCatalog.bundled

    /// One recorded input.
    private enum Action { case drop(BodyKind), pause, step, resume, timeScale(Int) }

    /// The recorded inputs: (host step at which it applies, action).
    private static let inputs: [(step: Int, action: Action)] = [
        (0, .drop(.circle)), (30, .drop(.box)), (60, .drop(.box)), (90, .timeScale(1)), (150, .drop(.circle)),
        (200, .pause), (201, .step), (202, .step), (210, .resume), (220, .timeScale(3)), (260, .drop(.box)),
        (300, .timeScale(0)), (340, .drop(.circle)), (380, .timeScale(2)),
    ]

    /// Plays the recorded inputs over host `steps` from the given world and generator.
    private func play(_ steps: Range<Int>, world start: PhysicsWorld, random startRandom: SeededRandom)
        -> (PhysicsWorld, SeededRandom) {
        var world = start, random = startRandom
        for step in steps {
            for input in Self.inputs where input.step == step {
                switch input.action {
                case .drop(let kind): WorldSimulation.drop(&world, kind: kind, random: &random, catalog: catalog)
                case .pause: world.paused = true
                case .step: #expect(WorldSimulation.step(&world, catalog: catalog))
                case .resume: world.paused = false
                case .timeScale(let index): world.timeScaleIndex = index
                }
            }
            WorldSimulation.advanceHostStep(&world, catalog: catalog)
        }
        return (world, random)
    }

    /// The starting world and generator of `seed`.
    private func start(_ seed: UInt64) -> (PhysicsWorld, SeededRandom) {
        var random = SeededRandom(seed: seed)
        let world = StartingScene.make(random: &random, catalog: catalog)
        return (world, random)
    }

    @Test func replayingTheSameInputsTwiceGivesTheSameWorld() {
        for seed: UInt64 in [7, 2026] {
            let (world, random) = start(seed)
            let (a, randomA) = play(0..<420, world: world, random: random)
            let (b, randomB) = play(0..<420, world: world, random: random)
            #expect(a.encoded() == b.encoded() && !a.encoded().isEmpty)
            #expect(randomA == randomB)
            #expect(a.bodies.count == 10 + 6 && a.validate().isEmpty)
            #expect(a.tick > 300)
        }
        let (other, _) = play(0..<420, world: start(8).0, random: start(8).1)
        let (seven, _) = play(0..<420, world: start(7).0, random: start(7).1)
        #expect(other.encoded() != seven.encoded())
    }

    @Test func savingHalfwayAndRestoringContinuesToTheSameWorld() throws {
        let (world, random) = start(99)
        let (whole, wholeRandom) = play(0..<420, world: world, random: random)
        let (half, halfRandom) = play(0..<205, world: world, random: random)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let savedWorld = half.encoded()
        let savedRandom = try encoder.encode(halfRandom.state)
        let restoredWorld = try JSONDecoder().decode(PhysicsWorld.self, from: savedWorld)
        let restoredRandom = try SeededRandom(restoring: try JSONDecoder().decode(SeededRandom.State.self,
                                                                                  from: savedRandom))
        #expect(restoredWorld == half && restoredWorld.paused)
        let (continued, continuedRandom) = play(205..<420, world: restoredWorld, random: restoredRandom)
        #expect(continued.encoded() == whole.encoded())
        #expect(continuedRandom == wholeRandom)
    }
}
