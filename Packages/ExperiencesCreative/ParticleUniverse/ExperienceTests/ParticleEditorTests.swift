// ParticleEditorTests — feature 036 A04-P04 T-A04-404, T-A04-412 and the adapter part of T-A04-415 (FR-A04-402,
// FR-A04-420…; US1, US3, US4; contracts/actions.md; research D2, D3, D6, §3). The open sequence of a saved scene
// through the core's logged actions, `ParticleCore.document(name:)`, the replay of an open, the rejected opens,
// `emitter.move` and the drawn-count cap of an opened eight-emitter scene. Short runs only (owner rule of 2026-11-13).
import Foundation
import Testing
@testable import ParticleUniverseExperience
import ParticleUniverseCore
import VisualCoreExperience
import VisualCoreMath

private let id = ExperienceID(rawValue: ParticleCore.experienceID)!
private let invalidOpen = ActionResult.rejected(.rule(code: "a04.invalid-open"))

private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<ParticleCore> {
    var engine = ExperienceEngine<ParticleCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<ParticleCore>) throws -> ParticleCore {
    try #require(engine.core)
}

/// Sends every open action of `document`; returns the results.
@discardableResult
private func open(_ document: SceneDocument, in engine: inout ExperienceEngine<ParticleCore>) -> [ActionResult] {
    document.openActions().map { engine.handle(control: $0.id, values: $0.values) }
}

/// What a person sees of an emitter: family, placement (explicit or the family's own), overrides.
private struct Seen: Equatable {
    var family: EmitterFamily
    var position: Vec2
    var size: Double?
    var lifetime: Double?
    var gradient: String?
    init(_ e: SceneEmitter) {
        family = e.family; position = e.position ?? e.family.emitter().position
        size = e.size; lifetime = e.lifetime; gradient = e.gradient
    }
}

/// The simulation-relevant state of a core, for "unchanged" checks.
private struct Observed: Equatable {
    var checksum: UInt64
    var emitters: [SceneEmitter]
    var force: PlacedForce?
    var trailsOn: Bool
    var trailStrength: Double
    var additive: Bool
    init(_ c: ParticleCore) {
        checksum = c.simulation.state.checksum(); emitters = c.simulation.visibleEmitters; force = c.placedForce
        trailsOn = c.trailsOn; trailStrength = c.trailStrength; additive = c.additive
    }
}

private func sample() throws -> SceneDocument {
    let scene = ParticleScene(seed: 99, emitters: [
        SceneEmitter(family: .curtain, position: Vec2(-200, 450), size: 10, lifetime: 2, gradient: "ocean"),
        SceneEmitter(family: .fountain),
        SceneEmitter(family: .halo, position: Vec2(-300, 200), gradient: "ember"),
    ])
    return try SceneDocument(name: "Nebula", scene: scene,
                             force: SavedForce(kind: PlacedForceKind.vortex.rawValue, x: 100, y: -50, strength: 1.5),
                             trailsOn: true, trailStrength: 0.4, additive: true)
}

@Suite struct ParticleEditorTests {
    // MARK: T-A04-404 Save and open

