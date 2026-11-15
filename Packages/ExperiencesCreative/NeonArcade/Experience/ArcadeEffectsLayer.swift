// ArcadeEffectsLayer — feature 077 (A10-P03) T-A10-304 (FR-A10-320, FR-A10-321; SC-A10-304; clarifications 3 and 4;
// research D4; edge cases "many events in one step", "pausing during a burst"). The visual effects, sounds and
// haptics of Neon Arcade, derived by the presenter from the run it last drew and the run it draws now with
// `ArcadeEffects.plan(previous:current:)`; nothing here changes the game, and the presenter never hands a value back
// to the core.
//   - Particle bursts: one `ParticleSystem` of 256 particles, seeded with a fixed value (the same draws give the same
//     bursts), with three emitter slots per colour (the plan starts at most three visual cues per step): a pickup is a
//     burst of 16 cyan particles at the orb's position, a hit 24 red particles at the player; each lives 0.4 s. The
//     pool advances by the game steps between two drawn runs (1/60 s each, at most `maxCatchUpSteps` per draw), so
//     a paused or suspended game freezes its particles. A new run (fewer steps or fewer events than the last drawn
//     one, as after a restart or a restore) clears every effect.
//   - A hit also starts a red ring expanding from the player's hit radius 0.4 to 1.6 units over 0.3 s (18 steps), and
//     a full-field red tint of alpha 0.25 for 6 steps unless reduced flashing is on, which keeps only the ring (a
//     non-flashing outline).
//   - A new wave starts a horizontal cyan sweep line from the top of the field to the bottom over 0.5 s (30 steps).
//   - Sounds go to an `ArcadeSoundSink` (by default `ArcadeSoundPlayer`, VisualCore's `SoundEffectPlayer` with each
//     `ArcadeSound` as a `SoundEffect` whose buffer id is the sound's id) only while the state's sound setting is on;
//     haptics go through the host's `ExperienceFeedback` (which also honours the person's system-wide switch) only
//     while the haptics setting is on. The plan's caps (3 visual and 2 sound cues per step) hold here unchanged.
// The effect nodes sit in the presenter's back layer, which is drawn before the particles and both before the
// glows, objects, player and HUD: the collision shapes are always drawn above every effect.
import Foundation
import NeonArcadeCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

/// Where Neon Arcade's sounds go: the system player in the app, a recorder in tests.
@MainActor
protocol ArcadeSoundSink: AnyObject {
    /// Plays `sound` now.
    func play(_ sound: ArcadeSound)
    /// Stops every sound that is playing.
    func stopAll()
}

/// The default sound sink: VisualCore's `SoundEffectPlayer` (ambient session, four voices), created on the first play.
@MainActor
final class ArcadeSoundPlayer: ArcadeSoundSink {
    private var player: SoundEffectPlayer?

    /// `sound` as a VisualCore sound effect; nil for an unknown waveform name.
    nonisolated static func effect(_ sound: ArcadeSound) -> SoundEffect? {
        guard let waveform = SoundWaveform(rawValue: sound.waveform) else { return nil }
        return SoundEffect(waveform: waveform, startFrequency: sound.startFrequency, endFrequency: sound.endFrequency,
                           duration: sound.duration, attack: sound.attack, release: sound.release, noise: sound.noise,
                           gain: sound.gain)
    }

    func play(_ sound: ArcadeSound) {
        guard let effect = Self.effect(sound) else { return }
        let player = self.player ?? SoundEffectPlayer()
        self.player = player
        player.play(effect, id: sound.id)
    }

    func stopAll() {
        player?.stopAll()
    }
}

