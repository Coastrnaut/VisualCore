// EmitterShapeTests — feature 033 A04-P01 T-A04-102 (G-EMITTERS; FR-A04-101, FR-A04-102; SC-A04-101, SC-A04-102;
// contract C1–C4).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private let dt = 1.0 / 120

/// Emits `count` particles from `emitter` in one step (lifetime long enough that none expire) and returns their positions.
private func spawnPositions(_ emitter: Emitter, count: Int, seed: UInt64 = 7) -> [Vec2] {
    var ps = ParticleSystem(capacity: count, seed: seed)
    var e = emitter
    e.rate = 0; e.lifetime = 100...100
    ps.emitters = [e]
    ps.burst(count)
    ps.step(dt)   // integration runs before emission, so new particles are still where they spawned
    return (0..<ps.aliveCount).map { Vec2(ps.px[$0], ps.py[$0]) }
}

@Test func pointSpawnsExactlyAtThePosition() {
    let p = spawnPositions(Emitter(position: Vec2(12, -3)), count: 1_000)
    #expect(p.count == 1_000)
    #expect(p.allSatisfy { $0 == Vec2(12, -3) })
}

@Test func ringSpawnsOnTheCircle() {
    // C2 / SC-A04-101: 10,000 spawns, distance to the center equals the radius within 1e-9.
    let c = Vec2(10, 20)
    let p = spawnPositions(Emitter(position: c, shape: .ring(radius: 200)), count: 10_000)
    #expect(p.count == 10_000)
    let worst = p.map { abs(($0 - c).length - 200) }.max()!
    #expect(worst <= 1e-9, "worst \(worst)")
    // Spread around the whole circle: every quadrant is used.
    let quadrants = Set(p.map { ($0.x >= c.x ? 1 : 0) + ($0.y >= c.y ? 2 : 0) })
    #expect(quadrants.count == 4)
}

@Test func lineSpawnsOnTheSegment() {
    // C2 / SC-A04-101: on the segment (perpendicular distance ≤ 1e-9, within the half length).
    let c = Vec2(-50, 5), angle = 0.3, h = 400.0
    let p = spawnPositions(Emitter(position: c, shape: .line(halfLength: h, angle: angle)), count: 10_000)
    let dir = Vec2(cos(angle), sin(angle)), normal = Vec2(-sin(angle), cos(angle))
    var worstPerp = 0.0, worstAlong = 0.0, minAlong = Double.infinity, maxAlong = -Double.infinity
    for q in p {
        let d = q - c
        let along = d.x * dir.x + d.y * dir.y
        worstPerp = max(worstPerp, abs(d.x * normal.x + d.y * normal.y))
        worstAlong = max(worstAlong, abs(along) - h)
        minAlong = min(minAlong, along); maxAlong = max(maxAlong, along)
    }
    #expect(worstPerp <= 1e-9, "perpendicular \(worstPerp)")
    #expect(worstAlong <= 1e-9, "beyond the ends by \(worstAlong)")
    #expect(minAlong < -0.9 * h && maxAlong > 0.9 * h, "uses the whole segment")
}

@Test func degenerateShapesBehaveAsAPoint() {
    let c = Vec2(3, 4)
    #expect(spawnPositions(Emitter(position: c, shape: .ring(radius: 0)), count: 100).allSatisfy { ($0 - c).length <= 1e-12 })
    #expect(spawnPositions(Emitter(position: c, shape: .line(halfLength: 0, angle: 1)), count: 100).allSatisfy { ($0 - c).length <= 1e-12 })
    #expect(spawnPositions(Emitter(position: c, shape: .ring(radius: -5)), count: 100).allSatisfy { ($0 - c).length <= 1e-12 })
}

@Test func liveNeverExceedsCapacityAndDropsAreExact() {
    // C3 / SC-A04-102: demand 600× the capacity; bursts every 1/60 s over 1 s at 1/120 s steps = 60 bursts of 1,000.
    var ps = ParticleSystem(capacity: 100, seed: 9)
    ps.emitters = [Emitter(rate: 0, lifetime: 60...60, burst: EmitterBurst(count: 1_000, interval: 1.0 / 60))]
    for _ in 0..<120 {
        ps.step(dt)
        #expect(ps.aliveCount <= ps.capacity)
    }
    #expect(ps.aliveCount == 100)
    #expect(ps.droppedCount == 60 * 1_000 - 100)
}

