// SceneModel.swift — the sandbox's observable state over the GPU-free SceneSimulation (feature 033 A04-P01 T-A04-106;
// FR-A04-106; plan "Lifecycle contracts"). The view reads counts and a particle snapshot; drawing never writes back.
import Foundation
import Observation
import ParticleUniverseCore
import VisualCoreSimulation

@Observable @MainActor
final class SceneModel {
    /// The chosen family; changing it rebuilds the scene from the seed (no mixing of populations).
    private(set) var family: EmitterFamily
    /// The scene seed; "New seed" moves to the next one deterministically.
    private(set) var seed: UInt64
    /// Play/pause choice and background suspension (VisualCore `PlaybackState`, feature 033 T-A04-115).
    private(set) var playback: PlaybackState
    /// Whether the scene advances on frames now.
    var isPlaying: Bool { playback.isRunning }
    /// The running simulation.
    private(set) var simulation: SceneSimulation
    /// Particles to draw, copied after each advance.
    private(set) var particles: [ParticleInstance] = []

    @ObservationIgnored private var lastFrame: Date?

    /// Starts with `family` and `seed`; under Reduce Motion the scene starts paused (spec edge cases, CHK017).
    init(family: EmitterFamily = .fountain, seed: UInt64 = 1, reduceMotion: Bool) {
        self.family = family; self.seed = seed
        playback = PlaybackState(reduceMotion: reduceMotion)
        simulation = Self.makeSimulation(family, seed)
        syncSimulation()
    }

    private static func makeSimulation(_ family: EmitterFamily, _ seed: UInt64) -> SceneSimulation {
        // `single` scenes are always valid (default limit and time scale, one emitter).
        (try? SceneSimulation(scene: .single(family, seed: seed)))!
    }

    var limit: Int { simulation.scene.particleLimit }
    var liveText: String { "Live particles: \(simulation.liveCount) of \(limit)" }
    var droppedText: String { "Dropped: \(simulation.droppedCount)" }
    var canvasDescription: String {
        "Particle preview: \(family.title), \(simulation.liveCount) particles, \(isPlaying ? "playing" : "paused")."
    }

    /// Chooses another family and restarts the scene.
    func select(_ family: EmitterFamily) {
        guard family != self.family else { return }
        self.family = family
        rebuild()
    }

    /// Moves to the next seed and restarts the scene.
    func reseed() {
        seed = seed &+ 0x9E37_79B9_7F4A_7C15
        rebuild()
    }

    /// Plays or pauses; resuming never catches up the paused time.
    func setPlaying(_ playing: Bool) {
        if playing { playback.play() } else { playback.pause() }
        syncSimulation()
    }

    /// Mirrors `playback.isRunning` into the simulation; resuming discards accumulated time.
    private func syncSimulation() {
        if playback.isRunning { simulation.resume() } else { simulation.pause() }
        lastFrame = nil
    }

    /// One fixed step (for the Step control while paused).
    func step() {
        simulation.stepOnce()
        particles = simulation.instances()
    }

    /// Called for each display frame with its timestamp.
    func frame(at date: Date) {
        defer { lastFrame = date }
        guard isPlaying, let last = lastFrame else { return }
        if simulation.advance(frame: date.timeIntervalSince(last)) > 0 { particles = simulation.instances() }
    }

    /// Background pauses; returning resumes only if the scene was playing.
    func enterBackground() {
        playback.enterBackground()
        syncSimulation()
    }

    func enterForeground() {
        playback.enterForeground()
        syncSimulation()
    }

    private func rebuild() {
        simulation = Self.makeSimulation(family, seed)
        particles = []
        syncSimulation()
    }
}
