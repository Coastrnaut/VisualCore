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
//     in memory. The sound choice drives the loop (``SkySound``, feature 156).
//   - Chrome: `controlsHidden` (presentation only, not in the snapshot or the digest). `hideControls()` hides the
//     controls; a tap on the sky (a touch that lifts within ``tapSlop`` points of where it landed) or the
//     accessibility action "Show controls" (`showControls()`) brings them back. The tap sends no action, so the
//     canvas has no gesture action (`gestureActions` is empty) and every action is a native control's.
//   - Words: the canvas label names the preset, the colour shift, the speed, the ribbons, the stars, the clouds and
//     the brightness limit. Probes: the bottom-leading corner is the dark sky below the ribbons (`dark`).
//
// Feature 155 (A21-P04) T-A21-406–408 (FR-A21-401–404; clarifications Q2–Q5; data-model.md;
// contracts/lowpower.md):
//
//   - Picture: everything is drawn by one ``SkyPicture`` (the transition, the fallback sky or the clear colour) inside
//     a `CachedScene`. The cache is in pass-through (the picture draws every frame, as before) unless the still view is
//     on or the fallback sky is shown.
//   - Still view ("Still sky", `setStillView(_:)`, presentation only: not in the core, the snapshot, the digest or the
//     preferences, no action): the cache key is the state digest, the drawable size, the level, the clock time, the
//     uniforms drawn, the mix of a running change and the reduced-flash flag, so the sky is drawn once and copied until
//     one of them changes. The clock holds, a control change within one sky is immediate (no input blend), and a change
//     between skies runs to its end (one draw per frame), then holds. With Reduce Motion on too, the change is
//     immediate and the picture holds. The brightness limit applies as always.
//   - Reduced flashing ("Reduced flashing", `setReducedFlash(_:)`, presentation only, or the system's Reduce Flashing
//     given to the factory): the stars do not twinkle and a change between skies takes 4.0 s
//     (``SkyTransition/reducedFlashDuration``), so consecutive frames' mean luminance changes slowly.
//   - Fallback: when `aurora-sky.frag` fails to compile (at `setup` or when a change builds the second sky) or the
//     host reports no fragment `highp` (``fragmentHighp``), the picture draws `SkyShader.fallbackSource` (the sky
//     colour to 0.6 × at the horizon, under the limit) and the controls show ``fallbackMessage``. If the fallback
//     fails too, the frame is cleared to the sky colour (never grey). ``breakShaders(sky:fallback:)`` is the tests' seam.
//
// Feature 156 (A21-P05) T-A21-503 (FR-A21-501–505; contracts/sound.md; data-model.md):
//
//   - Sound: one ``SkySound`` plays the shared ambient loop (`AmbientLoopPlayer` of `AmbientLoopRecipe.gentle`, made
//     only when it first must play) while the sound is on, the controls view is on screen (`controlsAppeared()`,
//     `controlsDisappeared()`; hiding the controls keeps the view) and the scene is active (`sceneActive(_:)`).
//     `setSound(on:)` and `setVolume(_:)` drive it at once; the preferences read when the presenter is made seed it.
//     A loop that cannot start leaves the choice on and the sky as it is. `setup`, `resize`, `draw`, `teardown`,
//     `shedCaches` (the protocol's default, which does nothing here), a preset change, the still view and reduced
//     flashing never touch it; the sound stays out of the core, the snapshot, the digest and the manifest.
//     ``loopFactory`` is the tests' seam (a fake player).
//   - Cadence: the clock follows the drawn-frame deltas (the host's clamped delta), so 30 and 60 frames per second
//     reach the same sky time. ``fixedDelta`` (nil in the app) is a test-only seam that sets each frame's delta.
//
// Feature 157 (A21-P06) T-A21-604 (FR-A21-603; SC-A21-602; clarification Q4): the test-only seam `failNextDraw`
// makes the next `draw` throw `SkyDrawError.injected` once, before anything is seeded, followed or drawn; the seam
// clears itself and is unreachable from the interface. The session then fails with the error's message, and `prefs.v1` is not
// touched (only an accepted change writes it).
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