@Test func burstCadenceFollowsTheInterval() {
    // First burst on the first step, then every `interval` seconds of simulated time.
    var ps = ParticleSystem(capacity: 10_000, seed: 4)
    ps.emitters = [Emitter(rate: 0, lifetime: 60...60, burst: EmitterBurst(count: 10, interval: 0.5))]
    ps.step(dt)
    #expect(ps.aliveCount == 10)
    for _ in 1..<60 { ps.step(dt) }        // up to 59/120 s: no second burst yet
    #expect(ps.aliveCount == 10)
    ps.step(dt)                             // 60/120 s = 0.5 s
    #expect(ps.aliveCount == 20)
    for _ in 0..<60 { ps.step(dt) }
    #expect(ps.aliveCount == 30)
}

@Test func aLongStepBurstsAtMostOnce() {
    var ps = ParticleSystem(capacity: 10_000, seed: 4)
    ps.emitters = [Emitter(rate: 0, lifetime: 600...600, burst: EmitterBurst(count: 10, interval: 0.5))]
    ps.step(dt)
    ps.step(10)                             // twenty intervals in one step: one burst only
    #expect(ps.aliveCount == 20)
}

@Test func stoppedEmittersDoNotBurst() {
    var ps = ParticleSystem(capacity: 1_000, seed: 4)
    var e = Emitter(rate: 0, lifetime: 60...60, burst: EmitterBurst(count: 10, interval: 0.1))
    e.isEmitting = false
    ps.emitters = [e]
    for _ in 0..<120 { ps.step(dt) }
    #expect(ps.aliveCount == 0)
}

@Test func nonPositiveIntervalsAreClampedToTheMinimum() {
    #expect(EmitterBurst(count: 10, interval: 0).clamped().interval == 1.0 / 60)
    #expect(EmitterBurst(count: 10, interval: -3).clamped().interval == 1.0 / 60)
    #expect(EmitterBurst(count: 10, interval: .nan).clamped().interval == 1)
    #expect(EmitterBurst(count: 0, interval: 1).clamped().count == 1)
    #expect(EmitterBurst(count: 1_000_000, interval: 1).clamped().count == 5_000)
    var ps = ParticleSystem(capacity: 100_000, seed: 4)
    ps.emitters = [Emitter(rate: 0, lifetime: 60...60, burst: EmitterBurst(count: 1, interval: 0))]
    for _ in 0..<120 { ps.step(dt) }        // at most one burst per step, never a storm
    #expect(ps.aliveCount <= 120)
}

