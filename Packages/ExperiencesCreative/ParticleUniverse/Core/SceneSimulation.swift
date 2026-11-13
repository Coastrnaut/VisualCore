// SceneSimulation.swift — a validated scene running on VisualCore's ParticleSystem and FixedStepRunner (feature 033
// A04-P01 T-A04-108; FR-A04-103–FR-A04-105; research R5, R6). Fixed step 1/120 s, at most 8 steps per frame; the time
// scale multiplies frame time only, so replays stay deterministic.
// Feature 035 (A04-P03 T-A04-307): emitter slots with retirement — removed emitters stop emitting and keep their slot
// until their last particle dies, so no live particle changes look (research R4); family forces are the deduplicated
// forces of the visible emitters' families.
import VisualCoreMath
import VisualCoreSimulation

/// The steppable state: the particle system plus the bookkeeping commands need.
public struct SceneState: FixedStepSimulation, Sendable {
    /// The particle pool (the placed force if any, then scene forces, then the families' forces).
    public internal(set) var system: ParticleSystem
    /// Number of scene forces in `system.forces` (the indices `moveAttractor` may address).
    public let sceneForceCount: Int
    /// Whether `system.forces[0]` is a placed force (feature 034); scene forces then start at index 1.
    public internal(set) var hasPlacedForce = false
    /// Commands ignored because their index named nothing suitable.
    public internal(set) var ignoredCommands = 0

    /// Advances the particle system.
    public mutating func step(_ dt: Double) { system.step(dt) }
    /// The particle system's checksum.
    public func checksum() -> UInt64 { system.checksum() }

    /// Places, replaces or removes the placed force in slot 0 (feature 034).
    public mutating func setPlacedForce(_ force: ParticleForce?) {
        switch (force, hasPlacedForce) {
        case (let f?, true): system.forces[0] = f
        case (let f?, false): system.forces.insert(f, at: 0); hasPlacedForce = true
        case (nil, true): system.forces.removeFirst(); hasPlacedForce = false
        case (nil, false): break
        }
    }

    /// Replaces the family forces (everything after the placed force and the scene forces).
    mutating func replaceFamilyForces(_ forces: [ParticleForce]) {
        let keep = sceneForceCount + (hasPlacedForce ? 1 : 0)
        system.forces = Array(system.forces.prefix(keep)) + forces
    }

    /// Applies one command (ignoring and counting invalid ones).
    public mutating func apply(_ command: SceneCommand) {
        switch command {
        case .moveAttractor(let index, let x, let y):
            let slot = index + (hasPlacedForce ? 1 : 0)
            guard index >= 0, index < sceneForceCount, x.isFinite, y.isFinite,
                  case .attractor(_, let s, let r) = system.forces[slot] else { ignoredCommands += 1; return }
            system.forces[slot] = .attractor(point: Vec2(x, y), strength: s, radius: r)
        case .burst(let emitter, let count):
            guard system.emitters.indices.contains(emitter) else { ignoredCommands += 1; return }
            system.burst(min(max(count, EmitterBurst.countRange.lowerBound), EmitterBurst.countRange.upperBound), from: emitter)
        case .setEmitting(let emitter, let on):
            guard system.emitters.indices.contains(emitter) else { ignoredCommands += 1; return }
            system.emitters[emitter].isEmitting = on
        }
    }
}

/// A running scene: build it from a validated `ParticleScene`, advance it with frame times or fixed steps, and read
/// counts and a particle snapshot for drawing. Drawing never changes the simulation.
public struct SceneSimulation: Sendable {
    /// Fixed simulation step (seconds).
    public static let step = 1.0 / 120
    /// Most steps per frame.
    public static let maxStepsPerFrame = 8

    /// The scene this simulation was built from.
    public let scene: ParticleScene
    private var runner: FixedStepRunner<SceneState, SceneCommand>

