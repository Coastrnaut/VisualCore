// PlacedForceTests — feature 034 A04-P02 T-A04-206 (FR-A04-204; US1 AC1–AC4; spec clarification 3; edge cases).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import ParticleUniverseCore

@Test func defaultsPerKindScaleWithStrength() {
    let p = Vec2(100, -50)
    #expect(PlacedForce(kind: .attractor, position: p).particleForce == .attractor(point: p, strength: 300, radius: 300))
    #expect(PlacedForce(kind: .repulsor, position: p, strength: 2).particleForce == .repulsor(point: p, strength: 800, radius: 250))
    #expect(PlacedForce(kind: .gravityWell, position: p, strength: 0.5).particleForce
            == .gravityWell(point: p, strength: 1_000_000, softening: 40))
    #expect(PlacedForce(kind: .vortex, position: p).particleForce == .vortex(point: p, strength: 250, radius: 300))
    let wind = PlacedForce(kind: .wind, position: Vec2(0, 300)).particleForce
    #expect(wind == .wind(velocity: Vec2(0, 120), rate: 0.8), "wind blows from the center toward the force")
    #expect(PlacedForce(kind: .wind, position: .zero, strength: 2).particleForce == .wind(velocity: Vec2(240, 0), rate: 0.8),
            "exactly at the center the wind blows toward +x")
    // Every default is already inside VisualCore's clamp ranges.
    for kind in PlacedForceKind.allCases {
        for s in [0.1, 1, 2] {
            let f = PlacedForce(kind: kind, position: p, strength: s).particleForce
            #expect(f.clamped() == f, "\(kind) ×\(s)")
        }
    }
}

@Test func positionAndStrengthAreClamped() {
    var f = PlacedForce(kind: .attractor, position: Vec2(900, -2_000), strength: 7)
    #expect(f.position == Vec2(500, -500) && f.strength == 2)
    #expect(PlacedForce(kind: .vortex, position: Vec2(.nan, 3), strength: .infinity).position == Vec2(0, 3))
    #expect(PlacedForce(kind: .vortex, position: .zero, strength: .nan).strength == 1)
    #expect(PlacedForce(kind: .vortex, position: .zero, strength: 0).strength == 0.1)
    f.move(to: Vec2(.nan, 0)); #expect(f.position == Vec2(500, -500), "a non-finite move is ignored")
    f.move(to: Vec2(10, 20)); #expect(f.position == Vec2(10, 20))
    f.nudge(by: Vec2(600, 0)); #expect(f.position == Vec2(500, 20))
    f.setStrength(.nan); #expect(f.strength == 2)
    f.setStrength(0.5); #expect(f.strength == 0.5)
    f.kind = .repulsor; #expect(f.position == Vec2(500, 20), "changing the kind keeps the position")
}

@Test func placedForceOccupiesSlotZeroAndCanBeRemoved() throws {
    var sim = try SceneSimulation(scene: .single(.fountain))
    let family = sim.activeForces
    sim.setPlacedForce(PlacedForce(kind: .attractor, position: Vec2(0, 100)))
    #expect(sim.activeForces.count == family.count + 1)
    #expect(sim.activeForces.first == .attractor(point: Vec2(0, 100), strength: 300, radius: 300))
    sim.setPlacedForce(PlacedForce(kind: .vortex, position: Vec2(0, 100)))
    #expect(sim.activeForces.count == family.count + 1, "replaced, not added")
    sim.setPlacedForce(nil)
    #expect(sim.activeForces == family, "removing leaves the family's own forces only")
    #expect(sim.placedForce == nil)
}

@Test func moveAttractorStillAddressesSceneForcesWithAPlacedForce() throws {
    let scene = ParticleScene(emitters: [SceneEmitter(family: .halo)], forces: [.attractor(x: 0, y: 0, strength: 100, radius: 50)])
    var sim = try SceneSimulation(scene: scene)
    sim.setPlacedForce(PlacedForce(kind: .repulsor, position: Vec2(200, 0)))
    sim.apply(.moveAttractor(index: 0, x: 7, y: 8))
    #expect(sim.activeForces[1] == .attractor(point: Vec2(7, 8), strength: 100, radius: 50))
    #expect(sim.activeForces[0] == .repulsor(point: Vec2(200, 0), strength: 400, radius: 250))
    sim.apply(.moveAttractor(index: 1, x: 0, y: 0))
    #expect(sim.ignoredCommands == 1)
}