/// Why a draw of Aurora failed on purpose (feature 157, A21-P06, T-A21-604).
enum SkyDrawError: Error, Equatable, CustomStringConvertible {
    /// The test-only seam ``AuroraPresenter/failNextDraw`` made this draw fail.
    case injected

    /// The message the failed session shows: "The Aurora draw failed: the test seam injected a failure."
    var description: String {
        switch self {
        case .injected:
            return "The Aurora draw failed: the test seam injected a failure."
        }
    }
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
    /// Whether the sound is on (the preferences; the loop plays while Aurora is open, feature 156).
    var soundOn = SkyPreferences.defaults.soundOn
    /// The sound volume (0…1; the preferences only).
    var volume = SkyPreferences.defaults.volume
    /// The message about the saved choices; nil when there is none.
    var message: String?
    /// Whether the still view is on (presentation only; feature 155).
    var stillView = false
    /// Whether the reduced-flash control is on (presentation only; feature 155).
    var reducedFlash = false
    /// The line about the sky shown (``AuroraPresenter/fallbackMessage``); nil when the full sky is drawn.
    var skyNotice: String?
}

/// What ``SkyPicture`` draws (feature 155).
enum SkyDrawMode: String, Equatable, Sendable {
    /// The full sky: the transition of `aurora-sky.frag` skies.
    case sky
    /// The fallback still sky of `SkyShader.fallbackSource`.
    case fallback
    /// The clear colour (the sky colour): the fallback failed too.
    case clear
}

/// The values the transition draws one frame with (feature 155).
struct SkyFrame {
    /// The incoming (or only) sky's inputs.
    var incoming: SkyInputs
    /// The incoming sky's uniforms.
    var uniforms: SkyUniforms
    /// The preset id shown.
    var preset: String
    /// The moving outgoing sky's uniforms during a change; nil without one.
    var outgoingUniforms: SkyUniforms?
    /// The animation time.
    var time: Double
}

/// Everything Aurora draws as one scene, wrapped by the still view's cache (feature 155): the transition's skies, the
/// fallback still sky, or the clear colour (see the presenter's file header).
@MainActor
final class SkyPicture: RenderScene {
    /// The skies and the change between presets.
    let transition: SkyTransition
    /// The fallback's source (`SkyShader.fallbackSource`; a test seam replaces it before `setup`).
    var fallbackFragment = SkyShader.fallbackSource
    /// The fallback still sky; nil until the fallback is first needed.
    private(set) var fallback: FullScreenShaderScene?
    /// The clear of the last resort.
    let clear = ClearColorScene()
    /// What is drawn.
    private(set) var mode: SkyDrawMode = .sky
    /// Set before `setup` when the host reports no fragment `highp`: the fallback is drawn at once.
    var highpMissing = false
    /// Why the full sky is not drawn (the shader's message, or the missing precision); nil while it is.
    private(set) var failure: String?
    /// Whether the picture is set up (between `setup` and `teardown`).
    private(set) var isSetUp = false
    /// What the transition draws next (sky mode).
    var frame: SkyFrame?
    /// The sky colour in linear light (the fallback's top and the clear colour).
    var skyColour = SIMD3<Float>(0, 0, 0)
    /// The brightness limit (the fallback's cap).
    var limit = SkyCore.defaultLimit

    /// A picture of `transition`; nothing is allocated before `setup`.
    init(transition: SkyTransition) {
        self.transition = transition
    }

    /// Sets up the full sky; a compile or link failure, or a missing `highp`, sets up the fallback instead, and a
    /// failing fallback leaves the clear colour. Never throws for a shader failure.
    func setup(_ context: RenderContext) throws {
        if mode == .sky {
            if highpMissing {
                failure = "no fragment highp"
                mode = .fallback
            } else {
                do {
                    try transition.setup(context)
                    isSetUp = true
                    return
                } catch let error as SkyShaderError {
                    failure = error.message
                    mode = .fallback
                }
            }
        }
        setUpFallback(context)
        isSetUp = true
    }