    /// Builds the simulation; throws if the scene is invalid. `controls` are commands replayed at step indices.
    public init(scene: ParticleScene, controls: [(step: Int, command: SceneCommand)] = []) throws(SceneError) {
        try scene.validate()
        self.scene = scene
        var system = ParticleSystem(capacity: scene.particleLimit, seed: scene.seed)
        system.emitters = scene.emitters.map { $0.emitter() }
        system.forces = scene.forces.map(\.particleForce) + Self.familyForces(scene.emitters)
        let state = SceneState(system: system, sceneForceCount: scene.forces.count)
        slots = scene.emitters.map { Optional($0) }
        runner = FixedStepRunner(simulation: state, clock: FixedStepClock(step: Self.step, maxSteps: Self.maxStepsPerFrame),
                                 stream: ControlStream(controls)) { state, command in state.apply(command) }
    }

    /// The forces the families of `emitters` bring, each family once, in order of first appearance (feature 035; a
    /// scene with two Fountains has one gravity, not two).
    static func familyForces(_ emitters: [SceneEmitter]) -> [ParticleForce] {
        var seen: [EmitterFamily] = []
        for e in emitters where !seen.contains(e.family) { seen.append(e.family) }
        return seen.flatMap { $0.forces() }
    }

    // MARK: Emitter slots (feature 035)

    /// One entry per particle-system emitter: the visible emitter, or nil for a retired slot whose particles fade.
    public private(set) var slots: [SceneEmitter?] = []
    /// The emitters a person sees, in order.
    public var visibleEmitters: [SceneEmitter] { slots.compactMap { $0 } }
    /// Slots of removed emitters whose particles may still be alive.
    public var retiredSlots: Int { slots.filter { $0 == nil }.count }

    private func slotIndex(visible index: Int) -> Int? {
        var n = -1
        for (i, s) in slots.enumerated() where s != nil {
            n += 1
            if n == index { return i }
        }
        return nil
    }

    private func freeSlot() -> Int? {
        slots.indices.first { slots[$0] == nil && runner.simulation.system.liveCount(source: $0) == 0 }
    }

    /// True when another emitter fits: fewer than `ParticleScene.maxEmitters` slots, or a retired slot whose
    /// particles are gone.
    public var canAddEmitter: Bool { slots.count < ParticleScene.maxEmitters || freeSlot() != nil }

    /// Where the k-th added emitter (k ≥ 1) of `family` goes: the family's position shifted 150·⌈k/2⌉ sideways,
    /// alternating right and left, clamped to ±450 (research R5).
    public static func placement(of family: EmitterFamily, index k: Int) -> Vec2 {
        let base = family.emitter().position
        guard k > 0 else { return base }
        let step = 150.0 * Double((k + 1) / 2) * (k % 2 == 1 ? 1 : -1)
        return Vec2(min(max(base.x + step, -450), 450), base.y)
    }

    /// Adds `emitter` (reusing a free retired slot, else appending); false when no slot is available.
    @discardableResult
    public mutating func addEmitter(_ emitter: SceneEmitter) -> Bool {
        let index: Int
        if let free = freeSlot() {
            index = free
            slots[index] = emitter
            runner.mutate { $0.system.emitters[index] = emitter.emitter() }
        } else if slots.count < ParticleScene.maxEmitters {
            slots.append(emitter)
            runner.mutate { $0.system.emitters.append(emitter.emitter()) }
        } else {
            return false
        }
        syncFamilyForces()
        return true
    }

    /// Removes the visible emitter at `index`: it stops emitting and its slot is retired until its particles are
    /// gone. False for a bad index or the last visible emitter (a scene always has one).
    @discardableResult
    public mutating func removeEmitter(at index: Int) -> Bool {
        guard visibleEmitters.count > 1, let slot = slotIndex(visible: index) else { return false }
        slots[slot] = nil
        runner.mutate { $0.system.emitters[slot].isEmitting = false; $0.system.emitters[slot].burst = nil }
        syncFamilyForces()
        return true
    }