/// The effect state of the presenter (see the file header): particles, rings, tint and sweep, advanced by game steps.
@MainActor
final class ArcadeEffectsLayer {
    /// The particle pool's size.
    nonisolated static let particleCapacity = 256
    /// The particle pool's fixed seed.
    nonisolated static let particleSeed: UInt64 = 0xA10_0077
    /// The emitter slots per colour (the plan starts at most three visual cues per step).
    nonisolated static let slots = ArcadeEffects.maxVisualCues
    /// The particles of a pickup burst and of a hit burst.
    nonisolated static let pickupParticles = 16, hitParticles = 24
    /// The life of a particle in seconds.
    nonisolated static let particleLife = 0.4
    /// A particle's start diameter in game units.
    nonisolated static let particleSize = 0.16
    /// The colour of a pickup burst: cyan.
    nonisolated static let pickupColor = Vec4(0.2, 0.95, 1.0, 0.9)
    /// The colour of a hit burst, ring, tint and outline: red.
    nonisolated static let hitColor = Vec4(1.0, 0.22, 0.32, 0.9)
    /// The colour of the wave sweep: cyan.
    nonisolated static let sweepColor = Vec4(0.2, 0.95, 1.0, 0.7)
    /// The hit ring's length in steps (0.3 s) and its radius at the start and at the end in game units.
    nonisolated static let ringSteps = 18, ringStartRadius = PlayerState.hitRadius, ringEndRadius = 1.6
    /// The hit ring's line width in game units.
    nonisolated static let ringWidth = 0.08
    /// The most hit rings shown at once.
    nonisolated static let maxRings = 3
    /// The full-field tint's alpha and length in steps.
    nonisolated static let tintAlpha = 0.25, tintSteps = 6
    /// The wave sweep's length in steps (0.5 s) and its line width in game units.
    nonisolated static let sweepSteps = 30, sweepWidth = 0.06
    /// The most game steps the particles advance in one draw (the host runs at most 8 steps per frame).
    nonisolated static let maxCatchUpSteps = 30

    /// Whether reduced flashing is on: a hit keeps only its ring (no full-field tint).
    let reduceFlashing: Bool
    /// The particle pool.
    private(set) var particles: ParticleSystem
    /// The active hit rings: centre (game units) and the step they started at.
    private(set) var rings: [(center: Vec2, start: Int)] = []
    /// The step the full-field tint started at, nil when none is active.
    private(set) var tintStart: Int?
    /// The step the wave sweep started at, nil when none is active.
    private(set) var sweepStart: Int?
    /// The step the effects were last advanced to.
    private(set) var currentStep = 0
    /// The run the effects were last advanced to.
    private(set) var lastRun: GameRun?
    /// The cues of the last advance.
    private(set) var lastCues: [EffectCue] = []
    /// The bursts started since the layer was made (tests).
    private(set) var burstCount = 0

    /// The ring nodes, the tint node and the sweep node (in the presenter's back layer).
    private(set) var ringNodes: [SceneNode] = []
    let tint: SceneNode
    let sweep: SceneNode

    /// A layer whose nodes have the z `z`.
    init(reduceFlashing: Bool, z: Int) {
        self.reduceFlashing = reduceFlashing
        particles = ArcadeEffectsLayer.makeParticles()
        for index in 0..<Self.maxRings { ringNodes.append(SceneNode(id: "effect.ring\(index)", z: z)) }
        tint = SceneNode(id: "effect.tint", z: z)
        sweep = SceneNode(id: "effect.sweep", z: z)
    }

    /// The nodes to add to the back layer.
    var nodes: [SceneNode] { [tint, sweep] + ringNodes }

    /// An empty pool with the six emitters: slots 0…2 cyan (pickup), 3…5 red (hit); none emits on its own.
    nonisolated static func makeParticles() -> ParticleSystem {
        var system = ParticleSystem(capacity: particleCapacity, seed: particleSeed)
        for slot in 0..<(2 * slots) {
            let color = slot < slots ? pickupColor : hitColor
            var emitter = Emitter(rate: 0, lifetime: particleLife...particleLife, speed: 1.5...3.5,
                                  startSize: particleSize, endSize: 0, startColor: color,
                                  endColor: Vec4(color.x, color.y, color.z, 0))
            emitter.isEmitting = false
            system.emitters.append(emitter)
        }
        system.forces = [.drag(2.5)]
        return system
    }

    /// Forgets every effect (a new run, a restore).
    func clear() {
        particles = Self.makeParticles()
        rings = []
        tintStart = nil
        sweepStart = nil
    }