/// Mean distance from `p` of the live particles after `steps` steps of a Halo scene with `force` placed.
private func meanDistance(_ force: PlacedForce?, from p: Vec2, steps: Int = 240) throws -> Double {
    var sim = try SceneSimulation(scene: .single(.halo, seed: 3))
    sim.setPlacedForce(force)
    sim.run(steps: steps)
    let ps = sim.instances().map(\.position)
    return ps.map { $0.distance(to: p) }.reduce(0, +) / Double(max(ps.count, 1))
}

@Test func particlesRespondToEachKind() throws {
    // US1 AC4: attractor and gravity well pull in, repulsor pushes away, wind moves everything one way, vortex turns.
    let c = Vec2.zero   // the Halo ring is centered on the origin
    let unforced = try meanDistance(nil, from: c)
    #expect(try meanDistance(PlacedForce(kind: .attractor, position: c, strength: 2), from: c) < unforced)
    #expect(try meanDistance(PlacedForce(kind: .gravityWell, position: c, strength: 2), from: c) < unforced)
    #expect(try meanDistance(PlacedForce(kind: .repulsor, position: c, strength: 2), from: c) > unforced)
    func meanX(_ f: PlacedForce?) throws -> Double {
        var sim = try SceneSimulation(scene: .single(.halo, seed: 3)); sim.setPlacedForce(f); sim.run(steps: 240)
        let ps = sim.instances(); return ps.map(\.position.x).reduce(0, +) / Double(max(ps.count, 1))
    }
    #expect(try meanX(PlacedForce(kind: .wind, position: Vec2(400, 0), strength: 2)) > (try meanX(nil)) + 20)
    // Forces draw no random numbers and nothing becomes non-finite, so particle i is the same particle in both runs:
    // a counter-clockwise vortex turns positions counter-clockwise (positive cross product).
    func positions(_ f: PlacedForce?) throws -> [Vec2] {
        var sim = try SceneSimulation(scene: .single(.halo, seed: 3)); sim.setPlacedForce(f); sim.run(steps: 120)
        return sim.instances().map(\.position)
    }
    let free = try positions(nil), turned = try positions(PlacedForce(kind: .vortex, position: c, strength: 2))
    #expect(free.count == turned.count && free.count > 100)
    let ccw = zip(free, turned).filter { $0.cross($1) > 0 }.count
    #expect(Double(ccw) > 0.9 * Double(free.count))
}

@Test func newSceneForcesValidateAndRoundTrip() throws {
    let scene = ParticleScene(emitters: [SceneEmitter(family: .fountain)],
                              forces: [.repulsor(x: 1, y: 2, strength: -400, radius: 250), .gravityWell(x: 0, y: 0, strength: 2e6, softening: 40),
                                       .wind(vx: 120, vy: 0, rate: 0.8), .vortex(x: 0, y: 0, strength: 250, radius: 300)])
    try scene.validate()
    let back = try JSONDecoder().decode(ParticleScene.self, from: JSONEncoder().encode(scene))
    #expect(back == scene)
    func bad(_ f: SceneForce) -> Bool {
        do { try ParticleScene(emitters: [SceneEmitter(family: .fountain)], forces: [f]).validate(); return false }
        catch { return error == .invalidForce(0) }
    }
    #expect(bad(.repulsor(x: 0, y: 0, strength: 20_000, radius: 10)))
    #expect(bad(.repulsor(x: 0, y: 0, strength: 1, radius: 0.5)))
    #expect(bad(.vortex(x: 0, y: 0, strength: 1, radius: 3_000)))
    #expect(bad(.gravityWell(x: 0, y: 0, strength: -1, softening: 40)))
    #expect(bad(.gravityWell(x: 0, y: 0, strength: 1, softening: 600)))
    #expect(bad(.wind(vx: 3_000, vy: 0, rate: 1)))
    #expect(bad(.wind(vx: 0, vy: 0, rate: 11)))
}
