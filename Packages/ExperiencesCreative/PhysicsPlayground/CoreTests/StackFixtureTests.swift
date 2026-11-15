// StackFixtureTests — feature 083 (A11-P02) T-A11-203 (FR-A11-203, FR-A11-211; clarifications 2 and 3; research D2,
// D3, D5; SC-A11-202, 203). Host-free and short:
// - Resting stack (fixture 11): five wood boxes 0.5 m wide stacked on the floor at x = 5 m, Earth gravity and low drag,
//   1,200 ticks (10 s) with the warm-started solver: the top box drifts less than 2 cm sideways and no box sinks more
//   than 1 cm below its starting (resting) height; the stack stays standing (every box within 0.1 rad of upright).
//   Measured on the host (2026-11-15): the top box's sideways offset peaks at 1.38 mm while the stack settles in the
//   first ticks and is 0.770 mm at both 5 s and 10 s (change 4.4e-8 m over the last 5 s, about 9e-9 m/s); the deepest
//   sink is 1.38 mm (settling into the 5 mm solver slop) and the top box's sink changes by 1.6e-9 m over the last 5 s.
//   Bound for longer runs (arithmetic, no long run executed): drift(t) ≤ drift(10 s) + rate·(t − 10 s); with the
//   asserted rate limit 1e-6 m/s, one hour adds at most 3.6 mm, so the top box stays within 2 cm for at least
//   (0.02 − 0.0008) / 1e-6 ≈ 19,000 s ≈ 5.3 h; the sink obeys the same limit and stays under 1 cm for over 2 h.
// - The contact cache: it is filled after a tick of the stack, sorted by (body id A, body id B, point index), and
//   restoring a saved world with its cache continues to the identical world.
// - Broad phase (fixture 16): a seeded starting scene with twelve drops run 600 ticks with the broad phase gives the
//   identical encoded world as the reference that passes every pair i < j to contact generation.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct StackFixtureTests {
    private let catalog = MaterialCatalog.bundled

    /// Five wood boxes (half-size 0.25 m) stacked on the floor at x = 5 m, touching, at rest.
    private func stack() -> PhysicsWorld {
        let bodies = (0..<5).map { index in
            PhysicsBody(id: index, shape: .box(halfExtents: Vec2(0.25, 0.25)), materialId: "wood",
                        position: Vec2(5, 0.25 + 0.5 * Double(index)))
        }
        return PhysicsWorld(bodies: bodies)
    }

    @Test func aFiveBoxStackStaysStandingForTenSeconds() {
        var world = stack()
        #expect(world.validate(catalog: catalog).isEmpty)
        let start = world.bodies
        var drift = 0.0, sink = 0.0, tilt = 0.0, driftAtFiveSeconds = 0.0, sinkAtFiveSeconds = 0.0
        for tick in 1...1_200 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            drift = max(drift, abs(world.bodies[4].position.x - start[4].position.x))
            for (body, initial) in zip(world.bodies, start) {
                sink = max(sink, initial.position.y - body.position.y)
                tilt = max(tilt, abs(body.angle))
            }
            if tick == 600 {
                driftAtFiveSeconds = abs(world.bodies[4].position.x - start[4].position.x)
                sinkAtFiveSeconds = start[4].position.y - world.bodies[4].position.y
            }
        }
        let finalDrift = abs(world.bodies[4].position.x - start[4].position.x)
        let finalSink = start[4].position.y - world.bodies[4].position.y
        #expect(drift < 0.02)
        #expect(sink < 0.01)
        #expect(tilt < 0.1)
        // Per-second rates over the second half bound longer runs (see the file header).
        let driftRate = abs(finalDrift - driftAtFiveSeconds) / 5, sinkRate = abs(finalSink - sinkAtFiveSeconds) / 5
        #expect(driftRate < 1e-6 && sinkRate < 1e-6)
        #expect(finalDrift + driftRate * 3_600 < 0.02)
        #expect(finalSink + sinkRate * 3_600 < 0.01)
        #expect(world.validate(catalog: catalog).isEmpty)
    }

    @Test func theContactCacheIsFilledSortedAndRestoredExactly() throws {
        var world = stack()
        #expect(world.contactCache.isEmpty)
        for _ in 0..<60 { WorldSimulation.tick(&world, catalog: catalog) }
        let cache = world.contactCache
        // Four box–box contacts and the floor contact, two points each.
        #expect(cache.count == 10)
        #expect(cache.filter { $0.bodyB == ContactCacheEntry.wallMarker(0) }.count == 2)
        #expect(cache.allSatisfy { $0.isFinite && $0.normalImpulse >= 0 && (0...1).contains($0.pointIndex) })
        let keys = cache.map { [$0.bodyA, $0.bodyB, $0.pointIndex] }
        #expect(zip(keys, keys.dropFirst()).allSatisfy { $0.lexicographicallyPrecedes($1) })
        // The floor carries the weight of five boxes: Σ normal impulse ≈ 5·m·g·dt.
        let floor = cache.filter { $0.bodyB == ContactCacheEntry.wallMarker(0) }.map(\.normalImpulse).reduce(0, +)
        let weightImpulse = 5 * 0.6 * 0.25 * 9.81 / 120
        #expect(abs(floor - weightImpulse) < 0.05 * weightImpulse)
        #expect(world.validate(catalog: catalog).isEmpty)

        var whole = world
        for _ in 0..<120 { WorldSimulation.tick(&whole, catalog: catalog) }
        var restored = try PhysicsWorld.decode(world.encoded())
        #expect(restored == world)
        for _ in 0..<120 { WorldSimulation.tick(&restored, catalog: catalog) }
        #expect(restored.encoded() == whole.encoded())
    }

    @Test func theBroadPhaseGivesTheSameWorldAsEveryPair() {
        var random = SeededRandom(seed: 2_026)
        var start = StartingScene.make(random: &random, catalog: catalog)
        for drop in 0..<12 {
            #expect(WorldSimulation.drop(&start, kind: drop.isMultiple(of: 2) ? .circle : .box, random: &random,
                                         catalog: catalog))
        }
        var broad = start, every = start
        var contactTicks = 0
        for _ in 0..<600 {
            #expect(WorldSimulation.tick(&broad, catalog: catalog, pairing: .broadPhase))
            #expect(WorldSimulation.tick(&every, catalog: catalog, pairing: .allPairs))
            if broad.contactCache.contains(where: { $0.bodyB >= 0 }) { contactTicks += 1 }
        }
        #expect(broad.encoded() == every.encoded() && !broad.encoded().isEmpty)
        #expect(contactTicks > 100)
        #expect(broad.validate(catalog: catalog).isEmpty)
    }
}
