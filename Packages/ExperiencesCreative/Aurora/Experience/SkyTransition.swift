// SkyTransition — feature 154 (A21-P03) T-A21-302 (FR-A21-301, FR-A21-302; clarification Q1; data-model.md
// "SkyTransition"; contracts/experience.md "Transition"). The change between two presets as a mix of two moving
// pictures, drawn through VisualCoreRendering's `CrossfadeScene`:
//
//   - `SkyLayer`: one moving sky, a `FullScreenShaderScene` of `aurora-sky.frag` with the inputs it draws. Each layer
//     has a program slot (0 or 1): slot 1 appends one `#define` line to the source, so the outgoing and the incoming
//     sky never share one cached program (the registry does not count holders, and tearing one sky down must not
//     delete the other's program). A build error throws `SkyShaderError` with the shader's message.
//   - `SkyTransition`: while no change runs it draws its sky alone. A change of preset makes a `CrossfadeScene` from
//     the shown sky (which keeps moving, with the inputs it showed) to a new sky in the other slot; progress runs over
//     ``SkyTransition/duration`` (2.0 s) of drawn-frame time, eased with smoothstep. A new choice during a change
//     calls `replaceIncoming(_:context:)` with the same incoming sky: the crossfade keeps the current mix as a still
//     outgoing picture, the moving outgoing sky is released and the fade restarts from the picture shown. At the end
//     the crossfade is torn down with the incoming sky kept set up (`keepsShaderOnTeardown`), which then draws alone.
//     Under Reduce Motion the presenter ends a change at once (``finish(_:)``).
//   - Lifecycle: `setup` sets up the crossfade (its children, its still picture re-uploaded) or the sky alone, again
//     after a context recreation, so a change keeps its picture and progress; `resize` passes the size on (the
//     crossfade releases its targets and makes them at the next mixed frame); `teardown` releases everything but keeps
//     the objects, so a later `setup` continues where the change was.
// The brightness limit: each sky applies it in its shader, and a mix in display space of two capped pictures stays
// capped (sRGB decoding is convex). A still captured under a higher limit than the one asked for now ends the change
// (``stillLimit``). No GL call: everything is drawn through VisualCoreRendering's scenes.
//
// Feature 155 (A21-P04) T-A21-407, T-A21-408 (FR-A21-402, FR-A21-403; clarifications Q2, Q4): with
// ``SkyTransition/reducedFlashing`` on, a change takes ``SkyTransition/reducedFlashDuration`` (4.0 s) instead of 2.0 s
// (switched during a change, the share done is kept, so the mix does not jump) and every sky draws with the twinkle
// off (`SkyShader.twinkleOffParameter` 1). ``SkyTransition/fragment`` is the sky's source (a test seam replaces it,
// before `setup`, with a source that fails to compile).
import Foundation
import AuroraCore
import VisualCoreExperience
import VisualCoreRendering
import VisualCoreScenes

/// One moving sky of the transition: a full-screen shader scene of `aurora-sky.frag` in its own program slot.
@MainActor
final class SkyLayer: RenderScene {
    /// The program slot, 0 or 1 (slot 1 compiles a distinct program of the same shader).
    let slot: Int
    /// The scene drawing the sky.
    let shader: FullScreenShaderScene
    /// The inputs this sky drew last; nil before its first frame.
    var inputs: SkyInputs?
    /// The preset id of the scene this sky showed last; nil before its first frame.
    var preset: String?
    /// While true, `teardown` leaves the shader set up: the transition takes the sky out of a crossfade it ends.
    var keepsShaderOnTeardown = false

    /// The fragment source of `slot`: the shader itself for slot 0, one `#define AURORA_SKY_SLOT <slot>` line appended
    /// otherwise (the line numbers of diagnostics stay those of `aurora-sky.frag`).
    static func source(slot: Int, fragment: String = SkyShader.source) -> String {
        slot == 0 ? fragment : fragment + "\n#define AURORA_SKY_SLOT \(slot)\n"
    }

    /// A sky in program slot `slot` drawing `fragment` (`aurora-sky.frag` by default); nothing is allocated before
    /// `setup`.
    init(slot: Int, fragment: String = SkyShader.source) {
        self.slot = slot
        shader = FullScreenShaderScene(fragment: Self.source(slot: slot, fragment: fragment),
                                       fragmentName: SkyShader.fragmentName, bundle: ShaderBundle(files: [:]))
    }

