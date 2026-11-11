// SceneSimulation.swift — a validated scene running on VisualCore's ParticleSystem and FixedStepRunner (feature 033
// A04-P01 T-A04-108; FR-A04-103–FR-A04-105; research R5, R6). Fixed step 1/120 s, at most 8 steps per frame; the time
// scale multiplies frame time only, so replays stay deterministic.
import VisualCoreMath
import VisualCoreSimulation

/// The steppable state: the particle system plus the bookkeeping commands need.
public struct SceneState: FixedStepSimulation, Sendable {
    /// The particle pool (scene forces first, then the families' forces).
    public internal(set) var system: ParticleSystem
    /// Number of scene forces at the start of `system.forces` (the indices `moveAttractor` may address).
    public let sceneForceCount: Int
    /// Commands ignored because their index named nothing suitable.
    public internal(set) var ignoredCommands = 0

    /// Advances the particle system.
    public mutating func step(_ dt: Double) { system.step(dt) }
    /// The particle system's checksum.
    public func checksum() -> UInt64 { system.checksum() }

    /// Applies one command (ignoring and counting invalid ones).
    public mutating func apply(_ command: SceneCommand) {
        switch command {
        case .moveAttractor(let index, let x, let y):
            guard index >= 0, index < sceneForceCount, x.isFinite, y.isFinite,
                  case .attractor(_, let s, let r) = system.forces[index] else { ignoredCommands += 1; return }
            system.forces[index] = .attractor(point: Vec2(x, y), strength: s, radius: r)
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
        system.forces = scene.forces.map(\.particleForce) + scene.emitters.flatMap { $0.family.forces() }
        let state = SceneState(system: system, sceneForceCount: scene.forces.count)
        runner = FixedStepRunner(simulation: state, clock: FixedStepClock(step: Self.step, maxSteps: Self.maxStepsPerFrame),
                                 stream: ControlStream(controls)) { state, command in state.apply(command) }
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

    /// Whether frames are ignored.
    public var isPaused: Bool { runner.isPaused }
    /// Steps completed.
    public var stepIndex: Int { runner.stepIndex }
    /// Live particles (≤ the scene's particle limit).
    public var liveCount: Int { runner.simulation.system.aliveCount }
    /// Particles not created because the limit was reached.
    public var droppedCount: Int { runner.simulation.system.droppedCount }
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
