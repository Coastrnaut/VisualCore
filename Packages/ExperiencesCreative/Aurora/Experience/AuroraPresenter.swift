// AuroraPresenter — feature 153 (A21-P02) T-A21-203, T-A21-206 (FR-A21-201, FR-A21-203–205, FR-A21-207;
// clarifications Q2–Q4; contracts/experience.md); feature 154 (A21-P03) T-A21-302, T-A21-305, T-A21-306
// (FR-A21-301–306; clarifications Q1, Q3–Q5; data-model.md). Draws Aurora through the host only and owns its
// presentation state:
//
//   - Scene: a ``SkyTransition``: one moving sky (`FullScreenShaderScene` of `aurora-sky.frag`, the `vc/` library
//     through an empty `ShaderBundle`), and during a change of preset a `CrossfadeScene` of the outgoing and the
//     incoming sky. `setup` sets it up (again after a context recreation, when the host calls `setup` again; the
//     clock, the blend and a running change are not GPU objects and stay, so the picture is the same). A resize
//     passes the new size on. A compile or link error throws `SkyShaderError` with the shader's message.
//   - Draw: the target inputs follow the core (`SkyInputs` of the scene with the hue shift). A preset change starts
//     the 2.0 s crossfade (smoothstep over drawn-frame time; both skies move, each under the limit); a new choice
//     during a change restarts it from the current mix. A control moved within one sky goes through the A21-P02
//     input blend (`SkyBlend`, retargeted: at once when no blend runs). Under Reduce Motion every change is
//     immediate. Each draw advances the `SkyClock` (the scene's speed; held under Reduce Motion) and the change by
//     the frame's delta, then draws once. An off-screen still (delta 0) shows the sky as it is. `maxFramesPerSecond`
//     30.
//   - Preferences (`SkyPreferences`, the experience value `prefs.v1`): read when the presenter is made, before the
//     first frame. A fresh open is seeded from them at the first draw through the port (the sky's actions; a refused
//     send is tried again at the next draw); a state restored from a session snapshot (`SkyCore.isRestored`) wins
//     for the sky and is not seeded. The sound choice (on/off, volume) always comes from the preferences: it is not
//     in the core, the snapshot or the digest, and no lifecycle call (teardown, setup, context recreation, resize,
//     suspend, resume) reads or writes it. The preferences are written after every accepted change of the sky (not
//     for the restore itself) and of the sound choice. A damaged, newer or out-of-range value opens with the
//     defaults, keeps its refusal (`preferencesRefusal`) and shows ``readFailedMessage``; the defaults are saved over
//     it only after the next accepted change. A failed save shows ``saveFailedMessage`` once and the choices stay
//     in memory. Nothing plays (the sound comes in A21-P05).
//   - Chrome: `controlsHidden` (presentation only, not in the snapshot or the digest). `hideControls()` hides the
//     controls; a tap on the sky (a touch that lifts within ``tapSlop`` points of where it landed) or the
//     accessibility action "Show controls" (`showControls()`) brings them back. The tap sends no action, so the
//     canvas has no gesture action (`gestureActions` is empty) and every action is a native control's.
//   - Words: the canvas label names the preset, the colour shift, the speed, the ribbons, the stars, the clouds and
//     the brightness limit. Probes: the bottom-leading corner is the dark sky below the ribbons (`dark`).
//
// No GL call: everything is drawn through VisualCoreRendering's scenes.
import Foundation
import AuroraCore
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// A sky shader that failed to build (feature 153): the shader's message.
struct SkyShaderError: Error, Equatable, CustomStringConvertible {
    /// The compiler's or linker's message, naming `aurora-sky.frag`.
    let message: String

    /// "The Aurora sky shader failed: <message>".
    var description: String { "The Aurora sky shader failed: " + message }
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class SkyMirror {
    /// The preset's index in `SkyPresets.all`.
    var preset = 0
    /// The hue shift in turns.
    var hue = 0.0
    /// The speed (0…2).
    var speed = SkyPresets.defaultPreset.scene.speed
    /// The turbulence (0…1).
    var turbulence = SkyPresets.defaultPreset.scene.turbulence
    /// The ribbon count (1…4).
    var ribbons = SkyPresets.defaultPreset.scene.ribbons
    /// The star count (0…400).
    var stars = SkyPresets.defaultPreset.scene.stars
    /// The cloudiness (0…1).
    var clouds = SkyPresets.defaultPreset.scene.cloudiness
    /// The brightness limit (0.2…0.72).
    var limit = SkyCore.defaultLimit
    /// Whether the controls are hidden (presentation only).
    var controlsHidden = false
    /// Whether the sound is on (the preferences only; nothing plays in this phase).
    var soundOn = SkyPreferences.defaults.soundOn
    /// The sound volume (0…1; the preferences only).
    var volume = SkyPreferences.defaults.volume
    /// The message about the saved choices; nil when there is none.
    var message: String?
}

/// Draws Aurora and owns its presentation state (see the file header).
@MainActor
final class AuroraPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = SkyCore

