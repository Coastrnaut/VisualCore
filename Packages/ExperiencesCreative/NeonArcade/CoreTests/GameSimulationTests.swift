// GameSimulationTests — feature 075 (A10-P01) T-A10-103 (FR-A10-111; clarifications 1–3; research D2, D3;
// SC-A10-101, SC-A10-102). The fixed-step rules, host-free and short: the step is 1/60 s; the first object appears at
// step 30 (well within 2 s) for every seed; steering eases the velocity by 1 unit/s per step up to 9 and moves the
// player, and over 10,000 steps × 20 seeds of random steering the player never leaves 0.5…8.5, its speed never
// exceeds 9, objects never exceed 24 and spawned values stay in their ranges (x 0.5…8.5, fall 3…5, radius from the
// catalog, about 70 % hazards); a spawn at the cap is skipped with the same generator use; a hazard hit costs one life,
// starts 90 steps of invulnerability and is removed with a `hit` event; an invulnerable contact passes without
// effect; an orb pickup adds 10; two contacts in one step resolve in id order; a fast circle crossing the player in
// one step is caught by the swept test; capsules hit by end-of-step overlap and the capsule speed bound holds for the
// catalog; objects below y −1 are removed; game over and pause stop the run; the score stops at 9,999,999; a
// non-finite steering value is ignored.
// A10-P02 (feature 076, T-A10-202; FR-A10-201, 203, 205; SC-A10-201, 202): spawning goes through the wave director,
// so the first object still comes at step 30 at a lane centre; the bounded run also checks every spawn against its
// wave's difficulty (speed range, orb value × multiplier) and lane centres, and the 70 % hazard share for `rain`; the
// cap check starts at wave step 30; the capsule bound is checked at the difficulty ceiling (fall ≤ 5); survival adds
// 1 point per 60 played steps (not paused or over); an orb spawned in a later wave is worth its value × multiplier.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct GameSimulationTests {
    private let catalog = ArcadeCatalog.bundled

    /// A new run holding `objects` (ids as given; the next id follows the largest).
    private func run(with objects: [FallingObject]) -> GameRun {
        var run = GameRun.new()
        run.objects = objects
        run.nextObjectId = (objects.map(\.id).max() ?? -1) + 1
        return run
    }

    /// A circle hazard of radius 0.4 at `position`, falling at 4 units/s.
    private func hazard(_ id: Int, at position: Vec2) -> FallingObject {
        FallingObject(id: id, contentId: "spike-ball", kind: .hazard, position: position, velocity: Vec2(0, -4),
                      radius: 0.4)
    }

    /// An orb worth 10 at `position`, falling at 4 units/s.
    private func orb(_ id: Int, at position: Vec2) -> FallingObject {
        FallingObject(id: id, contentId: "glow-orb", kind: .orb, position: position, velocity: Vec2(0, -4),
                      radius: 0.25, value: 10)
    }

    /// Advances `run` `count` steps with `random` (and the bundled catalog unless another is given).
    private func advance(_ run: inout GameRun, _ random: inout SeededRandom, steps count: Int,
                         catalog: ArcadeCatalog = .bundled) {
        for _ in 0..<count { GameSimulation.advance(&run, catalog: catalog, random: &random) }
    }

    @Test func theStepIsOneSixtiethOfASecond() {
        #expect(GameSimulation.step == 1.0 / 60)
    }

    @Test func theFirstObjectAppearsWithinTwoSeconds() {
        for seed in UInt64(1)...20 {
            var game = GameRun.new()
            var random = SeededRandom(seed: seed)
            advance(&game, &random, steps: 30)
            #expect(game.objects.isEmpty && game.nextObjectId == 0)
            advance(&game, &random, steps: 1)
            #expect(game.objects.count == 1 && game.nextObjectId == 1, "seed \(seed)")
            #expect(Lanes.centres.contains(game.objects.first?.position.x ?? -1))
            advance(&game, &random, steps: 89)   // 120 steps = 2 s
            #expect(game.nextObjectId >= 2)
        }
        #expect(WaveDirector.spawnIndex(waveStep: 30, every: 40) == 0)
        #expect(WaveDirector.spawnIndex(waveStep: 70, every: 40) == 1)
        #expect(WaveDirector.spawnIndex(waveStep: 50, every: 40) == nil)
        #expect(WaveDirector.spawnIndex(waveStep: 29, every: 40) == nil)
        #expect(Difficulty(wave: 1).spawnGap == 40)
    }

    @Test func steeringEasesTheVelocityAndMovesThePlayer() {
        // An empty catalog spawns nothing, so no hit can end the run during the check.
        let empty = ArcadeCatalog(items: [])
        var game = GameRun.new()
        var random = SeededRandom(seed: 3)
        GameSimulation.steer(&game, value: 1)
        advance(&game, &random, steps: 1, catalog: empty)
        #expect(abs(game.player.velocity - 1) < 1e-12)
        #expect(abs(game.player.x - (4.5 + 1.0 / 60)) < 1e-12)
        advance(&game, &random, steps: 8, catalog: empty)
        #expect(abs(game.player.velocity - 9) < 1e-9)
        #expect(game.player.x > 4.5)
        advance(&game, &random, steps: 60, catalog: empty)
        #expect(game.player.x == 8.5 && game.player.velocity == 0)
        GameSimulation.steer(&game, value: -0.5)
        advance(&game, &random, steps: 2, catalog: empty)
        #expect(game.player.velocity < 0 && game.player.x < 8.5)
        advance(&game, &random, steps: 600, catalog: empty)
        #expect(game.player.x == 0.5)
        GameSimulation.steer(&game, value: 0)
        advance(&game, &random, steps: 2, catalog: empty)
        #expect(game.player.x == 0.5 && game.player.velocity == 0)
        #expect(game.objects.isEmpty && game.step == 673)
    }

    @Test func thePlayerStaysInsideAndObjectsStayBoundedOver10000StepsAnd20Seeds() {
        // Violations are counted and checked once at the end, so the 200,000 steps stay fast.
        var spawned = 0, hazards = 0, rainSpawned = 0, rainHazards = 0
        var playerOutside = 0, tooFast = 0, tooMany = 0, badSpawns = 0, invalid = 0
        var maxObjects = 0, runsOver = 0
        for seed in UInt64(100)..<120 {
            var game = GameRun.new()
            var random = SeededRandom(seed: seed)
            var steering = SeededRandom(seed: seed &+ 1000)
            for i in 0..<10_000 {
                if i % 37 == 0 { GameSimulation.steer(&game, value: steering.range(-1.5...1.5)) }
                let firstNew = game.nextObjectId
                let difficulty = Difficulty(wave: game.wave), isRain = game.patternId == "rain"
                GameSimulation.advance(&game, catalog: catalog, random: &random)
                if game.player.x < 0.5 || game.player.x > 8.5 || !game.player.x.isFinite { playerOutside += 1 }
                if !(abs(game.player.velocity) <= 9) { tooFast += 1 }
                if game.objects.count > 24 { tooMany += 1 }
                maxObjects = max(maxObjects, game.objects.count)
                for object in game.objects where object.id >= firstNew {
                    spawned += 1
                    if object.kind == .hazard { hazards += 1 }
                    if isRain { rainSpawned += 1; if object.kind == .hazard { rainHazards += 1 } }
                    guard let item = catalog.item(id: object.contentId),
                          Lanes.centres.contains(object.position.x),
                          // Spawned this step, so moved once.
                          abs(object.position.y - GameSimulation.spawnY - object.velocity.y * GameSimulation.step)
                              < 1e-9,
                          difficulty.fallSpeed.contains(-object.velocity.y), (3.0...5.0).contains(-object.velocity.y),
                          object.velocity.x == 0,
                          item.radiusRange.closed.contains(object.radius),
                          object.isCapsule == (item.shape == .bar),
                          item.halfLengthRange.map({ $0.closed.contains(object.halfLength) }) ?? true,
                          object.value == (object.kind == .orb ? item.value * difficulty.orbMultiplier : 0)
                    else { badSpawns += 1; continue }
                }
                if game.over {
                    runsOver += 1
                    if !game.validate().isEmpty { invalid += 1 }
                    GameSimulation.restart(&game)
                }
            }
            if !game.validate().isEmpty { invalid += 1 }
        }
        #expect(playerOutside == 0 && tooFast == 0 && tooMany == 0 && badSpawns == 0 && invalid == 0,
                "\(playerOutside) \(tooFast) \(tooMany) \(badSpawns) \(invalid)")
        #expect(maxObjects > 0 && maxObjects <= 24)
        #expect(runsOver > 0)
        #expect(spawned > 4000 && hazards > 0)
        let share = Double(rainHazards) / Double(rainSpawned)
        #expect(rainSpawned > 1000 && share > 0.65 && share < 0.75, "rain hazard share \(share)")
    }

    @Test func aSpawnAtTheCapIsSkippedWithTheSameGeneratorUse() {
        let full = (0..<24).map { FallingObject(id: $0, contentId: "spike-ball", kind: .hazard,
                                               position: Vec2(0.5 + Double($0) * 0.3, 15), velocity: .zero,
                                               radius: 0.35) }
        var capped = run(with: full)
        capped.waveStep = 30
        var open = GameRun.new()
        open.waveStep = 30
        var randomA = SeededRandom(seed: 44), randomB = SeededRandom(seed: 44)
        GameSimulation.advance(&capped, catalog: catalog, random: &randomA)
        GameSimulation.advance(&open, catalog: catalog, random: &randomB)
        #expect(capped.objects.count == 24 && capped.nextObjectId == 24)
        #expect(open.objects.count == 1)
        #expect(randomA == randomB)
    }

    @Test func aHazardHitCostsOneLifeAndStartsInvulnerability() {
        var game = run(with: [hazard(0, at: Vec2(4.5, 2.2))])
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.lives == 2)
        #expect(game.player.invulnerableSteps == 89)
        #expect(game.objects.isEmpty)
        #expect(game.events == [CollisionEvent(step: 0, objectId: 0, kind: .hit)] && game.eventCount == 1)
        advance(&game, &random, steps: 89)
        #expect(game.player.invulnerableSteps == 0)
        #expect(game.lives == 2 && !game.over)
    }

    @Test func anInvulnerableContactPassesWithoutEffect() {
        var game = run(with: [hazard(0, at: Vec2(4.5, 1.5))])
        game.player.invulnerableSteps = 50
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.lives == 3 && game.events.isEmpty && game.eventCount == 0)
        #expect(game.objects.count == 1 && game.objects[0].position.y < 1.5)
        #expect(game.player.invulnerableSteps == 49)
    }

    @Test func anOrbPickupAddsTen() {
        var game = run(with: [orb(0, at: Vec2(4.6, 1.9))])
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.score == 10 && game.lives == 3)
        #expect(game.objects.isEmpty)
        #expect(game.events == [CollisionEvent(step: 0, objectId: 0, kind: .pickup)])
    }

    @Test func twoContactsInOneStepResolveInIdOrder() {
        var game = run(with: [orb(0, at: Vec2(4.5, 1.6)), hazard(1, at: Vec2(4.4, 1.5)),
                              hazard(2, at: Vec2(4.6, 1.5)), orb(3, at: Vec2(4.5, 1.4))])
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.events == [CollisionEvent(step: 0, objectId: 0, kind: .pickup),
                                CollisionEvent(step: 0, objectId: 1, kind: .hit),
                                CollisionEvent(step: 0, objectId: 3, kind: .pickup)])
        #expect(game.score == 20 && game.lives == 2)
        #expect(game.objects.map(\.id) == [2])   // the second hazard passed during invulnerability
    }

    @Test func aFastCircleCrossingThePlayerInOneStepIsCaught() {
        // 2 units per step, more than twice the summed radii 0.35 + 0.4 = 0.75: it starts 1.0 above the player and
        // ends 1.0 below it, overlapping at neither end.
        var fast = FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(4.5, 2.5),
                                 velocity: Vec2(0, -120), radius: 0.35)
        var game = run(with: [fast])
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.lives == 2 && game.events.map(\.kind) == [.hit])
        // The same object moving sideways past the player's line misses.
        fast.position = Vec2(4.5, 3.0); fast.velocity = Vec2(120, 0)
        game = run(with: [fast])
        advance(&game, &random, steps: 1)
        #expect(game.lives == 3 && game.events.isEmpty)
    }

    @Test func capsulesHitByEndOfStepOverlap() {
        let bar = { (y: Double) in
            FallingObject(id: 0, contentId: "bar", kind: .hazard, position: Vec2(5.3, y), velocity: Vec2(0, -5),
                          radius: 0.2, halfLength: 0.8)
        }
        var game = run(with: [bar(2.05)])   // ends at y ≈ 1.967: 0.467 from the player < 0.6
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.lives == 2 && game.events.map(\.kind) == [.hit])
        game = run(with: [bar(2.2)])        // ends at y ≈ 2.117: 0.617 from the player > 0.6
        advance(&game, &random, steps: 1)
        #expect(game.lives == 3 && game.events.isEmpty && game.objects.count == 1)
    }

    @Test func theCapsuleSpeedBoundHoldsForTheCatalogAtTheDifficultyCeiling() throws {
        let ceiling = Difficulty.ceiling.fallSpeed.upperBound
        for wave in 1...40 { #expect(Difficulty(wave: wave).fallSpeed.upperBound <= ceiling) }
        let maxFallPerStep = ceiling * GameSimulation.step
        #expect(ceiling <= 5 && GameSimulation.fallSpeedRange.upperBound <= 5)
        for item in catalog.items where item.shape == .bar {
            #expect(maxFallPerStep < item.radiusRange.min + PlayerState.hitRadius, "\(item.id)")
            #expect(item.radiusRange.min + PlayerState.hitRadius >= 0.6)
        }
        #expect(!catalog.hazards.filter { $0.shape == .bar }.isEmpty)
        #expect(maxFallPerStep < 0.6)
        #expect(PlayerState.maxSpeed * GameSimulation.step < 0.6)
    }

    @Test func objectsBelowTheFieldAreRemoved() {
        var game = run(with: [orb(0, at: Vec2(8, -0.95)), hazard(1, at: Vec2(1, -0.5))])
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.objects.map(\.id) == [1])
        #expect(game.events.isEmpty && game.score == 0)
    }

    @Test func gameOverStopsTheRun() {
        var game = run(with: [hazard(0, at: Vec2(4.5, 1.5))])
        game.lives = 1
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.lives == 0 && game.over)
        let stopped = game, generator = random
        advance(&game, &random, steps: 200)
        #expect(game == stopped && random == generator)
    }

    @Test func pauseStopsTheRun() {
        var game = run(with: [orb(0, at: Vec2(3, 8))])
        game.paused = true
        let held = game
        var random = SeededRandom(seed: 1)
        let generator = random
        advance(&game, &random, steps: 100)
        #expect(game == held && random == generator)
        game.paused = false
        advance(&game, &random, steps: 1)
        #expect(game.step == 1)
    }

    @Test func theScoreStopsAtTheMaximum() {
        var game = run(with: [orb(0, at: Vec2(4.5, 1.5))])
        game.score = 9_999_995
        var random = SeededRandom(seed: 1)
        advance(&game, &random, steps: 1)
        #expect(game.score == 9_999_999)
        game.objects = [orb(1, at: Vec2(4.5, 1.5))]
        game.nextObjectId = 2
        advance(&game, &random, steps: 1)
        #expect(game.score == 9_999_999 && game.eventCount == 2)
        #expect(game.validate().isEmpty)
    }

    @Test func aNonFiniteSteeringValueIsIgnored() {
        var game = GameRun.new()
        GameSimulation.steer(&game, value: 0.5)
        for value in [Double.nan, .infinity, -.infinity] {
            GameSimulation.steer(&game, value: value)
            #expect(game.steering == 0.5)
        }
        GameSimulation.steer(&game, value: 3)
        #expect(game.steering == 1)
        GameSimulation.steer(&game, value: -2)
        #expect(game.steering == -1)
    }

    @Test func survivalAddsOnePointPerSecondOfPlayOnly() {
        let empty = ArcadeCatalog(items: [])
        var game = GameRun.new()
        var random = SeededRandom(seed: 2)
        advance(&game, &random, steps: 59, catalog: empty)
        #expect(game.score == 0)
        advance(&game, &random, steps: 1, catalog: empty)
        #expect(game.score == 1)
        advance(&game, &random, steps: 540, catalog: empty)
        #expect(game.score == 10 && game.step == 600 && game.wave == 2)
        game.paused = true
        advance(&game, &random, steps: 600, catalog: empty)
        #expect(game.score == 10 && game.step == 600)
        game.paused = false
        game.lives = 0; game.over = true
        advance(&game, &random, steps: 600, catalog: empty)
        #expect(game.score == 10 && game.step == 600)
        game.lives = 1; game.over = false; game.score = 9_999_999
        advance(&game, &random, steps: 60, catalog: empty)
        #expect(game.score == 9_999_999 && game.validate().isEmpty)
    }

    @Test func anOrbInALaterWaveIsWorthItsValueTimesTheMultiplier() {
        var game = GameRun.new()
        game.wave = 5; game.patternId = "orb-trail"; game.patternCursor = 2
        var random = SeededRandom(seed: 6)
        advance(&game, &random, steps: 31)
        let orb = game.objects.first { $0.kind == .orb }
        #expect(game.objects.count == 1)
        #expect(Difficulty(wave: 5).orbMultiplier == 3)
        #expect(orb?.value == 30 && orb?.position.x == Lanes.centre(2))
        // Collected: the score rises by 30 (the survival point at step 60 is not reached).
        var pickup = run(with: [FallingObject(id: 0, contentId: "glow-orb", kind: .orb, position: Vec2(4.5, 1.6),
                                              velocity: Vec2(0, -4), radius: 0.25, value: orb?.value ?? 0)])
        pickup.wave = 5
        advance(&pickup, &random, steps: 1)
        #expect(pickup.score == 30 && pickup.events.map(\.kind) == [.pickup])
    }
}