    @Test func theOpenActionsReproduceTheDocument() async throws {
        let document = try sample()
        var engine = try await makeEngine()
        try engine.run(steps: 30)
        let before = try core(engine)
        #expect(open(document, in: &engine).allSatisfy { $0 == .accepted })
        let opened = try core(engine)
        #expect(opened.simulation.visibleEmitters.map(Seen.init) == document.scene.emitters.map(Seen.init))
        #expect(opened.placedForce == document.force?.placedForce)
        #expect(opened.placedForce?.kind == .vortex && opened.placedForce?.position == Vec2(100, -50)
                && opened.placedForce?.strength == 1.5)
        #expect(opened.trailsOn && opened.trailStrength == 0.4 && opened.additive)
        #expect(opened.pendingOpen == nil)
        // Research §3: the scene seed, particle limit, time scale and scene forces stay as they were.
        #expect(opened.sceneSeed == before.sceneSeed && opened.simulation.scene.seed == before.sceneSeed)
        #expect(opened.simulation.scene.particleLimit == before.simulation.scene.particleLimit)
        #expect(opened.simulation.scene.timeScale == before.simulation.scene.timeScale)
        #expect(opened.simulation.scene.forces == before.simulation.scene.forces)
        // The opened scene runs.
        try engine.run(steps: 60)
        #expect(try core(engine).simulation.liveCount > 0)
    }

    @Test func aDocumentWithoutAForceRemovesThePlacedForce() async throws {
        var engine = try await makeEngine()
        #expect(engine.handle(control: "force.place", values: [0.75, 0.25]) == .accepted)
        var document = try sample()
        document.force = nil
        #expect(open(document, in: &engine).allSatisfy { $0 == .accepted })
        #expect(try core(engine).placedForce == nil)
    }

    @Test func theDocumentRoundTripsThroughTheOpenActions() async throws {
        var first = try await makeEngine()
        #expect(open(try sample(), in: &first).allSatisfy { $0 == .accepted })
        try first.run(steps: 20)
        let saved = try core(first).document(name: "  Nebula  ")
        #expect(saved.name == "Nebula")
        #expect(saved.scene.emitters.map(Seen.init) == (try sample()).scene.emitters.map(Seen.init))
        #expect(saved.force == (try sample()).force)
        #expect(saved.trailsOn && saved.trailStrength == 0.4 && saved.additive)
        // The file form decodes to the same document.
        #expect(try SceneDocument.decode(saved.encoded()) == saved)
        // Opened in another engine with the same seed, it saves the same document.
        var second = try await makeEngine()
        try second.run(steps: 5)
        #expect(open(saved, in: &second).allSatisfy { $0 == .accepted })
        #expect(try core(second).document(name: "Nebula") == saved)
        #expect(throws: SceneError.self) { try core(second).document(name: "   ") }
    }

    @Test func aReplayOfALogWithAnOpenReachesTheSameDigestThreeTimes() async throws {
        var engine = try await makeEngine(seed: 11)
        #expect(engine.handle(control: "emitter.add") == .accepted)
        try engine.run(steps: 20)
        #expect(open(try sample(), in: &engine).allSatisfy { $0 == .accepted })
        try engine.run(steps: 40)
        #expect(engine.handle(control: "emitter.move", values: [120, -80]) == .accepted)
        try engine.run(steps: 30)
        let digest = try engine.digest()
        let state = try core(engine)
        let snapshot = try engine.snapshot().encoded()
        for run in 1...3 {
            var restored = ExperienceEngine<ParticleCore>(id: id)
            try await restored.prepare(seed: 11)
            try restored.restore(try ExperienceSnapshot(data: snapshot))
            #expect(try restored.digest() == digest, "restore \(run)")
            let replayed = try ParticleCore.replay(seed: 11, log: state.log, steps: state.steps)
            #expect(replayed.simulation.state.checksum() == state.simulation.state.checksum(), "replay \(run)")
            #expect(replayed == state, "replay \(run)")
        }
    }

    @Test func anInvalidDefineRejectsTheWholeOpenAndLeavesTheSceneUnchanged() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 10)
        let before = Observed(try core(engine))
        #expect(engine.handle(control: "scene.begin", values: [2]) == .accepted)
        // Size 100 is outside the control's range; 0.5 is inside it but outside the size rule (1…48 or 0).
        #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 100, 0, 0]) == .rejected(.outOfRange(index: 3)))
        #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 0.5, 0, 0]) == invalidOpen)
        #expect(engine.handle(control: "emitter.define", values: [1.5, 0, -400, 0, 0, 0]) == invalidOpen,
                "a family index must be whole")
        #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 0, 0.1, 0]) == invalidOpen)
        #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 0, 0, 0]) == .accepted)
        // One of two emitters defined: the force and the commit are refused, nothing changes.
        #expect(engine.handle(control: "force.define", values: [0, 0, 0, 1]) == invalidOpen)
        #expect(engine.handle(control: "look.define", values: [1, 0.5, 1]) == invalidOpen)
        #expect(Observed(try core(engine)) == before)
        // An unknown force kind index is out of range; a fractional one breaks the force rule.
        #expect(engine.handle(control: "emitter.define", values: [2, 0, 0, 0, 0, 0]) == .accepted)
        #expect(engine.handle(control: "force.define", values: [1.5, 0, 0, 1]) == invalidOpen)
        #expect(engine.handle(control: "look.define", values: [1, 0.5, 1]) == .accepted, "the open still commits")
    }

    @Test func aDefineWithoutBeginIsRejected() async throws {
        var engine = try await makeEngine()
        let before = Observed(try core(engine))
        #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 0, 0, 0]) == invalidOpen)
        #expect(engine.handle(control: "force.define", values: [0, 0, 0, 1]) == invalidOpen)
        #expect(engine.handle(control: "look.define", values: [0, 0.85, 0]) == invalidOpen)
        #expect(Observed(try core(engine)) == before)
        #expect(try core(engine).log.isEmpty, "rejected actions are not logged")
        // After a commit the open is over: another define needs a new begin.
        #expect(open(try sample(), in: &engine).allSatisfy { $0 == .accepted })
        #expect(engine.handle(control: "look.define", values: [0, 0.85, 0]) == invalidOpen)
    }

    @Test func aWrongCountRejectsTheOpen() async throws {
        var engine = try await makeEngine()
        let before = Observed(try core(engine))
        #expect(engine.handle(control: "scene.begin", values: [1.5]) == invalidOpen)
        #expect(engine.handle(control: "scene.begin", values: [9]) == .rejected(.outOfRange(index: 0)))
        // Fewer emitters than begun.
        #expect(engine.handle(control: "scene.begin", values: [3]) == .accepted)
        for _ in 0..<2 { #expect(engine.handle(control: "emitter.define", values: [0, 0, -400, 0, 0, 0]) == .accepted) }
        #expect(engine.handle(control: "look.define", values: [0, 0.85, 0]) == invalidOpen)
        #expect(Observed(try core(engine)) == before)
        // More emitters than begun.
        #expect(engine.handle(control: "scene.begin", values: [1]) == .accepted, "a begin discards the pending open")
        #expect(engine.handle(control: "emitter.define", values: [3, 0, 0, 0, 0, 0]) == .accepted)
        #expect(engine.handle(control: "emitter.define", values: [3, 10, 0, 0, 0, 0]) == invalidOpen)
        #expect(engine.handle(control: "look.define", values: [0, 0.85, 0]) == .accepted)
        #expect(try core(engine).simulation.visibleEmitters == [SceneEmitter(family: .firework)])
    }

    // MARK: T-A04-412 Move an emitter

    @Test func emitterMoveSetsTheSelectedPositionClampedAndKeepsTheRest() async throws {
        var engine = try await makeEngine()
        #expect(try core(engine).selectedEmitterPosition == EmitterFamily.fountain.emitter().position,
                "an emitter without a position is at its family's own")
        #expect(engine.handle(control: "emitter.add") == .accepted)
        #expect(try core(engine).selectedEmitterPosition == SceneSimulation.placement(of: .fountain, index: 1))
        #expect(engine.handle(control: "size", values: [20]) == .accepted)
        #expect(engine.handle(control: "gradient", values: [2]) == .accepted)
        let first = try core(engine).simulation.visibleEmitters[0]
        let selected = try core(engine).selectedEntry
        #expect(engine.handle(control: "emitter.move", values: [700, -1_000]) == .accepted)
        let moved = try core(engine).selectedEntry
        #expect(moved.position == Vec2(500, -500), "clamped to ±500")
        #expect(try core(engine).selectedEmitterPosition == Vec2(500, -500))
        #expect(moved.family == selected.family && moved.size == 20 && moved.gradient == selected.gradient
                && moved.lifetime == selected.lifetime)
        #expect(try core(engine).simulation.visibleEmitters[0] == first, "only the selected emitter moves")
        #expect(engine.handle(control: "emitter.move", values: [1_001, 0]) == .rejected(.outOfRange(index: 0)))
        #expect(engine.handle(control: "emitter.move", values: [-120, 75]) == .accepted)
        #expect(try core(engine).selectedEntry.position == Vec2(-120, 75))
        // The move survives document → open.
        let saved = try core(engine).document(name: "Moved")
        var other = try await makeEngine(seed: 3)
        #expect(open(saved, in: &other).allSatisfy { $0 == .accepted })
        let reopened = try core(other).simulation.visibleEmitters
        #expect(reopened.map(Seen.init) == (try core(engine)).simulation.visibleEmitters.map(Seen.init))
        #expect(Seen(reopened[1]).position == Vec2(-120, 75))
    }

    // MARK: T-A04-415 (adapter part) Gates hold for opened scenes

    @Test func anOpenedEightEmitterSceneRespectsEachTiersDrawCap() async throws {
        let families = EmitterFamily.allCases
        let emitters = (0..<ParticleScene.maxEmitters).map { i in
            SceneEmitter(family: families[i % families.count], position: Vec2(Double(i) * 100 - 350, Double(i % 3) * 150 - 150))
        }
        let document = try SceneDocument(name: "Eight", scene: ParticleScene(emitters: emitters), force: nil,
                                         trailsOn: false, trailStrength: 0.85, additive: false)
        var engine = try await makeEngine()
        let results = open(document, in: &engine)
        #expect(results.count == ParticleScene.maxEmitters + 3 && results.allSatisfy { $0 == .accepted })
        try engine.run(steps: 240)
        let state = try core(engine)
        #expect(state.simulation.visibleEmitters.count == 8)
        let live = state.simulation.liveCount
        #expect(live > 0 && live <= state.simulation.scene.particleLimit)
        for tier in 0..<ParticleCore.qualityTiers {
            let cap = Int((Double(state.simulation.scene.particleLimit) * ParticleCore.drawShare(tier: tier)).rounded())
            let drawn = state.instances(tier: tier).count
            #expect(drawn <= cap && drawn == min(live, cap), "tier \(tier)")
        }
    }
}