    /// Builds the program; a compile or link error tears it down again and throws ``SkyShaderError``.
    func setup(_ context: RenderContext) throws {
        try shader.setup(context)
        if let message = shader.errorMessage {
            shader.teardown(context)
            throw SkyShaderError(message: message)
        }
    }

    /// Passes the drawable size on.
    func resize(_ context: RenderContext) {
        shader.resize(context)
    }

    /// Draws the sky with the uniforms last set by ``show(_:uniforms:preset:time:)``.
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try shader.render(context, frame: frame)
    }

    /// Releases the program unless ``keepsShaderOnTeardown`` is set.
    func teardown(_ context: RenderContext) {
        if !keepsShaderOnTeardown { shader.teardown(context) }
    }

    /// Sets what the next frame draws: `uniforms` (made from `inputs`) at animation time `time`, for `preset`; with
    /// `twinkleOff` the stars do not twinkle (reduced flash).
    func show(_ inputs: SkyInputs, uniforms: SkyUniforms, preset: String, time: Double, twinkleOff: Bool = false) {
        self.inputs = inputs
        self.preset = preset
        shader.palette = uniforms.palette
        var parameters = uniforms.shaderParameters
        if twinkleOff { parameters[SkyShader.twinkleOffParameter] = 1 }
        shader.parameters = parameters
        shader.fixedTime = time
    }
}

/// The change between presets as a crossfade of two moving skies (see the file header).
@MainActor
final class SkyTransition {
    /// The length of a change: 2.0 s of drawn-frame time.
    static let duration = 2.0
    /// The length of a change with reduced flashing on: 4.0 s of drawn-frame time (feature 155).
    static let reducedFlashDuration = 4.0

    /// The sky's fragment source for every new layer (`aurora-sky.frag`); set only before `setup` (a test seam), when
    /// the sky alone is rebuilt with it.
    var fragment = SkyShader.source {
        didSet {
            guard !isSetUp, crossfade == nil else { return }
            sky = SkyLayer(slot: 0, fragment: fragment)
        }
    }

    /// Reduced flashing (feature 155): changes take ``reducedFlashDuration`` and the stars do not twinkle. Switched
    /// during a change, the share done stays.
    var reducedFlashing = false {
        didSet {
            guard oldValue != reducedFlashing else { return }
            let share = elapsed / (oldValue ? Self.reducedFlashDuration : Self.duration)
            elapsed = min(max(share, 0), 1) * length
        }
    }

    /// The length of a change now: ``duration``, or ``reducedFlashDuration`` with ``reducedFlashing``.
    var length: Double { reducedFlashing ? Self.reducedFlashDuration : Self.duration }

    /// The sky shown alone, or the incoming sky during a change.
    private(set) var sky = SkyLayer(slot: 0)
    /// The moving outgoing sky of a change; nil without a change or once a restart made the outgoing picture a still.
    private(set) var outgoing: SkyLayer?
    /// The crossfade of a running change; nil without one.
    private(set) var crossfade: CrossfadeScene?
    /// The frame time since the change began (or restarted), 0…``length``.
    private(set) var elapsed = SkyTransition.duration
    /// Whether the transition is set up (between `setup` and `teardown`).
    private(set) var isSetUp = false
    /// How many times a change restarted from the current mix (a new choice during a change).
    private(set) var restarts = 0
    /// The brightness limit the still outgoing picture was captured under; nil without a still.
    private(set) var stillLimit: Double?

    /// An idle transition showing slot 0; nothing is allocated before `setup`.
    init() {}

    /// Whether a change is running.
    var isChanging: Bool { crossfade != nil }

    /// The share of the change done, 0…1 (linear in frame time); 1 without a change.
    var progress: Double { isChanging ? min(max(elapsed / length, 0), 1) : 1 }

    /// The mix drawn: smoothstep of ``progress``.
    var eased: Double {
        let t = progress
        return t * t * (3 - 2 * t)
    }

    // MARK: Lifecycle