    /// How far, in view points, a finger may move and still tap.
    static let tapSlop = 10.0

    /// Whether Reduce Motion is on: the sky holds still and every change is immediate.
    var reduceMotion: Bool
    /// What the controls show.
    let mirror = SkyMirror()
    /// The port of the shell, for the controls; set by the factory.
    var port: ExperienceActionPort?
    /// The message shown when the saved choices could not be read (damaged, newer or out of range).
    static let readFailedMessage = "Your saved choices could not be read, so the default sky is shown."
    /// The message shown once when the choices could not be saved.
    static let saveFailedMessage = "Your choices could not be saved."

    /// The skies drawn and the change between presets (see ``SkyTransition``).
    let transition = SkyTransition()
    /// The scene of the sky shown (the incoming sky during a change); nil while not set up.
    var scene: FullScreenShaderScene? { transition.isSetUp ? transition.sky.shader : nil }
    /// How many times `setup` set the skies up.
    private(set) var setupCount = 0
    /// The launch's storage, which keeps the preferences as `prefs.v1`; nil without storage.
    let storage: ExperienceStorage?
    /// The person's choices: read from `prefs.v1` when made (the defaults without storage, without the value or for a
    /// refused value), updated after every accepted change.
    private(set) var preferences: SkyPreferences
    /// Why the saved preferences were refused when the presenter was made; nil when they were read or absent.
    let preferencesRefusal: PreferencesRefusal?
    /// Whether a failed save was reported (it is reported once).
    private(set) var saveFailureReported = false
    /// How many saves were refused by the storage.
    private(set) var failedSaves = 0
    /// Whether the saved sky still has to be sent to a fresh state (at the first draw).
    private(set) var seedPending: Bool
    /// True while the saved sky is being sent, so the seeding itself writes nothing.
    private var seeding = false
    /// The shell's current core, for the seeding; set by the factory.
    var coreSource: (() -> SkyCore?)?
    /// The sky's animation clock, advanced by frame deltas.
    private(set) var clock = SkyClock()
    /// The change between skies.
    private(set) var blend = SkyBlend(SkyInputs(scene: SkyPresets.defaultPreset.scene, hue: 0))
    /// The last core drawn or followed.
    private(set) var lastCore = SkyCore()
    /// Whether a core was followed yet (the first is shown at once).
    private var followed = false
    /// The uniforms of the last frame drawn (the incoming sky during a change); nil before one.
    private(set) var lastUniforms: SkyUniforms?
    /// The uniforms of the moving outgoing sky in the last frame drawn; nil without one.
    private(set) var lastOutgoingUniforms: SkyUniforms?
    /// The mix drawn in the last frame (0 = the outgoing picture, 1 = the incoming); nil without a change.
    private(set) var lastMix: Double?
    /// The touches on the canvas: where each landed, in view points.
    private var touches: [Int: Vec2] = [:]
    /// The frame cap: 30 frames per second (the sky moves slowly).
    var maxFramesPerSecond: Int { 30 }

    /// A presenter; with `reduceMotion` on the sky holds still and changes are immediate. The preferences are read
    /// from `storage`'s value `prefs.v1` now, before the first frame (see the file header).
    init(reduceMotion: Bool = false, storage: ExperienceStorage? = nil) {
        self.reduceMotion = reduceMotion
        self.storage = storage
        clock.reducedMotion = reduceMotion
        let read = Self.keptPreferences(storage)
        preferences = read.preferences
        preferencesRefusal = read.refusal
        seedPending = storage != nil && read.refusal == nil && read.preferences != SkyPreferences.defaults
        mirror.soundOn = preferences.soundOn
        mirror.volume = preferences.volume
        if read.refusal != nil { mirror.message = Self.readFailedMessage }
    }

    /// The preferences kept in `storage` as `prefs.v1` with the refusal of a value that could not be read: the
    /// defaults (and no refusal) without storage or without the value.
    static func keptPreferences(_ storage: ExperienceStorage?) -> (preferences: SkyPreferences,
                                                                   refusal: PreferencesRefusal?) {
        guard let data = storage?.value(for: SkyPreferences.storageKey) else { return (.defaults, nil) }
        switch SkyPreferences.decode(data) {
        case .success(let kept): return (kept, nil)
        case .failure(let refusal): return (.defaults, refusal)
        }
    }

    // MARK: Render scene

