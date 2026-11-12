// SceneModel.swift — the sandbox's observable state over the GPU-free SceneSimulation (feature 033 A04-P01 T-A04-106;
// FR-A04-106; plan "Lifecycle contracts"). The view reads counts and a particle snapshot; drawing never writes back.
// Feature 034 (A04-P02): one placed force (T-A04-207), quality tiers and the live limit (T-A04-211), and the GPU stage
// with the CPU preview as fallback (T-A04-213).
// Feature 035 (A04-P03): several emitters with per-emitter size, lifetime and gradient (T-A04-308, T-A04-310), and
// trails, blend and the Reduce Flashing brightness cap on the GPU stage (T-A04-312).
import Foundation
import Observation
import ParticleUniverseCore
import VisualCoreDiagnostics
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreUI

@Observable @MainActor
final class SceneModel {
    /// How the scene is drawn.
    enum RendererMode: Equatable {
        /// VisualCore's render host draws the particles.
        case gpu
        /// The SwiftUI Canvas preview draws them, because the GPU path failed (reason shown in the UI).
        case cpuFallback(String)
    }

    /// The visible emitter the family picker and the overrides edit (index into `simulation.visibleEmitters`).
    private(set) var selectedEmitter = 0
    /// The selected emitter's family.
    var family: EmitterFamily { selectedEntry.family }
    /// The visible emitters, cached so views holding controls never read per-frame simulation state (feature 033
    /// lesson: a rebuild every frame swallowed picker taps). Updated by `syncEmitters()` only when it changes.
    private(set) var emitters: [SceneEmitter] = []
    /// Whether another emitter fits now (changes as removed emitters' particles fade); cached like `emitters`.
    private(set) var canAddEmitter = true
    /// The selected emitter's scene entry.
    var selectedEntry: SceneEmitter { emitters[min(max(selectedEmitter, 0), emitters.count - 1)] }

    /// Copies the emitter list and the add flag from the simulation, assigning only on change.
    private func syncEmitters() {
        let v = simulation.visibleEmitters
        if v != emitters { emitters = v }
        let can = simulation.canAddEmitter
        if can != canAddEmitter { canAddEmitter = can }
    }
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
    /// Accessibility change observers (Reduce Flashing follows the system while the screen is open; T-A04-316).
    @ObservationIgnored private var accessibilityTokens: [NSObjectProtocol] = []
    @ObservationIgnored private let conditions: () -> DeviceConditions

    /// Starts with `family` and `seed`; under Reduce Motion the scene starts paused (spec edge cases, CHK017/CHK020).
    /// `hosted: false` skips the GPU stage (unit previews); `conditions` is the quality controller's input.
    init(family: EmitterFamily = .fountain, seed: UInt64 = 1, reduceMotion: Bool, hosted: Bool = true,
         conditions: @escaping () -> DeviceConditions = DeviceConditionsSource.current) {
        self.seed = seed
        self.conditions = conditions
        playback = PlaybackState(reduceMotion: reduceMotion)
        simulation = Self.makeSimulation(family, seed)
        emitters = simulation.visibleEmitters
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
        refreshAccessibility()
        accessibilityTokens = SystemAccessibilityObserver.changeNotifications.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshAccessibility() }
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

    /// Changes the selected emitter's family, keeping its position and overrides; the scene keeps running (feature
    /// 035, spec edge cases CHK017).
    func select(_ family: EmitterFamily) {
        guard family != self.family else { return }
        var e = selectedEntry
        e.family = family
        simulation.setEmitter(at: selectedEmitter, e)
        syncEmitters()
    }

    // MARK: Emitters (feature 035)

    /// "Emitter 1" … "Emitter N".
    var emitterTitles: [String] { emitters.indices.map { "Emitter \($0 + 1)" } }
    var emittersText: String {
        let n = emitters.count
        let waiting = !canAddEmitter && n < ParticleScene.maxEmitters ? " — waiting for removed emitters to fade" : ""
        return "Emitters: \(n) of \(ParticleScene.maxEmitters)\(waiting)"
    }
    var canRemoveEmitter: Bool { emitters.count > 1 }

    /// Selects the visible emitter at `index`.
    func selectEmitter(_ index: Int) {
        selectedEmitter = min(max(index, 0), emitters.count - 1)
    }

    /// Adds an emitter of the selected family beside the others and selects it.
    func addEmitter() {
        let f = family
        let k = emitters.count
        guard simulation.addEmitter(SceneEmitter(family: f, position: SceneSimulation.placement(of: f, index: k))) else { return }
        syncEmitters()
        selectedEmitter = emitters.count - 1
    }

