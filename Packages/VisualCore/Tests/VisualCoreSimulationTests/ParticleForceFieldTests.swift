// ParticleForceFieldTests — feature 034 A04-P02 T-A04-202 (G-FIELDS; FR-A04-201, FR-A04-202; SC-A04-201, SC-A04-202;
// contract C1–C4; research R1, R2).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private let center = Vec2(37.5, -12.25)

/// One sample of every kind at the clarified sandbox defaults and at the clamp extremes.
private let samples: [ParticleForce] = [
    .attractor(point: center, strength: 300, radius: 300),
    .repulsor(point: center, strength: 400, radius: 250),
    .repulsor(point: center, strength: -10_000, radius: 1),
    .gravityWell(point: center, strength: 2_000_000, softening: 40),
    .gravityWell(point: center, strength: 1e9, softening: 1),
    .wind(velocity: Vec2(120, -40), rate: 0.8),
    .wind(velocity: Vec2(2_000, 0), rate: 10),
    .vortex(point: center, strength: 250, radius: 300),
    .vortex(point: center, strength: -10_000, radius: 2_000),
    .gravity(Vec2(0, -150)),
    .drag(0.8),
]

private func within(_ f: ParticleForce, at p: Vec2, velocity v: Vec2 = .zero) -> Bool {
    let a = f.acceleration(at: p, velocity: v)
    return a.isFinite && a.length <= f.bound(speed: v.length) * (1 + 1e-12) + 1e-300
}

private func pointAndRadius(_ f: ParticleForce) -> (Vec2, Double) {
    switch f {
    case .attractor(let p, _, let r), .repulsor(let p, _, let r), .vortex(let p, _, let r): (p, r)
    case .gravityWell(let p, _, let e): (p, 10 * e)
    default: (center, 500)
    }
}

@Test func everyForceIsFiniteAndBoundedAtItsCenter() {
    // SC-A04-201: the exact center and 1e-12 from it, in several directions.
    for f in samples {
        let (p, _) = pointAndRadius(f)
        #expect(within(f, at: p), "\(f) at the center")
        for k in 0..<8 {
            let a = Double(k) * .pi / 4
            #expect(within(f, at: p + Vec2(cos(a), sin(a)) * 1e-12), "\(f) at 1e-12")
        }
    }
}

@Test func everyForceIsFiniteAndBoundedOnAGrid() {
    // SC-A04-201: a 101 × 101 grid over ±2 radii around each force, with and without a particle velocity.
    var samplesChecked = 0
    for f in samples {
        let (p, r) = pointAndRadius(f)
        for i in 0...100 {
            for j in 0...100 {
                let q = p + Vec2((Double(i) / 50 - 1) * 2 * r, (Double(j) / 50 - 1) * 2 * r)
                #expect(within(f, at: q), "\(f) at \(q)")
                #expect(within(f, at: q, velocity: Vec2(300, -900)), "\(f) at \(q) moving")
                samplesChecked += 2
            }
        }
    }
    #expect(samplesChecked == samples.count * 101 * 101 * 2)
}

@Test func randomAndExtremeParametersStayBounded() {
    // FR-A04-202: any finite (or non-finite) parameters are clamped before use.
    var rng = SeededRandom(seed: 34)
    let wild: [Double] = [0, -0.0, 1e-300, -1e300, 1e300, .infinity, -.infinity, .nan, 5, -5]
    func any() -> Double { rng.double() < 0.5 ? wild[Int(rng.double() * Double(wild.count)) % wild.count] : (rng.double() - 0.5) * 1e6 }
    for _ in 0..<4_000 {
        let p = Vec2(any(), any())
        let raw: [ParticleForce] = [.repulsor(point: p, strength: any(), radius: any()),
                                    .gravityWell(point: p, strength: any(), softening: any()),
                                    .wind(velocity: Vec2(any(), any()), rate: any()),
                                    .vortex(point: p, strength: any(), radius: any()),
                                    .attractor(point: p, strength: any(), radius: any()),
                                    .gravity(Vec2(any(), any())), .drag(any())]
        for f in raw {
            let c = f.clamped()
            #expect(c.clamped() == c, "clamping is idempotent")
            let q = Vec2((rng.double() - 0.5) * 4_000, (rng.double() - 0.5) * 4_000)
            #expect(within(c, at: q, velocity: Vec2(rng.double() * 100, 0)), "\(f)")
            #expect(c.bound(speed: 100).isFinite)
        }
    }
}

