// SceneModel.swift — the sandbox's observable state over the GPU-free SceneSimulation (feature 033 A04-P01 T-A04-106;
// FR-A04-106; plan "Lifecycle contracts"). The view reads counts and a particle snapshot; drawing never writes back.
// Feature 034 (A04-P02): one placed force (T-A04-207), quality tiers and the live limit (T-A04-211), and the GPU stage
// with the CPU preview as fallback (T-A04-213).
import Foundation
import Observation
import ParticleUniverseCore
import VisualCoreDiagnostics
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

@Observable @MainActor
final class SceneModel {
    /// How the scene is drawn.
    enum RendererMode: Equatable {
        /// VisualCore's render host draws the particles.
        case gpu
        /// The SwiftUI Canvas preview draws them, because the GPU path failed (reason shown in the UI).
        case cpuFallback(String)
    }

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
    /// Particles to draw in the CPU preview, copied after each advance.
    private(set) var particles: [ParticleInstance] = []

    /// The kind a tap or "Center" places (nil = None: no force). Default Attractor (journey 1).
    private(set) var selectedKind: PlacedForceKind? = .attractor
    /// The placed force, if any.
    private(set) var placedForce: PlacedForce?
    /// Strength multiplier for the placed force and future placements (0.1…2).
    private(set) var strength: Double = 1

    /// Quality tiers and the effective particle limit (VisualCore QualityPolicy + ParticleBudget).
    private(set) var quality = SceneQuality()
    /// How the scene is drawn now.
    private(set) var rendererMode: RendererMode = .gpu
    /// The GPU stage (nil in the CPU fallback or before it starts).
    @ObservationIgnored private(set) var stage: ParticleStage?

    @ObservationIgnored private var lastFrame: Date?
    @ObservationIgnored private let conditions: () -> DeviceConditions

    /// Starts with `family` and `seed`; under Reduce Motion the scene starts paused (spec edge cases, CHK017/CHK020).
    /// `hosted: false` skips the GPU stage (unit previews); `conditions` is the quality controller's input.
    init(family: EmitterFamily = .fountain, seed: UInt64 = 1, reduceMotion: Bool, hosted: Bool = true,
         conditions: @escaping () -> DeviceConditions = DeviceConditionsSource.current) {
        self.family = family; self.seed = seed
        self.conditions = conditions
        playback = PlaybackState(reduceMotion: reduceMotion)
        simulation = Self.makeSimulation(family, seed)
        syncSimulation()
        updateQuality()
        if !hosted {
            rendererMode = .cpuFallback("no graphics host")
        } else if DeviceConditionsSource.forcedRendererFailure {
            rendererMode = .cpuFallback("test: GPU disabled")
        } else {
            do {
                stage = try ParticleStage(source: { [weak self] frame in self?.gpuFrame(frame) ?? [] },
                                          onFailure: { [weak self] reason in self?.fallBack(reason) })
            } catch {
                rendererMode = .cpuFallback("graphics could not start: \(error)")
            }
        }
    }

    private static func makeSimulation(_ family: EmitterFamily, _ seed: UInt64) -> SceneSimulation {
        // `single` scenes are always valid (default limit and time scale, one emitter).
        (try? SceneSimulation(scene: .single(family, seed: seed)))!
    }

    // MARK: Text

    var limit: Int { simulation.scene.particleLimit }
    var liveText: String { "Live particles: \(simulation.liveCount) of \(limit)" }
    var droppedText: String { "Dropped: \(simulation.droppedCount)" }
    var effectiveText: String {
        "Effective limit: \(quality.effectiveLimit.formatted()) of \(limit.formatted()) "
            + "(quality tier \(quality.tier + 1) of \(SceneQuality.tierCount))"
    }
    var rendererText: String {
        switch rendererMode {
        case .gpu: "Renderer: GPU"
        case .cpuFallback(let reason): "Renderer: CPU preview (\(reason))"
        }
    }
    var forceText: String {
        guard let f = placedForce else { return "Force: none" }
        return "Force: \(f.kind.title) at (\(Int(f.position.x.rounded())), \(Int(f.position.y.rounded()))), strength \(strengthText)"
    }
    var strengthText: String { "×" + strength.formatted(.number.precision(.fractionLength(1))) }
    /// The stage's spoken description; it changes only with interactions, never per frame (feature 033 lesson).
    var canvasDescription: String {
        let force = placedForce.map { "\($0.kind.title) at \(Int($0.position.x.rounded())), \(Int($0.position.y.rounded())), which \($0.kind.spokenDescription)" } ?? "no force placed"
        return "Particle scene: \(family.title), \(force), \(isPlaying ? "playing" : "paused")."
    }