    /// Sets up the crossfade of a running change (both pictures) or the sky alone; again after a context recreation.
    func setup(_ context: RenderContext) throws {
        if let crossfade {
            try crossfade.setup(context)
        } else {
            try sky.setup(context)
        }
        isSetUp = true
    }

    /// Passes the new drawable size to the crossfade (its children and targets) or to the sky.
    func resize(_ context: RenderContext) {
        if let crossfade {
            crossfade.resize(context)
        } else {
            sky.resize(context)
        }
    }

    /// Releases the GPU objects; the skies, the still picture and the progress stay for the next `setup`.
    func teardown(_ context: RenderContext) {
        if let crossfade {
            crossfade.teardown(context)
        } else {
            sky.teardown(context)
        }
        isSetUp = false
    }

    // MARK: Changes

    /// Starts a change from the picture shown towards a new choice, drawn by ``sky`` from the next frame on. Without a
    /// running change, the shown sky becomes the moving outgoing sky (it keeps the inputs it showed) and a new sky in
    /// the other slot comes in. During a change the fade restarts from the current mix (`replaceIncoming` with the
    /// same incoming sky), and `limit` is recorded as ``stillLimit``. A failure leaves the shown picture as it was and
    /// rethrows.
    func begin(limit: Double, context: RenderContext) throws {
        guard isSetUp else { return }
        if let crossfade {
            try crossfade.replaceIncoming(sky, context: context)
            outgoing = nil
            stillLimit = limit
            restarts += 1
        } else {
            let shown = sky
            let incoming = SkyLayer(slot: 1 - shown.slot, fragment: fragment)
            incoming.inputs = shown.inputs
            incoming.preset = shown.preset
            let made = CrossfadeScene(from: shown, to: incoming)
            shown.keepsShaderOnTeardown = true
            defer { shown.keepsShaderOnTeardown = false }
            try made.setup(context)
            made.progress = 0
            outgoing = shown
            sky = incoming
            crossfade = made
            stillLimit = nil
        }
        elapsed = 0
    }

    /// Ends a running change at the incoming sky, which then draws alone (Reduce Motion, the end of the fade, or a
    /// still captured under a higher limit). Without a change only the progress is completed.
    func finish(_ context: RenderContext) {
        elapsed = length
        guard let crossfade else { return }
        sky.keepsShaderOnTeardown = true
        crossfade.teardown(context)
        sky.keepsShaderOnTeardown = false
        self.crossfade = nil
        outgoing = nil
        stillLimit = nil
    }

    /// Advances a running change by one drawn frame's `delta` seconds; a negative or non-finite delta does nothing.
    func advance(by delta: Double) {
        guard isChanging, delta.isFinite, delta > 0 else { return }
        elapsed = min(elapsed + delta, length)
        if length - elapsed < 1e-9 { elapsed = length }
    }

    /// Moves a running change to the point where the mix drawn (``eased``) is `mix` (0…1), by inverting smoothstep;
    /// the tests read the picture at chosen steps of a change with it.
    func seek(mix: Double) {
        guard isChanging else { return }
        let y = min(max(mix.isFinite ? mix : 0, 0), 1)
        let t = 0.5 - sin(asin(1 - 2 * y) / 3)
        elapsed = min(max(t, 0), 1) * length
    }

    // MARK: Drawing

    /// Draws one frame: the incoming (or only) sky with `incoming`, the moving outgoing sky with `outgoingUniforms`
    /// (its own inputs at the same phase, level and limit), both at animation time `time`, mixed by the crossfade at
    /// ``eased`` during a change.
    func render(_ context: RenderContext, frame: FrameInfo, incoming: SkyInputs, uniforms: SkyUniforms, preset: String,
                outgoingUniforms: SkyUniforms?, time: Double) throws {
        sky.resize(context)
        sky.show(incoming, uniforms: uniforms, preset: preset, time: time, twinkleOff: reducedFlashing)
        if let outgoing, let outgoingInputs = outgoing.inputs, let outgoingUniforms {
            outgoing.resize(context)
            outgoing.show(outgoingInputs, uniforms: outgoingUniforms, preset: outgoing.preset ?? preset, time: time,
                          twinkleOff: reducedFlashing)
        }
        if let crossfade {
            crossfade.progress = eased
            try crossfade.render(context, frame: frame)
        } else {
            try sky.render(context, frame: frame)
        }
    }
}