    /// Sets up the skies (the crossfade of a running change, or the sky alone), again after a context recreation; a
    /// build error throws ``SkyShaderError``. The preferences and the sound choice are not touched.
    func setup(_ context: RenderContext) throws {
        try transition.setup(context)
        setupCount += 1
    }

    /// Passes the new drawable size to the skies.
    func resize(_ context: RenderContext) {
        transition.resize(context)
    }

    /// Seeds a fresh state from the preferences (once), follows `core`, starts, restarts, advances or ends the change
    /// between presets and draws the sky (or the mix of both skies) once at `tier`.
    func draw(_ core: SkyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        var core = core
        if seedPending, seedPreferences(core) { core = coreSource?() ?? core }
        follow(core)
        guard transition.isSetUp else { return }
        clock.reducedMotion = reduceMotion
        clock.speed = core.scene.speed
        clock.advance(by: frame.delta)
        if reduceMotion {
            blend.finish()
        } else {
            blend.advance(by: frame.delta)
        }
        if let shown = transition.sky.preset, shown != core.scene.preset {
            if reduceMotion {
                transition.finish(context)
            } else {
                try transition.begin(limit: core.limit, context: context)
            }
        } else if transition.isChanging {
            if reduceMotion { transition.finish(context) }
            transition.advance(by: frame.delta)
        }
        if let still = transition.stillLimit, core.limit < still { transition.finish(context) }
        if transition.isChanging, transition.progress >= 1 { transition.finish(context) }
        let uniforms = blend.current.uniforms(phase: clock.phase, level: tier, limit: core.limit)
        let outgoing = transition.outgoing?.inputs?.uniforms(phase: clock.phase, level: tier, limit: core.limit)
        try transition.render(context, frame: frame, incoming: blend.current, uniforms: uniforms,
                              preset: core.scene.preset, outgoingUniforms: outgoing, time: clock.time)
        lastUniforms = uniforms
        lastOutgoingUniforms = transition.isChanging ? outgoing : nil
        lastMix = transition.isChanging ? transition.eased : nil
    }

    /// Releases the skies' GPU objects; a running change, the clock and the preferences stay.
    func teardown(_ context: RenderContext) {
        transition.teardown(context)
    }

    // MARK: Preferences

    /// Sends the saved sky to a fresh state through the port (the preset first, then each value that differs); a
    /// state restored from a snapshot is left as it is. Returns whether anything was accepted. A refused send (the
    /// experience is not active) is tried again at the next draw.
    @discardableResult
    func seedPreferences(_ core: SkyCore) -> Bool {
        guard seedPending, !seeding else { return false }
        guard !core.isRestored, let scene = preferences.scene else {
            seedPending = false
            return false
        }
        guard let port else { return false }
        seeding = true
        defer { seeding = false }
        var sends: [(String, Double)] = []
        if core.scene.preset != scene.preset, let index = SkyPresets.all.firstIndex(where: { $0.id == scene.preset }) {
            sends.append(("preset.select", Double(index)))
        }
        let base = core.scene.preset == scene.preset ? core.scene : (SkyPresets.scene(id: scene.preset) ?? core.scene)
        if base.speed != scene.speed { sends.append(("motion.speed", scene.speed)) }
        if base.turbulence != scene.turbulence { sends.append(("motion.turbulence", scene.turbulence)) }
        if base.ribbons != scene.ribbons { sends.append(("sky.ribbons", Double(scene.ribbons))) }
        if base.stars != scene.stars { sends.append(("sky.stars", Double(scene.stars))) }
        if base.cloudiness != scene.cloudiness { sends.append(("sky.clouds", scene.cloudiness)) }
        if core.hue != preferences.hue { sends.append(("colour.hue", preferences.hue)) }
        if core.limit != preferences.limit { sends.append(("light.limit", preferences.limit)) }
        var accepted = false
        var refused = false
        for (control, value) in sends {
            if port.send(control, [value]).isAccepted { accepted = true } else { refused = true }
        }
        if !refused { seedPending = false }
        return accepted
    }

    /// Turns the sound on or off: kept in the preferences only (no action is sent, nothing plays).
    func setSound(on: Bool) {
        guard preferences.soundOn != on else { return }
        preferences.soundOn = on
        if mirror.soundOn != on { mirror.soundOn = on }
        save()
    }

    /// Sets the sound volume, clamped to 0…1 (a non-finite value is ignored): kept in the preferences only.
    func setVolume(_ volume: Double) {
        guard volume.isFinite else { return }
        let kept = min(max(volume, SkyPreferences.volumeRange.lowerBound), SkyPreferences.volumeRange.upperBound)
        guard preferences.volume != kept else { return }
        preferences.volume = kept
        if mirror.volume != kept { mirror.volume = kept }
        save()
    }