    /// Advances the effects to `run`: the plan of the change since the last run starts its visual cues, then the
    /// particles advance by the game steps in between (none while paused). Returns the cues (with their sounds and
    /// haptics, which the presenter plays as the settings allow).
    func advance(to run: GameRun) -> [EffectCue] {
        let continues = lastRun.map { run.step >= $0.step && run.eventCount >= $0.eventCount } ?? false
        let delta = continues ? run.step - (lastRun?.step ?? run.step) : 0
        if !continues, lastRun != nil { clear() }
        let cues = ArcadeEffects.plan(previous: lastRun, current: run)
        lastRun = run
        currentStep = run.step
        var slot = 0
        for cue in cues where cue.visual {
            defer { slot += 1 }
            switch cue.kind {
            case .pickup:
                particles.emitters[slot].position = cue.position
                particles.burst(Self.pickupParticles, from: slot)
                burstCount += 1
            case .hit:
                particles.emitters[Self.slots + slot].position = cue.position
                particles.burst(Self.hitParticles, from: Self.slots + slot)
                burstCount += 1
                rings.append((cue.position, run.step))
                if rings.count > Self.maxRings { rings.removeFirst(rings.count - Self.maxRings) }
                if !reduceFlashing { tintStart = run.step }
            case .wave:
                sweepStart = run.step
            case .over:
                break
            }
        }
        for _ in 0..<min(delta, Self.maxCatchUpSteps) { particles.step(GameSimulation.step) }
        rings.removeAll { run.step - $0.start >= Self.ringSteps }
        if let start = tintStart, run.step - start >= Self.tintSteps { tintStart = nil }
        if let start = sweepStart, run.step - start >= Self.sweepSteps { sweepStart = nil }
        lastCues = cues
        return cues
    }

    /// The tint's alpha now: 0.25 while a tint is active, 0 otherwise (always 0 under reduced flashing).
    var tintAlphaNow: Double { tintStart == nil ? 0 : Self.tintAlpha }

    /// The progress 0…1 of an effect of `steps` steps that started at `start`.
    private func progress(_ start: Int, steps: Int) -> Double {
        min(max(Double(currentStep - start) / Double(steps), 0), 1)
    }

    /// The radius of a ring that started at `start`, in game units.
    func ringRadius(start: Int) -> Double {
        Self.ringStartRadius + (Self.ringEndRadius - Self.ringStartRadius) * progress(start, steps: Self.ringSteps)
    }

    /// The y of the sweep line in game units, nil when no sweep is active.
    var sweepY: Double? {
        sweepStart.map { GameRun.fieldHeight * (1 - progress($0, steps: Self.sweepSteps)) }
    }

    /// The live particles in game units.
    var instances: [ParticleInstance] { particles.instances() }

    /// Whether an effect lies within `margin` game units of `point` (the frame probe steps aside for it).
    func touches(_ point: Vec2, margin: Double) -> Bool {
        for ring in rings where (ring.center - point).length < ringRadius(start: ring.start) + Self.ringWidth + margin {
            return true
        }
        if let y = sweepY, abs(y - point.y) < Self.sweepWidth + margin { return true }
        return instances.contains { ($0.position - point).length < $0.size + margin }
    }

    /// Places the ring, tint and sweep nodes for the field mapping `world` (game units → world) at `scale` pixels per
    /// unit; `fieldCenter` and `fieldSize` are the field rectangle in world units.
    func layOut(world: (Vec2) -> Vec2, scale: Double, fieldCenter: Vec2, fieldSize: Vec2) {
        func px(_ units: Double) -> Double { max(units * scale, 1) }
        for (index, node) in ringNodes.enumerated() {
            guard index < rings.count else { node.primitive = nil; continue }
            let ring = rings[index]
            let t = progress(ring.start, steps: Self.ringSteps)
            node.primitive = .polyline(ArcadePresenter.ring(center: ring.center, radius: ringRadius(start: ring.start))
                .map(world), width: px(Self.ringWidth))
            node.color = ArcadePresenter.faded(Self.hitColor, 1 - t)
        }
        if tintStart != nil {
            tint.primitive = .rect(fieldSize)
            tint.position = fieldCenter
            tint.color = Vec4(Self.hitColor.x, Self.hitColor.y, Self.hitColor.z, Self.tintAlpha)
        } else {
            tint.primitive = nil
        }
        if let y = sweepY, let start = sweepStart {
            let t = progress(start, steps: Self.sweepSteps)
            sweep.primitive = .line(world(Vec2(0, y)), world(Vec2(GameRun.fieldWidth, y)), width: px(Self.sweepWidth))
            sweep.color = ArcadePresenter.faded(Self.sweepColor, 1 - t)
        } else {
            sweep.primitive = nil
        }
    }
}
