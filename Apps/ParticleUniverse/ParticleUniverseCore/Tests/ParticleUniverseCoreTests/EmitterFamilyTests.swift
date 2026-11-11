// EmitterFamilyTests — feature 033 T-A04-105 (FR-A04-101, FR-A04-102, FR-A04-106; US1 AC1–AC3; SC-A04-101, SC-A04-102).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import ParticleUniverseCore

private let dt = 1.0 / 120

/// A system with only `family`'s emitter and forces.
private func system(_ family: EmitterFamily, capacity: Int, seed: UInt64 = 3) -> ParticleSystem {
    var ps = ParticleSystem(capacity: capacity, seed: seed)
    ps.emitters = [family.emitter()]
    ps.forces = family.forces()
    return ps
}

@Test func familiesAreValidAndDescribed() {
    for f in EmitterFamily.allCases {
        #expect(f.emitter().clamped() == f.emitter(), "\(f) is in range, so clamping changes nothing")
        #expect(!f.title.isEmpty && f.spokenDescription.count > 20)
    }
    #expect(EmitterFamily.allCases.map(\.title) == ["Fountain", "Curtain", "Halo", "Firework"])
}

@Test func eachFamilySpawnsOnItsShape() {
    // US1 AC1/AC3: positions of particles born this step lie on the family's shape (tolerance 1e-9).
    for f in EmitterFamily.allCases {
        var ps = system(f, capacity: 20_000)
        ps.step(dt)                                    // first step: spawn only (Firework's first burst)
        let e = f.emitter()
        let born = ps.instances().map(\.position)
        #expect(!born.isEmpty, "\(f) emits on the first step")
        for p in born {
            let d = p - e.position
            switch e.shape {
            case .point: #expect(d.length <= 1e-9)
            case .line(let h, let a):
                #expect(abs(-d.x * sin(a) + d.y * cos(a)) <= 1e-9)
                #expect(abs(d.x * cos(a) + d.y * sin(a)) <= h + 1e-9)
            case .ring(let r): #expect(abs(d.length - r) <= 1e-9)
            }
        }
    }
}

@Test func fireworkEmitsOnlyInBursts() {
    var ps = system(.firework, capacity: 20_000)
    ps.step(dt)
    #expect(ps.aliveCount == 400)
    for _ in 1..<180 { ps.step(dt) }                   // up to 1.49 s: particles live 1–2 s, no second burst yet
    #expect(ps.aliveCount <= 400)
    ps.step(dt)                                        // 1.5 s: the second burst
    #expect(ps.aliveCount >= 400)
}

@Test func liveCountRespectsTheLimitForEveryFamily() {
    // US1 AC2 / SC-A04-102: at the smallest and largest limits the live count never exceeds the limit.
    for f in EmitterFamily.allCases {
        for limit in [100, 20_000] {
            var ps = system(f, capacity: limit)
            for _ in 0..<600 {
                ps.step(dt)
                #expect(ps.aliveCount <= limit)
            }
            if limit == 100 { #expect(ps.droppedCount > 0, "\(f) asks for more than 100") }
        }
    }
}