    // MARK: Family, seed, playback

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

    // MARK: Frames

    /// CPU preview: called for each display frame with its timestamp.
    func frame(at date: Date) {
        defer { lastFrame = date }
        guard rendererMode != .gpu else { return }
        updateQuality()
        guard isPlaying, let last = lastFrame else { return }
        if simulation.advance(frame: date.timeIntervalSince(last)) > 0 { particles = simulation.instances() }
    }

    /// GPU stage: called by the layer scene once per rendered frame; advances while playing (the host's clamped
    /// frame delta) and returns a copy of the particles. While paused it redraws the held state.
    func gpuFrame(_ frame: FrameInfo) -> [ParticleInstance] {
        updateQuality()
        if isPlaying { simulation.advance(frame: frame.delta) }
        return simulation.instances()
    }

    /// One quality decision on the monotonic clock; the effective limit becomes the simulation's live limit.
    private func updateQuality() {
        let limit = quality.update(conditions: conditions(), now: ProcessInfo.processInfo.systemUptime, requested: self.limit)
        if simulation.liveLimit != limit { simulation.setLiveLimit(limit) }
    }

    /// Switches to the CPU preview for the rest of this screen.
    private func fallBack(_ reason: String) {
        guard rendererMode == .gpu else { return }
        rendererMode = .cpuFallback(reason)
        stage?.destroy()
        stage = nil
        particles = simulation.instances()
        lastFrame = nil
    }

    // MARK: Force

    /// Chooses the kind; nil removes the force. A placed force changes kind and keeps its position.
    func selectKind(_ kind: PlacedForceKind?) {
        selectedKind = kind
        guard var f = placedForce else { return }
        if let kind { f.kind = kind; setForce(f) } else { setForce(nil) }
    }

    /// Places the force at `world` (or moves it there), using the selected kind (Attractor when None).
    func place(at world: Vec2) {
        guard world.isFinite else { return }
        if var f = placedForce {
            f.move(to: world)
            setForce(f)
        } else {
            let kind = selectedKind ?? .attractor
            selectedKind = kind
            setForce(PlacedForce(kind: kind, position: world, strength: strength))
        }
    }

    /// A touch on the stage at `point` (view points, top-left origin) in a stage of `size`.
    func touch(at point: CGPoint, in size: CGSize) {
        guard let w = ParticleLayerScene.worldPoint(Vec2(point.x, point.y), viewSize: Vec2(size.width, size.height),
                                                    world: ParticleStage.world) else { return }
        place(at: w)
    }

    /// "Center": places the force (or moves it) at the world center.
    func center() { place(at: .zero) }

    /// Moves the force by (dx, dy) world units, clamped to the world square.
    func nudge(_ dx: Double, _ dy: Double) {
        guard var f = placedForce else { return }
        f.nudge(by: Vec2(dx, dy))
        setForce(f)
    }

    /// Sets the strength multiplier (clamped 0.1…2) for the force and future placements.
    func setStrength(_ s: Double) {
        guard s.isFinite else { return }
        strength = min(max(s, PlacedForce.strengthRange.lowerBound), PlacedForce.strengthRange.upperBound)
        if var f = placedForce { f.setStrength(strength); setForce(f) }
    }

    private func setForce(_ f: PlacedForce?) {
        placedForce = f
        simulation.setPlacedForce(f)
    }

    // MARK: Lifecycle

    /// Background pauses the scene and the host; returning resumes only if the scene was playing.
    func enterBackground() {
        playback.enterBackground()
        syncSimulation()
        stage?.pause()
    }

    func enterForeground() {
        playback.enterForeground()
        syncSimulation()
        stage?.resume()
    }

    /// Releases the GPU stage (the screen went away).
    func tearDown() {
        stage?.destroy()
        stage = nil
    }

    private func rebuild() {
        simulation = Self.makeSimulation(family, seed)
        simulation.setPlacedForce(placedForce)
        particles = []
        syncSimulation()
        updateQuality()
    }
}
