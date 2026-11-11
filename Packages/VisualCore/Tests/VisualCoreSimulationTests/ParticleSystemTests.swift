// ParticleSystemTests — feature 006 T-F512 (FR-F507, FR-F511, FR-F512; US3 AC1/AC2; SC-F502, SC-F504).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private let dt = 1.0 / 120

@Test func steadyEmissionMatchesAnalyticCount() {
    // AC1 / SC-F504: 100/s with 1 s life, run 2 s → 99…101 alive.
    var ps = ParticleSystem(seed: 1)
    ps.emitters = [Emitter(rate: 100, lifetime: 1...1)]
    for _ in 0..<240 { ps.step(dt) }
    #expect((99...101).contains(ps.aliveCount), "alive \(ps.aliveCount)")
    #expect(ps.droppedCount == 0)
}

@Test func capacityIsNeverExceeded() {
    // AC2: pool of 10,000; emission beyond it is dropped and counted.
    var ps = ParticleSystem(seed: 2)
    ps.emitters = [Emitter(rate: 0, lifetime: 10...10)]
    ps.burst(12_345)
    ps.step(dt)
    #expect(ps.aliveCount == 10_000)
    #expect(ps.droppedCount == 2_345)
    #expect(ParticleSystem(capacity: 1_000_000).capacity == 100_000)
    #expect(ParticleSystem(capacity: 0).capacity == 1)
}

@Test func forcesMoveParticles() {
    var ps = ParticleSystem(seed: 3)
    ps.emitters = [Emitter(rate: 0, lifetime: 10...10, speed: 0...0)]
    ps.forces = [.gravity(Vec2(0, -10))]
    ps.burst(1); ps.step(dt)
    for _ in 0..<120 { ps.step(dt) }   // 1 s of free fall
    let y = ps.instances()[0].position.y
    #expect(abs(y - (-5)) < 0.1, "≈ -½ g t² (semi-implicit Euler), got \(y)")

    var drag = ParticleSystem(seed: 3)
    drag.emitters = [Emitter(rate: 0, lifetime: 10...10, speed: 100...100, direction: 0, spread: 0)]
    drag.forces = [.drag(2)]
    drag.burst(1); drag.step(dt)
    for _ in 0..<120 { drag.step(dt) }
    #expect(drag.vx[0] < 100 * exp(-2) * 1.05 && drag.vx[0] > 100 * exp(-2) * 0.95)

    var pull = ParticleSystem(seed: 3)
    pull.emitters = [Emitter(position: Vec2(10, 0), rate: 0, lifetime: 10...10, speed: 0...0)]
    pull.forces = [.attractor(point: .zero, strength: 50, radius: 20)]
    pull.burst(1); pull.step(dt); pull.step(dt)
    #expect(pull.vx[0] < 0, "moves toward the attractor")
}

@Test func nanParticlesAreRemovedAndCounted() {
    var ps = ParticleSystem(seed: 4)
    ps.emitters = [Emitter(rate: 0, lifetime: 10...10)]
    ps.burst(5); ps.step(dt)
    ps.vx[2] = .nan
    ps.step(dt)
    #expect(ps.aliveCount == 4)
    #expect(ps.nanRemoved == 1)
    #expect(ps.instances().allSatisfy { $0.position.isFinite })
}

@Test func sizeAndColorInterpolateOverLife() {
    var ps = ParticleSystem(seed: 5)
    ps.emitters = [Emitter(rate: 0, lifetime: 1...1, speed: 0...0, startSize: 10, endSize: 0,
                           startColor: Vec4(1, 0, 0, 1), endColor: Vec4(0, 0, 1, 0))]
    ps.burst(1); ps.step(dt)
    for _ in 0..<60 { ps.step(dt) }   // half of its life
    let p = ps.instances()[0]
    #expect(abs(p.size - 5) < 1e-9)
    #expect(abs(p.color.x - 0.5) < 1e-9 && abs(p.color.z - 0.5) < 1e-9)
}

private func run(seed: UInt64, frames: Int, frameTime: Double) -> UInt64 {
    var ps = ParticleSystem(seed: seed)
    ps.emitters = [Emitter(rate: 250, lifetime: 0.5...2, speed: 10...200)]
    ps.forces = [.gravity(Vec2(0, -98)), .drag(0.3), .attractor(point: Vec2(30, 30), strength: 40, radius: 80)]
    var clock = FixedStepClock()
    for _ in 0..<frames { for _ in 0..<clock.advance(by: frameTime) { ps.step(clock.step) } }
    return ps.checksum()
}

@Test func tenThousandStepsAreDeterministicAndRateIndependent() {
    // SC-F502: same seed twice → same checksum; 60 Hz vs 120 Hz feeding → same state.
    let a = run(seed: 9, frames: 10_000, frameTime: 1.0 / 120)
    #expect(a == run(seed: 9, frames: 10_000, frameTime: 1.0 / 120))
    #expect(a == run(seed: 9, frames: 5_000, frameTime: 1.0 / 60))
    #expect(a != run(seed: 10, frames: 10_000, frameTime: 1.0 / 120))
}

@Test func invalidStepsAndEmittersAreIgnored() {
    var ps = ParticleSystem(seed: 6)
    ps.emitters = [Emitter(rate: .nan), Emitter(rate: -5)]
    ps.step(.nan); ps.step(-1); ps.step(dt)
    #expect(ps.aliveCount == 0)
    ps.burst(3, from: 7)
    ps.step(dt)
    #expect(ps.aliveCount == 0)
}