    /// Leaves the full sky for the fallback (a change could not build its second sky): the transition's GPU objects
    /// are released.
    func fallBack(_ context: RenderContext, failure: String) {
        guard mode == .sky else { return }
        if transition.isSetUp { transition.teardown(context) }
        self.failure = failure
        mode = .fallback
        setUpFallback(context)
    }

    /// Builds the fallback scene; a failure leaves the clear colour.
    private func setUpFallback(_ context: RenderContext) {
        guard mode == .fallback else { return }
        let scene = fallback ?? FullScreenShaderScene(fragment: fallbackFragment, fragmentName: SkyShader.fallbackName,
                                                      bundle: ShaderBundle(files: [:]))
        fallback = scene
        do {
            try scene.setup(context)
        } catch {
            mode = .clear
            return
        }
        if scene.errorMessage != nil {
            scene.teardown(context)
            mode = .clear
        }
    }

    /// Passes the drawable size to what is drawn.
    func resize(_ context: RenderContext) {
        switch mode {
        case .sky: transition.resize(context)
        case .fallback: fallback?.resize(context)
        case .clear: break
        }
    }

    /// Draws ``frame`` through the transition, the fallback with ``skyColour`` under ``limit``, or the clear colour.
    func render(_ context: RenderContext, frame info: FrameInfo) throws {
        switch mode {
        case .sky:
            guard let frame else { return }
            try transition.render(context, frame: info, incoming: frame.incoming, uniforms: frame.uniforms,
                                  preset: frame.preset, outgoingUniforms: frame.outgoingUniforms, time: frame.time)
        case .fallback:
            guard let fallback else { return }
            fallback.resize(context)
            fallback.palette = [skyColour]
            fallback.parameters = ["limit": limit]
            try fallback.render(context, frame: info)
        case .clear:
            let encoded = Self.encoded(skyColour)
            clear.red = encoded.x
            clear.green = encoded.y
            clear.blue = encoded.z
            try clear.render(context, frame: info)
        }
    }

    /// Releases the GPU objects; the mode stays, so a later `setup` draws the same kind of picture.
    func teardown(_ context: RenderContext) {
        if transition.isSetUp { transition.teardown(context) }
        fallback?.teardown(context)
        isSetUp = false
    }

    /// A linear-light colour encoded to sRGB (the exact transfer function), each channel clamped to 0…1.
    static func encoded(_ linear: SIMD3<Float>) -> SIMD3<Float> {
        func encode(_ c: Float) -> Float {
            let v = min(max(c, 0), 1)
            return v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
        }
        return SIMD3(encode(linear.x), encode(linear.y), encode(linear.z))
    }
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
    /// Whether the system's Reduce Flashing was on when the experience was made (feature 155).
    let systemReduceFlashing: Bool
    /// The line shown when the full sky cannot be drawn (feature 155).
    static let fallbackMessage = "This device shows a simpler sky."
    /// The fragment `highp` precision the host reports; nil when unknown (then only a compile failure leads to the
    /// fallback). Read at every `setup`; the factory leaves it unknown and the tests set it.
    var fragmentHighp: () -> RenderCapabilities.ShaderPrecision? = { nil }
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
    /// Everything drawn: the transition, the fallback or the clear colour (feature 155).
    let picture: SkyPicture
    /// The still view's cache around ``picture`` (pass-through unless the picture is held).
    let cache: CachedScene
    /// Whether the still view is on (presentation only; feature 155).
    private(set) var stillView = false
    /// Whether the reduced-flash control is on (presentation only; feature 155).
    private(set) var reducedFlashControl = false
    /// Whether reduced flashing applies: the control or the system's Reduce Flashing.
    var reducedFlashing: Bool { reducedFlashControl || systemReduceFlashing }
    /// How many times the sky was drawn (every pass-through frame and every refresh of the held picture).
    var skyDrawCount: Int { cache.childDrawCount }
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
    /// When the ambient loop plays (feature 156).
    let sound: SkySound
    /// The tests' frame delta in seconds, used instead of the host's when set (feature 156); nil in the app.
    var fixedDelta: Double?
    /// The frame cap: 30 frames per second (the sky moves slowly).
    var maxFramesPerSecond: Int { 30 }
    /// Test-only seam: when true, the next `draw` throws ``SkyDrawError/injected`` once, before it seeds, follows or
    /// draws anything; the seam clears itself and nothing in the experience or its interface sets it (feature 157,
    /// A21-P06, T-A21-604).
    var failNextDraw = false