    /// Takes the sky of `core` into the preferences (the sound choice stays) and writes them.
    private func adoptSky(_ core: SkyCore) {
        let next = SkyPreferences(scene: core.scene, hue: core.hue, limit: core.limit, soundOn: preferences.soundOn,
                                  volume: preferences.volume)
        preferences = next
        save()
    }

    /// Writes the preferences as `prefs.v1`; the first refused write shows ``saveFailedMessage`` (once) and the
    /// choices stay in memory.
    private func save() {
        guard let storage else { return }
        do {
            try storage.setValue(preferences.encoded(), for: SkyPreferences.storageKey)
        } catch {
            failedSaves += 1
            guard !saveFailureReported else { return }
            saveFailureReported = true
            mirror.message = Self.saveFailedMessage
        }
    }

    // MARK: Chrome

    /// Hides the controls (presentation only; the state does not change).
    func hideControls() {
        if !mirror.controlsHidden { mirror.controlsHidden = true }
    }

    /// Shows the controls again (the tap on the sky and the accessibility action "Show controls").
    func showControls() {
        if mirror.controlsHidden { mirror.controlsHidden = false }
    }

    /// A touch that lifts within ``tapSlop`` points of where it landed shows hidden controls; nothing is sent.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard event.location.isFinite else { return }
        switch event.phase {
        case .began:
            touches[event.id] = event.location
        case .moved:
            if let start = touches[event.id], (event.location - start).length > Self.tapSlop {
                touches[event.id] = nil
            }
        case .ended:
            guard let start = touches.removeValue(forKey: event.id) else { return }
            if (event.location - start).length <= Self.tapSlop { showControls() }
        case .cancelled:
            touches[event.id] = nil
        }
    }

    /// Forgets the touches in progress.
    func cancelPointers() {
        touches = [:]
    }

    /// The actions of the native controls: all eight.
    var nativeActions: Set<String> { Set(SkyCore.actionIDs) }

    // MARK: Words, probes and views

    /// Brings the mirror and the blend's target up to `core` (see the file header); an accepted change of the sky
    /// (not the restore of a snapshot, not the seeding) is written to the preferences.
    func follow(_ core: SkyCore) {
        let target = SkyInputs(scene: core.scene, hue: core.hue)
        if !followed || reduceMotion {
            if blend.to != target || blend.isBlending { blend.jump(to: target) }
        } else if target != blend.to {
            if core.scene.preset != lastCore.scene.preset {
                blend.jump(to: target)   // the picture changes through the transition
            } else {
                blend.retarget(target)
            }
        }
        let changed = followed && core != lastCore
        let restored = core.isRestored && !lastCore.isRestored
        followed = true
        lastCore = core
        if changed, !restored, !seeding { adoptSky(core) }
        if mirror.preset != core.presetIndex { mirror.preset = core.presetIndex }
        if mirror.hue != core.hue { mirror.hue = core.hue }
        if mirror.speed != core.scene.speed { mirror.speed = core.scene.speed }
        if mirror.turbulence != core.scene.turbulence { mirror.turbulence = core.scene.turbulence }
        if mirror.ribbons != core.scene.ribbons { mirror.ribbons = core.scene.ribbons }
        if mirror.stars != core.scene.stars { mirror.stars = core.scene.stars }
        if mirror.clouds != core.scene.cloudiness { mirror.clouds = core.scene.cloudiness }
        if mirror.limit != core.limit { mirror.limit = core.limit }
    }

    /// The preset's display name of `core`.
    static func presetName(_ core: SkyCore) -> String { SkyPresets.all[core.presetIndex].name }

    /// The canvas label, for example "Aurora, Polar night, colour shift 0°, speed 1.0 times, 3 ribbons, 320 stars,
    /// clouds 10 %, brightness limit 60 %".
    func describe(_ core: SkyCore) -> String {
        follow(core)
        let ribbons = core.scene.ribbons
        return "Aurora, " + Self.presetName(core) + ", colour shift " + AuroraControls.hueText(core.hue)
            + ", speed " + AuroraControls.speedText(core.scene.speed) + ", \(ribbons) "
            + (ribbons == 1 ? "ribbon" : "ribbons") + ", \(core.scene.stars) stars, clouds "
            + AuroraControls.percentText(core.scene.cloudiness) + ", brightness limit "
            + AuroraControls.percentText(core.limit)
    }

    /// One probe at the bottom-leading corner, below the ribbons and the stars: `dark`.
    func probes(_ core: SkyCore) -> [FrameProbe] {
        [FrameProbe(name: "horizon", x: 0, y: 1, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The native controls (``AuroraControls``), sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AuroraControls(port: port, mirror: mirror, presenter: self))
    }
}