    /// Replaces the visible emitter at `index` (family, position, overrides); false for a bad index.
    @discardableResult
    public mutating func setEmitter(at index: Int, _ emitter: SceneEmitter) -> Bool {
        guard let slot = slotIndex(visible: index) else { return false }
        slots[slot] = emitter
        runner.mutate { $0.system.emitters[slot] = emitter.emitter() }
        syncFamilyForces()
        return true
    }

    private mutating func syncFamilyForces() {
        let forces = Self.familyForces(visibleEmitters)
        runner.mutate { $0.replaceFamilyForces(forces) }
    }

    /// A scene with the visible emitters (retired ones dropped) and this scene's other settings, for rebuilding.
    public func rebuildScene(seed: UInt64? = nil) -> ParticleScene {
        var s = scene
        s.emitters = visibleEmitters
        if let seed { s.seed = seed }
        return s
    }

    /// Adds a frame's elapsed real time (scaled by the scene's time scale) and runs the resulting steps; returns them.
    @discardableResult
    public mutating func advance(frame dt: Double) -> Int {
        runner.advance(frame: dt.isFinite ? dt * scene.timeScale : dt)
    }

    /// Runs one step even while paused.
    public mutating func stepOnce() { runner.stepOnce() }
    /// Runs `steps` steps without the clock (replays).
    public mutating func run(steps: Int) { runner.run(steps: steps) }
    /// Stops advancing on frames.
    public mutating func pause() { runner.pause() }
    /// Resumes advancing on frames without catching up paused time.
    public mutating func resume() { runner.resume() }
    /// Applies a command now (live interaction); it is not part of the replay stream.
    public mutating func apply(_ command: SceneCommand) { runner.mutate { $0.apply(command) } }

    /// The force a person placed, if any (feature 034, FR-A04-204). It acts from the next step.
    public private(set) var placedForce: PlacedForce?
    /// Places, moves, changes or removes (nil) the placed force; it occupies force slot 0 ahead of the scene's forces.
    public mutating func setPlacedForce(_ force: PlacedForce?) {
        placedForce = force
        runner.mutate { $0.setPlacedForce(force?.particleForce) }
    }
    /// The current emission ceiling (≤ the scene's particle limit); see `ParticleSystem.liveLimit` (feature 034).
    public var liveLimit: Int { runner.simulation.system.liveLimit }
    /// Sets the emission ceiling (clamped to 1…the scene's particle limit); live particles above it are not removed.
    public mutating func setLiveLimit(_ limit: Int) { runner.mutate { $0.system.liveLimit = limit } }

    /// The steppable state, read-only (tests and diagnostics).
    public var state: SceneState { runner.simulation }

    /// The forces the particles currently feel, in order (placed force, scene forces, family forces).
    public var activeForces: [ParticleForce] { runner.simulation.system.forces }

    /// Whether frames are ignored.
    public var isPaused: Bool { runner.isPaused }
    /// Steps completed.
    public var stepIndex: Int { runner.stepIndex }
    /// Live particles (≤ the scene's particle limit).
    public var liveCount: Int { runner.simulation.system.aliveCount }
    /// Particles not created because the limit was reached.
    public var droppedCount: Int { runner.simulation.system.droppedCount }
    /// Particles removed because their state became NaN or infinite (feature 034: stays 0 for every placed force).
    public var nonFiniteRemoved: Int { runner.simulation.system.nanRemoved }
    /// Commands ignored because their index named nothing suitable.
    public var ignoredCommands: Int { runner.simulation.ignoredCommands }
    /// Frames with an invalid time (NaN, infinite or negative).
    public var invalidFrames: Int { runner.clock.invalidDeltas }
    /// Simulated time lost to the per-frame step cap.
    public var droppedTime: Double { runner.clock.droppedTime }
    /// The particle state's checksum.
    public func checksum() -> UInt64 { runner.simulation.checksum() }
    /// A copy of every live particle for drawing.
    public func instances() -> [ParticleInstance] { runner.simulation.system.instances() }
    /// The first `n` live particles' positions (fixtures).
    public func positions(first n: Int) -> [Vec2] { Array(instances().prefix(max(n, 0)).map(\.position)) }
}
