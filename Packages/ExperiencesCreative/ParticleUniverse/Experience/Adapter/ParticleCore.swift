// ParticleCore — feature 193 (UA-F07) T-U07-027 (FR-U07-001 to FR-U07-004; research R4, R5; clarification 3). The
// state of Particle Universe as an experience: the app's own `SceneSimulation` with the seed, the emitters, the placed
// force and the render settings. Its snapshot is a replay: the seed, every accepted action with the step it was made
// at, and the step count. A restore prepares the seed and replays them, because a particle system of up to 20,000
// particles has no stored form within the snapshot limit.
//
// Differences from the standalone app (FR-U07-003):
//   1. The simulation advances in the core's fixed steps (one `SceneSimulation` step per core step while playing),
//      never in the render callback; the presenter draws what the core holds.
//   2. The quality level caps only the drawn count (clarification 2); the simulation keeps the scene's limit.
//   3. `force.place` carries the world point normalized to 0…1 of the world square (x right, y up); the presenter maps
//      a touch to the world with the app's own `ParticleLayerScene.worldPoint`.
//   4. A preparation starts playing, also under Reduce Motion; the controls pause it once when Reduce Motion is in
//      effect, as the standalone app starts paused.
//   5. The outcome `scene-built` (three emitters or more) gives the verification runner's completion scenario
//      something to reach; the standalone app had no outcome.
//   6. Every `maxReplaySteps` (10 simulated minutes) the core rebases: it keeps its configuration as an anchor (the
//      scene with its emitters, the force, the settings), starts a fresh simulation from it with the next scene seed
//      and clears the log, so that a restore replays at most 10 simulated minutes (clarification 3; tests are short,
//      so the bound comes from a short replay's cost per step). Particles live at most 8 s, so the picture restarts
//      briefly once in 10 minutes.
//   7. Feature 036 (A04-P04, T-A04-405, T-A04-413; contracts/actions.md; research D2, D3, D6): a saved scene opens through
//      logged actions (`scene.begin`, `emitter.define` × n, `force.define`, `look.define`), so a replay reproduces it
//      and the anchor gains no fields; `emitter.move` places the selected emitter; `document(name:)` saves the state.
import Foundation
import ParticleUniverseCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreParameters
import VisualCorePersistence
import VisualCoreSimulation