    /// Removes the selected emitter (never the last); its particles fade out and the previous one is selected.
    func removeEmitter() {
        guard simulation.removeEmitter(at: selectedEmitter) else { return }
        selectedEmitter = max(0, selectedEmitter - 1)
        syncEmitters()
    }

    // MARK: Overrides (feature 035)

    /// The selected emitter's start diameter (its override or the family's).
    var size: Double { selectedEntry.size ?? family.emitter().startSize }
    /// The selected emitter's lifetime (its override or the middle of the family's range).
    var lifetime: Double {
        selectedEntry.lifetime ?? { let r = family.emitter().lifetime; return (r.lowerBound + r.upperBound) / 2 }()
    }
    /// The selected emitter's gradient palette id (nil = family colors).
    var gradient: String? { selectedEntry.gradient }
    var sizeText: String { "\(Int(size.rounded())) points" }
    var lifetimeText: String { lifetime.formatted(.number.precision(.fractionLength(1))) + " seconds" }

    func setSize(_ v: Double) { editSelected { $0.size = SceneEmitter.clampedSize(v) ?? $0.size } }
    func setLifetime(_ v: Double) { editSelected { $0.lifetime = SceneEmitter.clampedLifetime(v) ?? $0.lifetime } }
    func setGradient(_ id: String?) { editSelected { $0.gradient = id } }

    private func editSelected(_ edit: (inout SceneEmitter) -> Void) {
        var e = selectedEntry
        edit(&e)
        guard e != selectedEntry else { return }
        simulation.setEmitter(at: selectedEmitter, e)
        syncEmitters()
    }

    // MARK: Trails (feature 035)

    /// Trails on or off.
    private(set) var trailsOn = false
    /// Trail strength 0…0.98 (fraction kept per 1/60 s), default 0.85.
    private(set) var trailStrength = 0.85
    /// Normal or additive particle blending.
    private(set) var blend: ParticleBlend = .normal
    /// Reduce Flashing (system setting, VisualCore preferences, or the DEBUG seam): caps brightness at 0.6.
    private(set) var reduceFlashing = false
    var trailsAvailable: Bool { rendererMode == .gpu }
    var trailStrengthText: String { "\(Int((trailStrength * 100).rounded())) percent" }
    var trailNote: String? {
        var notes: [String] = []
        if !trailsAvailable { notes.append("Trails need the GPU renderer") }
        if reduceFlashing { notes.append("Brightness limited (Reduce Flashing)") }
        return notes.isEmpty ? nil : notes.joined(separator: ". ")
    }

    func setTrails(_ on: Bool) {
        guard trailsAvailable else { return }
        trailsOn = on
        if !on { stage?.scene.clearTrails() }
        applyRenderSettings()
    }

    func setTrailStrength(_ s: Double) {
        guard s.isFinite else { return }
        trailStrength = TrailDecay.clampedStrength(s)
        applyRenderSettings()
    }

    func setBlend(_ b: ParticleBlend) {
        blend = b
        applyRenderSettings()
    }

    /// Re-reads Reduce Flashing (system flags through VisualCore's preferences, or the DEBUG seam).
    func refreshAccessibility() {
        reduceFlashing = AccessibilityPreferences().resolve(SystemAccessibilityObserver.systemValues()).reduceFlashing
            || DeviceConditionsSource.forcedReduceFlashing
        applyRenderSettings()
    }

    /// Pushes trails, blend and the brightness cap into the GPU stage's layer scene.
    private func applyRenderSettings() {
        guard let scene = stage?.scene else { return }
        scene.trailStrength = trailsOn ? trailStrength : 0
        scene.blend = blend
        scene.brightnessCap = reduceFlashing ? 0.6 : 1
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
        if emitters.count < ParticleScene.maxEmitters, !canAddEmitter || simulation.retiredSlots > 0 { syncEmitters() }
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
        refreshAccessibility()
        playback.enterForeground()
        syncSimulation()
        stage?.resume()
    }

    /// Releases the GPU stage (the screen went away).
    func tearDown() {
        accessibilityTokens.forEach { NotificationCenter.default.removeObserver($0) }
        accessibilityTokens = []
        stage?.destroy()
        stage = nil
    }

    private func rebuild() {
        let scene = simulation.rebuildScene(seed: seed)
        simulation = (try? SceneSimulation(scene: scene)) ?? Self.makeSimulation(.fountain, seed)
        simulation.setPlacedForce(placedForce)
        selectedEmitter = min(selectedEmitter, simulation.visibleEmitters.count - 1)
        syncEmitters()
        particles = []
        stage?.scene.clearTrails()
        syncSimulation()
        updateQuality()
    }
}