@Test func validEmittersAreUnchangedByClamping() {
    // C1: in-range values are returned unchanged, so earlier seeded results stay bit-identical.
    let valid = [Emitter(), Emitter(position: Vec2(0, -252), rate: 2_000, lifetime: 1.4...2.8, speed: 15...625, direction: .pi / 2,
                                    spread: 3.14159, startSize: 24, endSize: 4.8, startColor: Vec4(0.2, 0.4, 1, 1),
                                    endColor: Vec4(0, 0, 0, 0)),
                 Emitter(rate: 0, lifetime: 100...100, speed: 10...50),
                 Emitter(shape: .ring(radius: 200), burst: EmitterBurst(count: 400, interval: 1.5))]
    for e in valid { #expect(e.clamped() == e) }
}

@Test func clampingMakesAnyEmitterFiniteAndInRange() {
    // C4: fuzzed values, including NaN, infinities and huge or negative numbers.
    let odd: [Double] = [.nan, .infinity, -.infinity, -1e300, -5, 0, 1e-300, 3, 1e300]
    var r = SeededRandom(seed: 99)
    for _ in 0..<2_000 {
        func pick() -> Double { odd[r.int(0...(odd.count - 1))] }
        // Ranges cannot hold NaN (ClosedRange's precondition), but may hold infinities and huge values.
        func range() -> ClosedRange<Double> {
            let a = odd[r.int(1...(odd.count - 1))], b = odd[r.int(1...(odd.count - 1))]
            return min(a, b)...max(a, b)
        }
        let shape: EmitterShape = [.point, .line(halfLength: pick(), angle: pick()), .ring(radius: pick())][r.int(0...2)]
        let e = Emitter(position: Vec2(pick(), pick()), rate: pick(), lifetime: range(),
                        speed: range(), direction: pick(), spread: pick(), startSize: pick(), endSize: pick(),
                        startColor: Vec4(pick(), pick(), pick(), pick()), endColor: Vec4(pick(), 0, 0, 1),
                        shape: shape, burst: EmitterBurst(count: r.int(-10...10_000), interval: pick())).clamped()
        let values = [e.position.x, e.position.y, e.rate, e.lifetime.lowerBound, e.lifetime.upperBound, e.speed.lowerBound,
                      e.speed.upperBound, e.direction, e.spread, e.startSize, e.endSize,
                      e.startColor.x, e.startColor.y, e.startColor.z, e.startColor.w, e.endColor.x, e.burst!.interval]
        #expect(values.allSatisfy { $0.isFinite })
        #expect(Emitter.rateRange.contains(e.rate))
        #expect(Emitter.lifetimeRange.contains(e.lifetime.lowerBound) && Emitter.lifetimeRange.contains(e.lifetime.upperBound))
        #expect(Emitter.speedRange.contains(e.speed.upperBound) && Emitter.sizeRange.contains(e.startSize))
        #expect(Emitter.spreadRange.contains(e.spread))
        #expect(EmitterBurst.countRange.contains(e.burst!.count) && EmitterBurst.intervalRange.contains(e.burst!.interval))
        switch e.shape {
        case .point: break
        case .line(let h, let a): #expect(EmitterShape.extentRange.contains(h) && a.isFinite)
        case .ring(let radius): #expect(EmitterShape.extentRange.contains(radius))
        }
    }
}

@Test func clampedEmittersNeverCreateNonFiniteParticles() {
    var ps = ParticleSystem(capacity: 5_000, seed: 12)
    ps.emitters = [Emitter(position: Vec2(.nan, 3), rate: 1e300, lifetime: 1...1, speed: 0...1e300, direction: .infinity,
                           shape: .ring(radius: .infinity))]
    for _ in 0..<120 { ps.step(dt) }
    #expect(ps.aliveCount > 0)
    #expect(ps.instances().allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite && $0.size.isFinite })
    #expect(ps.nanRemoved == 0)
}

@Test func shapesAndBurstsAreCodable() throws {
    let e = [EmitterShape.point, .line(halfLength: 4, angle: 0.5), .ring(radius: 9)]
    let data = try JSONEncoder().encode(e)
    let shapes = try JSONDecoder().decode([EmitterShape].self, from: data)
    #expect(shapes == e)
    let b = EmitterBurst(count: 3, interval: 0.25)
    let decoded = try JSONDecoder().decode(EmitterBurst.self, from: try JSONEncoder().encode(b))
    #expect(decoded == b)
}

@Test func radialRingsEmitOutward() {
    // Feature 033 (Halo): with `radial`, direction 0 and no spread, every velocity points away from the center.
    var ps = ParticleSystem(capacity: 1_000, seed: 21)
    ps.emitters = [Emitter(position: Vec2(5, 5), rate: 0, lifetime: 9...9, speed: 10...10, direction: 0, spread: 0,
                           shape: .ring(radius: 100), radial: true)]
    ps.burst(1_000)
    ps.step(dt)
    for i in 0..<ps.aliveCount {
        let out = Vec2(ps.px[i] - 5, ps.py[i] - 5) / 100
        let v = Vec2(ps.vx[i], ps.vy[i]) / 10
        #expect(abs(out.x * v.x + out.y * v.y - 1) < 1e-9)
    }
    // Without `radial` the direction stays absolute.
    var flat = ParticleSystem(capacity: 10, seed: 21)
    flat.emitters = [Emitter(rate: 0, lifetime: 9...9, speed: 10...10, direction: 0, spread: 0, shape: .ring(radius: 100))]
    flat.burst(10); flat.step(dt)
    #expect((0..<flat.aliveCount).allSatisfy { abs(flat.vx[$0] - 10) < 1e-12 && abs(flat.vy[$0]) < 1e-12 })
}