@Test func clampRanges() {
    #expect(ParticleForce.repulsor(point: Vec2(.nan, 3), strength: 1e9, radius: 0).clamped()
            == .repulsor(point: Vec2(0, 3), strength: ParticleForce.strengthLimit, radius: 1))
    #expect(ParticleForce.vortex(point: .zero, strength: -1e9, radius: 1e9).clamped()
            == .vortex(point: .zero, strength: -ParticleForce.strengthLimit, radius: 2_000))
    #expect(ParticleForce.gravityWell(point: .zero, strength: -5, softening: 1e4).clamped()
            == .gravityWell(point: .zero, strength: 0, softening: 500))
    #expect(ParticleForce.gravityWell(point: .zero, strength: 1e12, softening: .nan).clamped()
            == .gravityWell(point: .zero, strength: 1e9, softening: 1))
    if case .wind(let w, let rate) = ParticleForce.wind(velocity: Vec2(3_000, 4_000), rate: 50).clamped() {
        #expect(w.length <= 2_000 && w.length > 1_999.999 && abs(w.x / w.y - 0.75) < 1e-12 && rate == 10)
    } else { Issue.record("wind stays wind") }
    if case .wind(let w, _) = ParticleForce.wind(velocity: Vec2(1e300, -1e300), rate: 1).clamped() {
        #expect(w.length <= 2_000 && w.x > 1_400 && w.y < -1_400, "huge winds keep their direction")
    } else { Issue.record("wind stays wind") }
    #expect(ParticleForce.wind(velocity: Vec2(.infinity, 1), rate: -1).clamped() == .wind(velocity: Vec2(0, 1), rate: 0))
    // Existing cases (research R1): valid values pass through bit-for-bit; only non-finite values and negative drag change.
    #expect(ParticleForce.attractor(point: Vec2(1e7, -3), strength: 1e5, radius: 1e7).clamped()
            == .attractor(point: Vec2(1e7, -3), strength: 1e5, radius: 1e7))
    #expect(ParticleForce.gravity(Vec2(0, -9.8)).clamped() == .gravity(Vec2(0, -9.8)))
    #expect(ParticleForce.drag(0.2).clamped() == .drag(0.2))
    #expect(ParticleForce.drag(-1).clamped() == .drag(0))
    #expect(ParticleForce.gravity(Vec2(1e300, -1e300)).clamped() == .gravity(Vec2(1e6, -1e6)))
    #expect(ParticleForce.attractor(point: Vec2(1e300, 0), strength: -1e300, radius: -1).clamped()
            == .attractor(point: Vec2(1e12, 0), strength: -1e6, radius: 0))
    #expect(ParticleForce.gravity(Vec2(.nan, 2)).clamped() == .gravity(Vec2(0, 2)))
}

@Test func forcesPointTheDocumentedWay() {
    let off = center + Vec2(100, 0)   // to the right of the center
    #expect(ParticleForce.attractor(point: center, strength: 300, radius: 300).acceleration(at: off, velocity: .zero).x < 0)
    #expect(ParticleForce.gravityWell(point: center, strength: 2e6, softening: 40).acceleration(at: off, velocity: .zero).x < 0)
    let push = ParticleForce.repulsor(point: center, strength: 400, radius: 250).acceleration(at: off, velocity: .zero)
    #expect(abs(push.x - 400 * (1 - 100.0 / 250)) < 1e-9 && push.y == 0)
    #expect(ParticleForce.repulsor(point: center, strength: 400, radius: 250).acceleration(at: center + Vec2(300, 0), velocity: .zero) == .zero)
    let turn = ParticleForce.vortex(point: center, strength: 250, radius: 300).acceleration(at: off, velocity: .zero)
    #expect(turn.y > 0 && abs(turn.x) < 1e-12, "counter-clockwise: right of the center pushes up")
    let wind = ParticleForce.wind(velocity: Vec2(120, 0), rate: 0.8).acceleration(at: off, velocity: Vec2(20, 10))
    #expect(abs(wind.x - 80) < 1e-12 && abs(wind.y + 8) < 1e-12)
    // Gravity well magnitude follows s·r/(r²+ε²)^{3/2} and peaks at r = ε/√2 with the documented bound.
    let well = ParticleForce.gravityWell(point: .zero, strength: 1_000, softening: 10)
    let peak = well.acceleration(at: Vec2(10 / 2.0.squareRoot(), 0), velocity: .zero).length
    #expect(abs(peak - well.bound(speed: 0)) < 1e-9)
    #expect(well.acceleration(at: .zero, velocity: .zero) == .zero)
}