/// The state of Particle Universe: a simulation and the actions that made it. Schema version 1.
public struct ParticleCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a04.particle-universe"
    /// The largest number of logged actions; beyond it an action is rejected (the snapshot stays within 1 MiB).
    public static let maxLog = 4_000
    /// The standalone app's seed step for "New seed".
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// The gradients offered: none (the family's colours) and the built-in palettes.
    public static let gradientIDs: [String?] = SceneDocument.gradientIDs
    /// The outcome threshold.
    public static let builtEmitters = 3

    /// The steps between two rebases: 10 simulated minutes (difference 6).
    public static let maxReplaySteps = 10 * 60 * 120

    /// What a replay starts from: the configuration at the preparation or at the last rebase.
    public struct Anchor: Codable, Equatable, Sendable {
        public var scene: ParticleScene
        public var playing: Bool
        public var selectedEmitter: Int
        public var selectedKind: String?
        public var force: [Double]?          // kind index, x, y, strength
        public var strength: Double
        public var trailsOn: Bool
        public var trailStrength: Double
        public var additive: Bool
    }

    /// The preparation seed.
    public private(set) var seed: UInt64
    /// Where the current replay starts.
    public private(set) var anchor: Anchor
    /// Rebases since the preparation.
    public private(set) var rebases: Int
    /// The scene's seed (moves with "New seed").
    public private(set) var sceneSeed: UInt64
    /// The accepted actions, oldest first; each carries its step.
    public private(set) var log: [ExperienceAction]
    /// The steps run since the anchor.
    public private(set) var steps: Int
    /// The running simulation (not encoded: a restore replays the log).
    public private(set) var simulation: SceneSimulation
    /// Whether the simulation advances.
    public private(set) var playing: Bool
    /// The selected emitter's index among the visible ones.
    public private(set) var selectedEmitter: Int
    /// The force kind chosen for the next placement; nil is None.
    public private(set) var selectedKind: PlacedForceKind?
    /// The placed force, if any.
    public private(set) var placedForce: PlacedForce?
    /// The strength for the force and future placements.
    public private(set) var strength: Double
    /// Render settings, kept as state because the person chose them.
    public private(set) var trailsOn: Bool
    public private(set) var trailStrength: Double
    public private(set) var additive: Bool
    /// The open being defined between `scene.begin` and `look.define`; not part of the anchor or the snapshot (the
    /// logged actions that built it are replayed).
    private(set) var pendingOpen: PendingOpen?

    /// An open in progress (contracts/actions.md): the emitter count begun, the emitters and the force defined so far.
    struct PendingOpen: Equatable, Sendable {
        /// The emitter count `scene.begin` announced, 1…8.
        var count: Int
        /// The emitters defined so far, in order.
        var emitters: [SceneEmitter] = []
        /// Whether `force.define` came.
        var forceDefined = false
        /// The defined force; nil for none.
        var force: SavedForce?
    }

    /// The rule code of every rejected open action.
    public static let invalidOpen = "a04.invalid-open"
    /// The largest |x| or |y| `emitter.move` accepts before clamping to ±`PlacedForce.worldHalfExtent`.
    public static let moveInputExtent = 1_000.0

    // MARK: Contract

    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    public static var qualityTiers: Int { SceneQuality.tierCount }

    /// Four levels, as `SceneQuality`: each draws at most a share of the scene's particles.
    public static var qualityProfile: QualityProfile {
        let levels = (0..<SceneQuality.tierCount).map { tier in
            QualityLevel(name: "level-\(tier)", elementShare: drawShare(tier: tier))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: SceneQuality.tierCount)
    }

    /// The share of the scene's particles drawn at `tier` (1, ¾, ½, ¼).
    public static func drawShare(tier: Int) -> Double {
        1 - 0.25 * Double(min(max(tier, 0), SceneQuality.tierCount - 1))
    }

    /// The scene's world square on one axis, ±`PlacedForce.worldHalfExtent`.
    private static var world: ClosedRange<Double> { -PlacedForce.worldHalfExtent...PlacedForce.worldHalfExtent }

    public static var controls: [ExperienceControl] {
        [
            ExperienceControl(id: "family", ranges: [0...Double(EmitterFamily.allCases.count - 1)]),
            ExperienceControl(id: "emitter.add"),
            ExperienceControl(id: "emitter.remove"),
            ExperienceControl(id: "emitter.select", ranges: [0...Double(ParticleScene.maxEmitters - 1)]),
            ExperienceControl(id: "size", ranges: [SceneEmitter.sizeRange]),
            ExperienceControl(id: "lifetime", ranges: [SceneEmitter.lifetimeRange]),
            ExperienceControl(id: "gradient", ranges: [0...Double(gradientIDs.count - 1)]),
            ExperienceControl(id: "trails", ranges: [0...1]),
            ExperienceControl(id: "trailStrength", ranges: [0...1]),
            ExperienceControl(id: "blend", ranges: [0...1]),
            ExperienceControl(id: "force.kind", ranges: [0...Double(PlacedForceKind.allCases.count)]),
            ExperienceControl(id: "force.place", ranges: [0...1, 0...1]),
            ExperienceControl(id: "force.nudge", ranges: [-1_000...1_000, -1_000...1_000]),
            ExperienceControl(id: "force.center"),
            ExperienceControl(id: "strength", ranges: [PlacedForce.strengthRange]),
            ExperienceControl(id: "play"),
            ExperienceControl(id: "pause"),
            ExperienceControl(id: "step"),
            ExperienceControl(id: "reseed"),
            // Feature 036: the open sequence and the move (contracts/actions.md). Size and lifetime 0 mean the
            // family's own; finer rules (whole indices, override ranges) are checked by `SceneDocument`.
            ExperienceControl(id: "scene.begin", ranges: [1...Double(ParticleScene.maxEmitters)]),
            ExperienceControl(id: "emitter.define", ranges: [
                0...Double(EmitterFamily.allCases.count - 1), world, world, 0...SceneEmitter.sizeRange.upperBound,
                0...SceneEmitter.lifetimeRange.upperBound, 0...Double(gradientIDs.count - 1)]),
            ExperienceControl(id: "force.define", ranges: [0...Double(PlacedForceKind.allCases.count), world, world,
                                                           PlacedForce.strengthRange]),
            ExperienceControl(id: "look.define", ranges: [0...1, 0...1, 0...1]),
            ExperienceControl(id: "emitter.move", ranges: [-moveInputExtent...moveInputExtent,
                                                           -moveInputExtent...moveInputExtent]),
        ]
    }

    public static func prepare(seed: UInt64) async throws -> ParticleCore {
        try Task.checkCancellation()
        return try ParticleCore(seed: seed)
    }

    /// The standalone start: one Fountain emitter with the seed, Attractor chosen, strength 1, no trails, playing.
    private init(seed: UInt64) throws {
        let anchor = Anchor(scene: .single(.fountain, seed: seed), playing: true, selectedEmitter: 0,
                            selectedKind: PlacedForceKind.attractor.rawValue, force: nil, strength: 1,
                            trailsOn: SceneDocument.defaultTrailsOn, trailStrength: SceneDocument.defaultTrailStrength,
                            additive: SceneDocument.defaultAdditive)
        try self.init(seed: seed, anchor: anchor, rebases: 0)
    }

    /// The state an anchor describes, before any action.
    private init(seed: UInt64, anchor: Anchor, rebases: Int) throws {
        self.seed = seed
        self.anchor = anchor
        self.rebases = rebases
        sceneSeed = anchor.scene.seed
        log = []
        steps = 0
        simulation = try SceneSimulation(scene: anchor.scene)
        playing = anchor.playing
        selectedEmitter = min(max(anchor.selectedEmitter, 0), simulation.visibleEmitters.count - 1)
        selectedKind = anchor.selectedKind.flatMap(PlacedForceKind.init(rawValue:))
        strength = anchor.strength
        trailsOn = anchor.trailsOn
        trailStrength = anchor.trailStrength
        additive = anchor.additive
        placedForce = nil
        pendingOpen = nil
        if let f = anchor.force, f.count == 4, PlacedForceKind.allCases.indices.contains(Int(f[0])) {
            setForce(PlacedForce(kind: PlacedForceKind.allCases[Int(f[0])], position: Vec2(f[1], f[2]), strength: f[3]))
        }
    }

    /// The current configuration as the anchor of a fresh scene with `sceneSeed`.
    private func currentAnchor(sceneSeed: UInt64) -> Anchor {
        let force = placedForce.map { f -> [Double] in
            [Double(PlacedForceKind.allCases.firstIndex(of: f.kind) ?? 0), f.position.x, f.position.y, f.strength]
        }
        return Anchor(scene: simulation.rebuildScene(seed: sceneSeed), playing: playing, selectedEmitter: selectedEmitter,
                      selectedKind: selectedKind?.rawValue, force: force, strength: strength, trailsOn: trailsOn,
                      trailStrength: trailStrength, additive: additive)
    }

    /// Difference 6: a fresh simulation from the current configuration with the next scene seed, an empty log.
    /// Internal so that the host tests can rebase without running 10 simulated minutes (tests are short).
    mutating func rebase() {
        guard let next = try? ParticleCore(seed: seed, anchor: currentAnchor(sceneSeed: sceneSeed &+ Self.seedStep),
                                           rebases: rebases + 1) else { return }
        self = next
    }

    /// One fixed step: the simulation advances one step while playing.
    public mutating func update(step: Int) {
        steps += 1
        if playing { simulation.run(steps: 1) }
        if steps >= Self.maxReplaySteps { rebase() }
    }

    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        guard log.count < Self.maxLog else { return .rejected(.rule(code: "a04.log-full")) }
        let result = perform(action)
        // Logged at the core's own step since the anchor, which a replay counts (the engine's index keeps counting
        // across a rebase).
        if result.isAccepted { log.append(ExperienceAction(control: action.control, values: action.values, step: steps)) }
        return result
    }

    /// Carries out an action without logging it (the replay calls it too).
    private mutating func perform(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        switch action.control {
        case "family":
            let family = EmitterFamily.allCases[Int(v[0].rounded())]
            var emitter = selectedEntry
            guard emitter.family != family else { return .rejected(.rule(code: "a04.same-family")) }
            emitter.family = family
            guard simulation.setEmitter(at: selectedEmitter, emitter) else { return .rejected(.rule(code: "a04.no-emitter")) }
        case "emitter.add":
            let family = selectedEntry.family
            let k = simulation.visibleEmitters.count
            guard simulation.addEmitter(SceneEmitter(family: family, position: SceneSimulation.placement(of: family, index: k)))
            else { return .rejected(.rule(code: "a04.emitters-full")) }
            selectedEmitter = simulation.visibleEmitters.count - 1
        case "emitter.remove":
            guard simulation.removeEmitter(at: selectedEmitter) else { return .rejected(.rule(code: "a04.last-emitter")) }
            selectedEmitter = max(0, selectedEmitter - 1)
        case "emitter.select":
            let index = Int(v[0].rounded())
            guard simulation.visibleEmitters.indices.contains(index) else { return .rejected(.rule(code: "a04.no-emitter")) }
            selectedEmitter = index
        case "size":
            edit { $0.size = SceneEmitter.clampedSize(v[0]) ?? $0.size }
        case "lifetime":
            edit { $0.lifetime = SceneEmitter.clampedLifetime(v[0]) ?? $0.lifetime }
        case "gradient":
            edit { $0.gradient = Self.gradientIDs[Int(v[0].rounded())] }
        case "trails":
            trailsOn = v[0] >= 0.5
        case "trailStrength":
            trailStrength = v[0]
        case "blend":
            additive = v[0] >= 0.5
        case "force.kind":
            let index = Int(v[0].rounded())
            selectedKind = index == 0 ? nil : PlacedForceKind.allCases[index - 1]
            if var force = placedForce {
                if let kind = selectedKind { force.kind = kind; setForce(force) } else { setForce(nil) }
            }
        case "force.place":
            place(at: Vec2((v[0] - 0.5) * 2 * PlacedForce.worldHalfExtent, (v[1] - 0.5) * 2 * PlacedForce.worldHalfExtent))
        case "force.nudge":
            guard var force = placedForce else { return .rejected(.rule(code: "a04.no-force")) }
            force.nudge(by: Vec2(v[0], v[1]))
            setForce(force)
        case "force.center":
            place(at: .zero)
        case "strength":
            strength = min(max(v[0], PlacedForce.strengthRange.lowerBound), PlacedForce.strengthRange.upperBound)
            if var force = placedForce { force.setStrength(strength); setForce(force) }
        case "play":
            guard !playing else { return .rejected(.rule(code: "a04.already-playing")) }
            playing = true
        case "pause":
            guard playing else { return .rejected(.rule(code: "a04.already-paused")) }
            playing = false
        case "step":
            guard !playing else { return .rejected(.rule(code: "a04.not-paused")) }
            simulation.run(steps: 1)
        case "reseed":
            guard let rebuilt = try? SceneSimulation(scene: simulation.rebuildScene(seed: sceneSeed &+ Self.seedStep))
            else { return .rejected(.rule(code: "a04.invalid-scene")) }
            sceneSeed = sceneSeed &+ Self.seedStep
            simulation = rebuilt
            simulation.setPlacedForce(placedForce)
            selectedEmitter = min(selectedEmitter, simulation.visibleEmitters.count - 1)
        case "scene.begin":
            guard v[0].rounded() == v[0] else { return .rejected(.rule(code: Self.invalidOpen)) }
            pendingOpen = PendingOpen(count: Int(v[0]))
        case "emitter.define":
            guard var open = pendingOpen, open.emitters.count < open.count, !open.forceDefined,
                  let emitter = try? SceneDocument.emitter(fromDefine: v)
            else { return .rejected(.rule(code: Self.invalidOpen)) }
            open.emitters.append(emitter)
            pendingOpen = open
        case "force.define":
            // `force(fromDefine:)` gives nil for kind 0 (none), so its success is checked apart from its value.
            guard var open = pendingOpen, open.emitters.count == open.count, !open.forceDefined,
                  let defined = Self.definedForce(v)
            else { return .rejected(.rule(code: Self.invalidOpen)) }
            open.forceDefined = true
            open.force = defined
            pendingOpen = open
        case "look.define":
            guard let open = pendingOpen, commit(open, trailsOn: v[0] >= 0.5, trailStrength: v[1], additive: v[2] >= 0.5)
            else { return .rejected(.rule(code: Self.invalidOpen)) }
        case "emitter.move":
            let h = PlacedForce.worldHalfExtent
            let p = Vec2(min(max(v[0], -h), h), min(max(v[1], -h), h))
            edit { $0.position = p }
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// The force a valid `force.define` value list describes, wrapped so that "none" (`.some(nil)`) differs from an
    /// invalid list (nil).
    private static func definedForce(_ v: [Double]) -> SavedForce?? {
        do { return .some(try SceneDocument.force(fromDefine: v)) } catch { return nil }
    }

    /// Commits a complete pending open (research §3): a scene with the defined emitters and the current scene seed,
    /// particle limit, time scale and scene forces, validated with the `ParticleScene` rules and built like `reseed`
    /// builds (a fresh deterministic simulation); then the placed force and the looks. False, with nothing changed,
    /// for a wrong emitter count or an invalid scene; the pending open is cleared on success.
    private mutating func commit(_ open: PendingOpen, trailsOn: Bool, trailStrength: Double, additive: Bool) -> Bool {
        guard open.emitters.count == open.count, (0...1).contains(trailStrength) else { return false }
        var scene = simulation.rebuildScene(seed: sceneSeed)
        scene.emitters = open.emitters
        guard let rebuilt = try? SceneSimulation(scene: scene) else { return false }
        simulation = rebuilt
        selectedEmitter = 0
        let force = open.force?.placedForce
        if let force {
            selectedKind = force.kind
            strength = force.strength
        }
        setForce(force)
        self.trailsOn = trailsOn
        self.trailStrength = trailStrength
        self.additive = additive
        pendingOpen = nil
        return true
    }

    /// The current state as a saved document named `name` (FR-A04-402): the visible emitters with the scene seed,
    /// particle limit, time scale and scene forces, the placed force and the looks. Throws when the name is not 1…64
    /// characters after trimming (or, never in practice, when the state is out of the document's ranges).
    public func document(name: String) throws(SceneError) -> SceneDocument {
        try SceneDocument(name: name, scene: simulation.rebuildScene(seed: sceneSeed), force: placedForce.map(SavedForce.init),
                          trailsOn: trailsOn, trailStrength: trailStrength, additive: additive)
    }

    /// A fresh preparation with the same seed; a seed that could not prepare keeps the state (it prepared before).
    public mutating func reset() {
        if let fresh = try? ParticleCore(seed: seed) { self = fresh }
    }

    /// `scene-built` once three or more emitters are visible.
    public var outcome: ExperienceOutcome? {
        simulation.visibleEmitters.count >= Self.builtEmitters ? ExperienceOutcome(code: "scene-built") : nil
    }

    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(rebases)
        builder.add(sceneSeed)
        builder.add(steps)
        builder.add(simulation.state.checksum())
        builder.add(simulation.liveCount)
        builder.add(simulation.visibleEmitters.count)
        builder.add(playing)
        builder.add(selectedEmitter)
        builder.add(selectedKind?.rawValue ?? "none")
        if let force = placedForce {
            builder.add(force.kind.rawValue)
            try builder.add(force.position.x)
            try builder.add(force.position.y)
            try builder.add(force.strength)
        } else {
            builder.add("no-force")
        }
        try builder.add(strength)
        builder.add(trailsOn)
        try builder.add(trailStrength)
        builder.add(additive)
        builder.add(count: log.count)
    }

    // MARK: Snapshot: a replay (clarification 3)

    private struct Payload: Codable {
        var seed: UInt64
        var anchor: Anchor
        var rebases: Int
        var steps: Int
        var log: [ExperienceAction]
    }

    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Payload(seed: seed, anchor: anchor, rebases: rebases, steps: steps, log: log))
    }

    public static func restore(payload: Data, seed: UInt64) throws -> ParticleCore {
        let decoded = try JSONDecoder().decode(Payload.self, from: payload)
        guard decoded.steps < maxReplaySteps else { throw ReplayError.tooLong(decoded.steps) }
        var core = try ParticleCore(seed: decoded.seed, anchor: decoded.anchor, rebases: decoded.rebases)
        try core.replay(log: decoded.log, steps: decoded.steps)
        return core
    }

    /// The state the log gives from a fresh preparation with `seed` (no rebase in between).
    public static func replay(seed: UInt64, log: [ExperienceAction], steps: Int) throws -> ParticleCore {
        var core = try ParticleCore(seed: seed)
        try core.replay(log: log, steps: steps)
        return core
    }

    /// Plays each action at its step with the steps between, then the steps after the last action. An action that is
    /// rejected now (a damaged or foreign payload) fails the restore.
    private mutating func replay(log: [ExperienceAction], steps target: Int) throws {
        for action in log {
            guard action.step >= steps, action.step <= target else { throw ReplayError.outOfOrder(action.step) }
            while steps < action.step { update(step: steps) }
            guard apply(action).isAccepted else { throw ReplayError.rejected(action.control) }
        }
        while steps < target { update(step: steps) }
    }

    /// Why a replay failed.
    public enum ReplayError: Error, Equatable {
        case outOfOrder(Int)
        case rejected(String)
        case tooLong(Int)
    }

    public static func == (a: ParticleCore, b: ParticleCore) -> Bool {
        a.seed == b.seed && a.anchor == b.anchor && a.rebases == b.rebases && a.sceneSeed == b.sceneSeed
            && a.steps == b.steps && a.log == b.log
            && a.simulation.state.checksum() == b.simulation.state.checksum() && a.playing == b.playing
    }

    // MARK: Derived values and helpers

    /// The selected emitter.
    public var selectedEntry: SceneEmitter {
        let visible = simulation.visibleEmitters
        return visible[min(max(selectedEmitter, 0), visible.count - 1)]
    }

    /// The particles to draw at the quality `tier`: at most the tier's share of the scene's limit.
    public func instances(tier: Int) -> [ParticleInstance] {
        let all = simulation.instances()
        let cap = Int((Double(simulation.scene.particleLimit) * Self.drawShare(tier: tier)).rounded())
        return all.count > cap ? Array(all.prefix(cap)) : all
    }

    /// The selected emitter's scene position: its explicit position, or its family's own when it has none (the point
    /// `emitter.move` steps from).
    public var selectedEmitterPosition: Vec2 {
        let e = selectedEntry
        return e.position ?? e.family.emitter().position
    }

    private mutating func edit(_ change: (inout SceneEmitter) -> Void) {
        var emitter = selectedEntry
        change(&emitter)
        _ = simulation.setEmitter(at: selectedEmitter, emitter)
    }

    private mutating func place(at world: Vec2) {
        if var force = placedForce {
            force.move(to: world)
            setForce(force)
        } else {
            let kind = selectedKind ?? .attractor
            selectedKind = kind
            setForce(PlacedForce(kind: kind, position: world, strength: strength))
        }
    }

    private mutating func setForce(_ force: PlacedForce?) {
        placedForce = force
        simulation.setPlacedForce(force)
    }
}
