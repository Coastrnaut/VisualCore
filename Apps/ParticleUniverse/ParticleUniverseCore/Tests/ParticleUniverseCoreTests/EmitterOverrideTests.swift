// EmitterOverrideTests — feature 035 A04-P03 T-A04-309 (US2; FR-A04-305; SC-A04-302; clarification 5; research R3).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreParameters
import VisualCoreSimulation
@testable import ParticleUniverseCore

/// The particles spawned in the last step: emission runs after aging, so they are the last `n` instances at age 0.
private func newest(_ sim: SceneSimulation, _ n: Int) -> [ParticleInstance] { Array(sim.instances().suffix(n)) }

@Test func newParticlesTakeTheNewSizeAndGradient() throws {
    // SC-A04-302 (size and color at age 0).
    var sim = try SceneSimulation(scene: .single(.firework, seed: 2))
    let base = EmitterFamily.firework.emitter()
    let changed = SceneEmitter(family: .firework, size: 20, gradient: "ocean")
    let set = sim.setEmitter(at: 0, changed)
    #expect(set)
    sim.apply(.burst(emitter: 0, count: 50))
    sim.run(steps: 1)
    let fresh = newest(sim, 50)
    let ocean = Palette.builtIn("ocean")!.sample(1)
    #expect(fresh.count == 50)
    #expect(fresh.allSatisfy { $0.size == 20 }, "new start size")
    #expect(fresh.allSatisfy { abs($0.color.x - ocean.x) < 1e-12 && abs($0.color.y - ocean.y) < 1e-12 && $0.color.w == 1 })
    let e = changed.emitter()
    #expect(abs(e.endSize / e.startSize - base.endSize / base.startSize) < 1e-12, "end keeps the family's ratio")
    #expect(e.endColor.w == 0)
}

@Test func lifetimeAppliesOnlyToParticlesBornAfterTheChange() throws {
    // SC-A04-302 (lifetime is fixed at birth): Halo particles live 1.5–2.5 s; after a change to 0.2 s, particles born
    // before it outlive 0.3 s, particles born after it are gone 0.25 s after emission stops.
    var sim = try SceneSimulation(scene: .single(.halo, seed: 3))
    sim.addEmitter(SceneEmitter(family: .curtain))
    sim.run(steps: 120)
    let old = sim.state.system.liveCount(source: 0)
    #expect(old > 100)
    _ = sim.setEmitter(at: 0, SceneEmitter(family: .halo, lifetime: 0.2))
    sim.run(steps: 36)                 // 0.3 s: new short-lived particles come and go; the old ones remain
    #expect(sim.state.system.liveCount(source: 0) >= old / 2, "earlier particles keep their 1.5–2.5 s lifetime")
    sim.run(steps: 240)                // the old ones have expired; only 0.16–0.24 s particles remain
    _ = sim.removeEmitter(at: 0)       // stop emission
    sim.run(steps: 30)                 // 0.25 s
    #expect(sim.state.system.liveCount(source: 0) == 0, "every particle born after the change lived ≤ 0.24 s")
}

@Test func otherEmittersAreUnaffected() throws {
    var sim = try SceneSimulation(scene: .single(.halo, seed: 6))
    sim.addEmitter(SceneEmitter(family: .halo, position: Vec2(200, 0)))
    let before = sim.state.system.emitters[0]
    _ = sim.setEmitter(at: 1, SceneEmitter(family: .halo, position: Vec2(200, 0), size: 40, lifetime: 5, gradient: "neon"))
    #expect(sim.state.system.emitters[0] == before)
}

@Test func validationAndCodingOfOverrides() throws {
    func reason(_ e: SceneEmitter) -> SceneError? {
        do { try ParticleScene(emitters: [SceneEmitter(family: .fountain), e]).validate(); return nil } catch { return error }
    }
    #expect(reason(SceneEmitter(family: .halo, size: 48, lifetime: 0.2, gradient: "ember")) == nil)
    #expect(reason(SceneEmitter(family: .halo, size: 0.5)) == .invalidEmitter(1))
    #expect(reason(SceneEmitter(family: .halo, size: .nan)) == .invalidEmitter(1))
    #expect(reason(SceneEmitter(family: .halo, lifetime: 9)) == .invalidEmitter(1))
    #expect(reason(SceneEmitter(family: .halo, gradient: "plaid")) == .invalidEmitter(1))
    let scene = ParticleScene(emitters: [SceneEmitter(family: .halo, size: 12, lifetime: 3, gradient: "forest")])
    let back = try JSONDecoder().decode(ParticleScene.self, from: JSONEncoder().encode(scene))
    #expect(back == scene)
    let old = #"{"version":1,"seed":0,"particleLimit":4000,"timeScale":1,"emitters":[{"family":"halo"}],"forces":[]}"#
    let decoded = try JSONDecoder().decode(ParticleScene.self, from: Data(old.utf8))
    #expect(decoded.emitters[0] == SceneEmitter(family: .halo), "files without overrides decode with none")
    #expect(SceneEmitter.clampedSize(100) == 48 && SceneEmitter.clampedSize(.infinity) == nil)
    #expect(SceneEmitter.clampedLifetime(0) == 0.2 && SceneEmitter.clampedLifetime(nil) == nil)
}