@Test func centersNeverProduceNonFiniteParticles() {
    // SC-A04-202: 10,000 steps with particles born exactly on each force's center (both defaults and extremes).
    for f in samples where !(f.isGlobal) {
        let (p, _) = pointAndRadius(f)
        var ps = ParticleSystem(capacity: 2_000, seed: 2)
        ps.emitters = [Emitter(position: p, rate: 600, lifetime: 1...3, speed: 0...50)]
        ps.forces = [f]
        ps.burst(200)
        for _ in 0..<10_000 { ps.step(1.0 / 120) }
        #expect(ps.nanRemoved == 0, "\(f)")
        #expect(ps.aliveCount > 0)
        #expect((0..<ps.aliveCount).allSatisfy { ps.px[$0].isFinite && ps.py[$0].isFinite })
    }
}

@Test func windAndWellAreSteppedWithClampedValues() {
    // The system clamps forces once per step: an absurd wind behaves exactly like its clamped form.
    func run(_ f: ParticleForce) -> UInt64 {
        var ps = ParticleSystem(capacity: 500, seed: 9)
        ps.emitters = [Emitter(rate: 300)]
        ps.forces = [f, .gravityWell(point: Vec2(5, 5), strength: 1e30, softening: 0)]
        for _ in 0..<240 { ps.step(1.0 / 120) }
        return ps.checksum()
    }
    let wild = ParticleForce.wind(velocity: Vec2(1e9, 0), rate: 1e9)
    #expect(run(wild) == run(wild.clamped()))
    #expect(run(wild) != run(.wind(velocity: Vec2(-50, 0), rate: 1)))
}

@Test func existingForceAccelerationsMatchThePre034Formula() {
    // C2 / research R1: for gravity, drag and attractor, `acceleration(at:velocity:)` equals the original per-particle
    // arithmetic bit for bit (whole-step identity is proven by replay-v1.json, A01's checksums and VisualCoreBaselines).
    let forces: [ParticleForce] = [.gravity(Vec2(0, -150)), .drag(0.8), .attractor(point: Vec2(30, 40), strength: 300, radius: 300)]
    var rng = SeededRandom(seed: 3)
    for _ in 0..<20_000 {
        let px = (rng.double() - 0.5) * 900, py = (rng.double() - 0.5) * 900
        let vx = (rng.double() - 0.5) * 400, vy = (rng.double() - 0.5) * 400
        var ax = 0.0, ay = 0.0, bx = 0.0, by = 0.0
        for f in forces {
            switch f {
            case .gravity(let g): ax += g.x; ay += g.y
            case .drag(let k): ax -= k * vx; ay -= k * vy
            case .attractor(let p, let s, let r):
                let dx = p.x - px, dy = p.y - py, d = (dx * dx + dy * dy).squareRoot()
                if d > 1e-9 && d <= r { ax += s * dx / d; ay += s * dy / d }
            default: break
            }
            let a = f.acceleration(at: Vec2(px, py), velocity: Vec2(vx, vy))
            bx += a.x; by += a.y
        }
        #expect(ax.bitPattern == bx.bitPattern && ay.bitPattern == by.bitPattern)
    }
}

private extension ParticleForce {
    var isGlobal: Bool {
        switch self { case .gravity, .drag, .wind: true; default: false }
    }
}
