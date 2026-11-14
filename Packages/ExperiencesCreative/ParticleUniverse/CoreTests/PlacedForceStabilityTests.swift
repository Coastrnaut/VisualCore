// PlacedForceStabilityTests — feature 034 A04-P02 T-A04-209 (US2; FR-A04-202; SC-A04-202 at the app level; manual §11
// fixture 4: singularities).
import Testing
import VisualCoreMath
@testable import ParticleUniverseCore

@Test(arguments: PlacedForceKind.allCases)
func emittersOnAForceCenterStayFinite(kind: PlacedForceKind) throws {
    // Every family's emitter sits exactly on the force at strength 2; 2,000 fixed steps (16.7 s of simulation at 1/120 s,
    // over four times the longest family lifetime of 4 s, so every particle alive at the end was born and lived its whole
    // life on the force). Shortened from 10,000 steps under the owner's short-test rule of 2026-11-13: the population is
    // in its steady state after one lifetime, so further steps repeat the same states.
    let center = Vec2(120, -80)
    for family in EmitterFamily.allCases {
        var sim = try SceneSimulation(scene: ParticleScene(seed: 4, emitters: [SceneEmitter(family: family, position: center)]))
        sim.setPlacedForce(PlacedForce(kind: kind, position: center, strength: 2))
        sim.run(steps: 2_000)
        #expect(sim.nonFiniteRemoved == 0, "\(kind) on \(family)")
        #expect(sim.instances().allSatisfy { $0.position.isFinite && $0.size.isFinite })
        #expect(sim.liveCount > 0)
    }
}

// Feature 036 A04-P04 T-A04-415 (US4; SC-A04-405): a saved document whose scene force of each of the 7 kinds and whose
// placed force sit exactly on an emitter is opened (file form decoded, emitters and force rebuilt from the open
// actions, as the adapter's `look.define` commits them) and stays finite for 600 fixed steps.
private let onEmitter = Vec2(-150, 120)

private let sceneForceKinds: [SceneForce] = [
    .gravity(x: 0, y: -300),
    .drag(k: 2),
    .attractor(x: onEmitter.x, y: onEmitter.y, strength: 5_000, radius: 300),
    .repulsor(x: onEmitter.x, y: onEmitter.y, strength: 5_000, radius: 300),
    .gravityWell(x: onEmitter.x, y: onEmitter.y, strength: 1_000_000, softening: 1),
    .wind(vx: 0, vy: 500, rate: 5),
    .vortex(x: onEmitter.x, y: onEmitter.y, strength: 5_000, radius: 300),
]

@Test(arguments: zip(sceneForceKinds.indices, sceneForceKinds))
func forcesOnAnEmitterOfAnOpenedDocumentStayFinite(index: Int, force: SceneForce) throws {
    let placedKind = PlacedForceKind.allCases[index % PlacedForceKind.allCases.count]
    let emitters = [SceneEmitter(family: .halo, position: onEmitter, size: 8),
                    SceneEmitter(family: EmitterFamily.allCases[index % EmitterFamily.allCases.count], position: onEmitter)]
    let saved = try SceneDocument(name: "Singular \(index)", scene: ParticleScene(seed: 4, emitters: emitters, forces: [force]),
                                  force: SavedForce(kind: placedKind.rawValue, x: onEmitter.x, y: onEmitter.y, strength: 2),
                                  trailsOn: true, trailStrength: 0.5, additive: true)
    let document = try SceneDocument.decode(saved.encoded())
    // Open as the adapter does: the emitters and the placed force from the open actions, the scene's other fields kept.
    let actions = document.openActions()
    var scene = document.scene
    scene.emitters = try actions.filter { $0.id == "emitter.define" }.map { try SceneDocument.emitter(fromDefine: $0.values) }
    let placed = try #require(try actions.first { $0.id == "force.define" }.map { try SceneDocument.force(fromDefine: $0.values) })
    var sim = try SceneSimulation(scene: scene)
    sim.setPlacedForce(placed?.placedForce)
    #expect(sim.placedForce?.position == onEmitter && sim.scene.forces == [force])
    sim.run(steps: 600)
    #expect(sim.nonFiniteRemoved == 0, "\(force) with \(placedKind)")
    #expect(sim.instances().allSatisfy { $0.position.isFinite && $0.size.isFinite })
    #expect(sim.liveCount > 0)
}