    /// A presenter; with `reduceMotion` on the sky holds still and changes are immediate. The preferences are read
    /// from `storage`'s value `prefs.v1` now, before the first frame (see the file header); `loopFactory` makes the
    /// sound's player (nil: `AmbientLoopPlayer(recipe: .gentle)`).
    init(reduceMotion: Bool = false, storage: ExperienceStorage? = nil, reduceFlashing: Bool = false,
         loopFactory: (() -> any SkyLoopPlaying)? = nil) {
        self.reduceMotion = reduceMotion
        self.systemReduceFlashing = reduceFlashing
        self.storage = storage
        picture = SkyPicture(transition: transition)
        cache = CachedScene(child: picture)
        transition.reducedFlashing = reduceFlashing
        clock.reducedMotion = reduceMotion
        let read = Self.keptPreferences(storage)
        preferences = read.preferences
        preferencesRefusal = read.refusal
        seedPending = storage != nil && read.refusal == nil && read.preferences != SkyPreferences.defaults
        mirror.soundOn = preferences.soundOn
        mirror.volume = preferences.volume
        sound = SkySound(makePlayer: loopFactory)
        sound.seed(wanted: preferences.soundOn, volume: preferences.volume)
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

    /// Sets up the picture inside its cache (the crossfade of a running change, or the sky alone), again after a
    /// context recreation; a build error or a missing `highp` sets up the fallback and shows ``fallbackMessage``. The
    /// preferences and the sound choice are not touched.
    func setup(_ context: RenderContext) throws {
        if let highp = fragmentHighp(), !highp.isSupported || highp.precisionBits <= 0 { picture.highpMissing = true }
        try cache.setup(context)
        setupCount += 1
        noteFallback()
    }

    /// Passes the new drawable size to the picture (the held picture is drawn again at the new size).
    func resize(_ context: RenderContext) {
        cache.resize(context)
    }

    /// Shows ``fallbackMessage`` while the full sky is not drawn.
    private func noteFallback() {
        let notice = picture.mode == .sky ? nil : Self.fallbackMessage
        if mirror.skyNotice != notice { mirror.skyNotice = notice }
    }

    /// The tests' seam (feature 155): before `setup`, replaces the sky's source (`sky`) and the fallback's source
    /// (`fallback`) with a source that does not compile.
    func breakShaders(sky: Bool, fallback: Bool) {
        let broken = "this is not a shader;"
        if sky { transition.fragment = broken }
        if fallback { picture.fallbackFragment = broken }
    }

    // MARK: Still view and reduced flash

    /// Turns the still view on or off (presentation only: no action, nothing saved).
    func setStillView(_ on: Bool) {
        guard stillView != on else { return }
        stillView = on
        if mirror.stillView != on { mirror.stillView = on }
    }

    /// Turns the reduced-flash control on or off (presentation only: no action, nothing saved).
    func setReducedFlash(_ on: Bool) {
        guard reducedFlashControl != on else { return }
        reducedFlashControl = on
        if mirror.reducedFlash != on { mirror.reducedFlash = on }
    }

    /// The still view's cache key: the state digest, the drawable size, `tier`, the clock time, the uniforms drawn, the
    /// mix of a running change, the mode and the reduced-flash flag.
    private func stillKey(_ core: SkyCore, tier: Int, context: RenderContext, uniforms: SkyUniforms,
                          outgoing: SkyUniforms?) throws -> Int {
        var builder = DigestBuilder(domain: SkyCore.experienceID)
        try core.writeDigest(into: &builder)
        var hasher = Hasher()
        hasher.combine(builder.finish().hex)
        hasher.combine(context.pixelWidth)
        hasher.combine(context.pixelHeight)
        hasher.combine(tier)
        hasher.combine(clock.time)
        for value in [uniforms, outgoing].compactMap({ $0 }) {
            for stop in value.palette { hasher.combine(stop.x); hasher.combine(stop.y); hasher.combine(stop.z) }
            for (name, number) in value.shaderParameters.sorted(by: { $0.key < $1.key }) {
                hasher.combine(name)
                hasher.combine(number)
            }
        }
        hasher.combine(transition.isChanging ? transition.eased : -1)
        hasher.combine(transition.restarts)
        hasher.combine(picture.mode)
        hasher.combine(reducedFlashing)
        return hasher.finalize()
    }

    /// Seeds a fresh state from the preferences (once), follows `core`, starts, restarts, advances or ends the change
    /// between presets and draws the sky (or the mix of both skies) once at `tier`. Throws ``SkyDrawError/injected``
    /// once while ``failNextDraw`` is set (it is cleared first).
    func draw(_ core: SkyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw SkyDrawError.injected
        }
        var core = core
        if seedPending, seedPreferences(core) { core = coreSource?() ?? core }
        follow(core)
        guard cache.isSetUp else { return }
        let holding = reduceMotion || stillView
        clock.reducedMotion = holding
        clock.speed = core.scene.speed
        let delta = fixedDelta ?? frame.delta
        clock.advance(by: delta)
        if holding {
            blend.finish()
        } else {
            blend.advance(by: delta)
        }
        transition.reducedFlashing = reducedFlashing
        if picture.mode == .sky {
            if let shown = transition.sky.preset, shown != core.scene.preset {
                if reduceMotion {
                    transition.finish(context)
                } else {
                    do {
                        try transition.begin(limit: core.limit, context: context)
                    } catch let error as SkyShaderError {
                        picture.fallBack(context, failure: error.message)
                        noteFallback()
                    }
                }
            } else if transition.isChanging {
                if reduceMotion { transition.finish(context) }
                transition.advance(by: delta)
            }
            if let still = transition.stillLimit, core.limit < still { transition.finish(context) }
            if transition.isChanging, transition.progress >= 1 { transition.finish(context) }
        }
        let uniforms = blend.current.uniforms(phase: clock.phase, level: tier, limit: core.limit)
        let outgoing = transition.outgoing?.inputs?.uniforms(phase: clock.phase, level: tier, limit: core.limit)
        picture.frame = SkyFrame(incoming: blend.current, uniforms: uniforms, preset: core.scene.preset,
                                 outgoingUniforms: outgoing, time: clock.time)
        picture.skyColour = blend.current.palette.first ?? .zero
        picture.limit = core.limit
        cache.passThrough = !(stillView || picture.mode != .sky)
        if !cache.passThrough {
            cache.key = try stillKey(core, tier: tier, context: context, uniforms: uniforms, outgoing: outgoing)
        }
        try cache.render(context, frame: frame)
        lastUniforms = uniforms
        lastOutgoingUniforms = transition.isChanging ? outgoing : nil
        lastMix = transition.isChanging ? transition.eased : nil
    }

    /// Releases the picture's GPU objects (and the held picture); a running change, the clock and the preferences
    /// stay.
    func teardown(_ context: RenderContext) {
        cache.teardown(context)
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

    /// Turns the sound on or off: kept in the preferences (no action is sent) and given to the loop at once.
    func setSound(on: Bool) {
        guard preferences.soundOn != on else { return }
        preferences.soundOn = on
        if mirror.soundOn != on { mirror.soundOn = on }
        save()
        sound.setWanted(on)
    }

    /// Sets the sound volume, clamped to 0…1 (a non-finite value is ignored): kept in the preferences and given to
    /// the loop at once.
    func setVolume(_ volume: Double) {
        guard volume.isFinite else { return }
        let kept = min(max(volume, SkyPreferences.volumeRange.lowerBound), SkyPreferences.volumeRange.upperBound)
        guard preferences.volume != kept else { return }
        preferences.volume = kept
        if mirror.volume != kept { mirror.volume = kept }
        save()
        sound.setVolume(kept)
    }

    /// The controls view appeared: the loop may play (feature 156).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (Aurora was left): the loop stops.
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active (`true`) or inactive or backgrounded (`false`): the loop plays or stops.
    func sceneActive(_ active: Bool) { sound.setActive(active) }

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
