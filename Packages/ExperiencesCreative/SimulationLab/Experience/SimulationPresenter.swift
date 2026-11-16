// SimulationPresenter — feature 117 (A16-P01) T-A16-105 (FR-A16-130; plan "Lifecycle"); feature 118 (A16-P02)
// T-A16-203 (FR-A16-201, 202, 204; clarification Q2). Draws Simulation Lab through the one host's drawing path. The
// cellular automaton is drawn from its GPU field (``AutomatonGPU``, an RGBA8 ping-pong pair stepped in lockstep with
// the engine). From feature 119 (A16-P03) T-A16-304/305/306/307 (FR-A16-301–330; clarifications Q1–Q5)
// reaction-diffusion and the wave are stepped and drawn on the GPU too, on floating-point targets (``GrayScottGPU``,
// ``WaveGPU``), through ``SimulationShaders/reactionDisplay`` and ``SimulationShaders/waveDisplay``. Their mirrors load
// from the CPU field on the same triggers as the automaton's and also once ``reloadInterval`` (64) GPU steps ran since
// the last load, so half-float rounding never drifts beyond the stated tolerance. The float probe
// (`FloatRenderSupport.detect(in:)`, per context generation; the test seam ``forceFloatUnsupported``) runs in `setup`:
// without support no float or 8-bit pair is made for the two families, choosing them is refused with `a16.unsupported`
// and ``unsupportedSentence``, and a restored state of either family is colour-mapped on the CPU and uploaded into the
// 64 × 64 `rgba8` target through ``SimulationShaders/display`` with the sentence in the status line. The canvas overlay
// is the legend (``SimulationLegend``) of the CPU field. A refused time step shows its own sentence.
//
// Feature 120 (A16-P04) T-A16-404/406/407 (FR-A16-401, 412, 420; clarifications Q1–Q3):
// - Touches: a point maps to its cell through the grid square in points; a touch that ends in the cell it began in
//   sends `sim.paint [x, y, 0]`; one that moves sends `sim.paint [x, y, 1]` for its first cell and for each newly
//   entered one; nothing outside the square.
// - Motion caps: ×1 under Reduce Motion, the automaton ×0.25 under Reduce Flashing (``speedCap(kind:)``). A faster
//   `sim.speed` is refused with `a16.reduced-motion` and ``reducedMotionSentence``; a family change lowers a faster
//   speed to the cap.
// - Histogram: the mirror's ``SimulationHistogram`` is recomputed from the CPU field at most once every
//   ``histogramInterval`` frames while running, and at the next frame after a non-step change.
//
// The display programs fit the grid into a square of side ⌊0.92 · min(width, height) / 64⌋ · 64 pixels (or
// ⌊0.92 · min(width, height)⌋ on a canvas under 70 pixels) centred on the canvas, and read the cell under each pixel
// with `texelFetch` at the integer cell index (`gl_FragCoord` scaled to the grid), so cells are crisp squares and no
// filtering blends them; outside the square they draw the dark background. The margin is at least 4 % of the shorter
// side, so the probe `background` at (0.01, 0.01) always lands on it. The automaton program maps red ≥ 0.5 to the
// palette's alive colour and the rest to its dead colour, so the picture is the CPU palette's, byte for byte.
//
// The CPU model stays the truth (clarification Q1); the GPU field is a mirror. It is loaded from the CPU field at the
// first automaton frame after setup, a context recreation or a resize, and whenever the field changed other than by
// stepping: another spec (family, preset, restore), a step count that went down (reset, restore) or jumped by more
// than 128 (16 iterations per host step × 8 host steps), or a changed field at an unchanged step count. Otherwise it
// runs exactly the iterations the engine ran since the last frame. This is exact for every state the actions reach:
// the automaton's field is a function of its spec (rule and seed) and step count alone, since every action that changes
// the field other than by stepping returns to the seeded start at step 0, so stepping from an earlier count of the
// same spec (also after a reset followed by iterations in the same frame) arrives at the same field.
//
// Lifecycle: `setup` makes the target, both display passes and the automaton pair with its step pass together
// (releasing whatever an earlier context left) and, after a context recreation, uploads the last colour-mapped CPU
// field again at once; a compile failure or an incomplete target throws with nothing left allocated, and the host
// fails the session (`experience.setup-failed`). `draw` mirrors or uploads, then runs the family's display pass;
// `teardown` releases everything together. Something missing at draw time releases everything and makes it again,
// never one part at a time. Drawing reads the core only: it never changes the state or its digest.
import Foundation
import SimulationLabCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class SimulationMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The family index, 0…2.
    var family = 0
    /// The family's title ("Cellular automaton").
    var familyTitle = ""
    /// The preset index, or nil for parameters that match no preset.
    var preset: Int?
    /// The preset titles of the family, in index order.
    var presetTitles: [String] = []
    /// The rule or preset in words ("rule Life (B3/S23)").
    var presetWords = ""
    /// True while running.
    var running = false
    /// The speed index, 0…4.
    var speedIndex = SimulationScheduler.defaultSpeedIndex
    /// The iterations run since the seeded start.
    var stepCount = 0
    /// The status line ("Running at ×1, step 120").
    var status = ""
    /// The answer to the last refused action; empty after an accepted one.
    var message = ""
    /// The legend of the current field (feature 119); nil before the first state.
    var legend: SimulationLegendValues?
    /// The time step of the current family (1 for the automaton).
    var timeStep = 1.0
    /// Whether reaction-diffusion and the wave can be chosen (false once the probe reported no float support).
    var floatFamiliesAvailable = true
    /// The histogram of the field (feature 120); nil before the first frame.
    var histogram: SimulationHistogram?
    /// The approximation label of the current family.
    var approximation = ""
    /// The fastest speed index allowed by Reduce Motion and Reduce Flashing (4 when neither is on).
    var speedCap = SimulationScheduler.speeds.count - 1
    /// The current spec, for the inspector.
    var spec: SimulationSpec?
}

/// Why drawing failed.
enum SimulationDrawError: Error, Equatable {
    /// The colour-mapped field could not be uploaded into the target.
    case uploadFailed
}

/// Draws Simulation Lab and owns its presentation state (the field target and the display pass).
@MainActor
final class SimulationPresenter: ExperiencePresenter {
    /// The fraction of the shorter canvas side the grid may cover.
    nonisolated static let coverage = 0.92

    /// The display program (``SimulationShaders/display``): the grid in a centred square with crisp cells, the
    /// background around it.
    nonisolated static var displayFragment: String { SimulationShaders.display }

    /// The most automaton iterations the engine runs between two frames: 16 per host step × 8 host steps
    /// (clarification Q2). A larger forward jump is not stepping, so the GPU field is loaded instead.
    nonisolated static let maxStepsPerFrame = SimulationScheduler.maxIterationsPerHostStep * 8

    /// Test seam: when set, the automaton step program is compiled from this source instead of
    /// ``SimulationShaders/automatonStep`` (an invalid source makes `setup` throw, so the session fails). Tests set it
    /// before opening and restore it to nil afterwards.
    static var stepFragmentOverride: String?

    /// Test seam (feature 119): when true, `setup` treats the float probe as reporting no support. Tests set it
    /// before opening and restore it to false afterwards.
    static var forceFloatUnsupported = false

    /// GPU steps after which a float mirror is loaded from the CPU field again (clarification Q3 of feature 119).
    nonisolated static let reloadInterval = 64

    /// The sentence shown when reaction-diffusion or the wave cannot run here (FR-A16-310).
    nonisolated static let reducedMotionSentence = "Faster speeds are off while Reduce Motion or Reduce Flashing is on."

    /// Frames between two histogram updates while running (4 per second at 60 frames per second).
    nonisolated static let histogramInterval = 15

    /// Whether Reduce Motion is on (set by the experience wrapper).
    var reduceMotion = false
    /// Whether Reduce Flashing is on (set by the experience wrapper).
    var reduceFlashing = false
    /// Histogram updates so far (tests).
    private(set) var histogramUpdateCount = 0
    /// Frames since the last histogram update.
    private var framesSinceHistogram = 0
    /// What the last histogram was computed from.
    private var histogramSource: (spec: SimulationSpec, step: Int, field: SimulationField)?
    /// The cells of the touches in progress, by pointer id: the first and the last cell, and whether it moved.
    private var touches: [Int: (first: (Int, Int), last: (Int, Int), moved: Bool)] = [:]

    /// The sentence shown when reaction-diffusion or the wave cannot run here (FR-A16-310).
    nonisolated static let unsupportedSentence =
        "Reaction-diffusion and the wave field need floating-point render targets, which this device does not offer."

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = SimulationMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// The 64 × 64 field target of the CPU upload (reaction-diffusion and wave); nil outside `setup` … `teardown`.
    private(set) var target: RenderTarget?
    /// The display pass of the CPU upload; nil outside `setup` … `teardown`.
    private(set) var display: FieldPass?
    /// The display pass of the automaton, sampling the GPU field; nil outside `setup` … `teardown`.
    private(set) var automatonDisplay: FieldPass?
    /// The automaton's GPU field (an RGBA8 pair and its step pass); nil outside `setup` … `teardown`.
    private(set) var automaton: AutomatonGPU?
    /// The Gray-Scott float pair; nil without float support or outside `setup` … `teardown`.
    private(set) var grayScott: GrayScottGPU?
    /// The wave float pair; nil without float support or outside `setup` … `teardown`.
    private(set) var wave: WaveGPU?
    /// The reaction-diffusion display pass; nil without float support.
    private(set) var reactionDisplay: FieldPass?
    /// The wave display pass; nil without float support.
    private(set) var waveDisplay: FieldPass?
    /// What the last probe reported (false also when forced); nil before the first `setup`.
    private(set) var floatSupported: Bool?
    /// Times a float mirror was loaded from the CPU field.
    private(set) var floatLoadCount = 0
    /// Float GPU steps run.
    private(set) var floatStepCount = 0
    /// GPU steps run on the current mirror since it was last loaded.
    private(set) var stepsSinceLoad = 0
    /// The last core drawn or described (for the words of a refused time step).
    private var lastCore: SimulationCore?
    /// How many times the target, the passes and the automaton pair were made (together each time).
    private(set) var resourceBuildCount = 0
    /// How many times a field was uploaded: a colour-mapped CPU field into the target, or the CPU automaton field
    /// into the GPU pair.
    private(set) var uploadCount = 0
    /// How many times the CPU automaton field was loaded into the GPU pair.
    private(set) var gpuLoadCount = 0
    /// How many automaton generations were run on the GPU in total.
    private(set) var gpuStepCount = 0
    /// The field last drawn (CPU data; survives a context loss); nil before the first state.
    private(set) var lastField: SimulationField?
    /// The family of ``lastField``.
    private(set) var lastKind: SimulationKind?
    /// The colour-mapped pixels of ``lastField`` (RGBA8, rows bottom-up); empty for the automaton, which is drawn
    /// from the GPU field.
    private(set) var lastPixels: [UInt8] = []
    /// Whether the target holds ``lastPixels`` (false after a new field or a new target).
    private(set) var uploaded = false
    /// The spec the GPU automaton field mirrors; nil when it mirrors nothing (before the first load, after a setup,
    /// a resize or another family).
    private(set) var mirroredSpec: SimulationSpec?
    /// The step count of the CPU state the GPU automaton field mirrors.
    private(set) var mirroredStep = 0
    /// The CPU automaton field the GPU field mirrors (to see a change at an unchanged step count).
    private var mirroredField: SimulationField?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The square the grid was drawn into, in pixels (origin x, origin y, side); nil before the first frame.
    private(set) var lastSquare: (x: Double, y: Double, side: Double)?
    /// The registry the target and the pass were made with (held weakly, as the host owns it).
    private weak var registry: ResourceRegistry?

    /// The saved experiments (feature 120); nil without storage (tests).
    let presets: SimulationPresetStore?
    /// The latest still capture (feature 120).
    let capture = SimulationCapture()

    /// A presenter for the experience `experienceID`, keeping saved experiments in `storage` when given. The capture
    /// folder is emptied, so no picture of an earlier session is left.
    init(experienceID: ExperienceID, storage: ExperienceStorage? = nil) {
        self.experienceID = experienceID
        presets = storage.map { SimulationPresetStore(storage: $0) }
        capture.clearFolder()
    }

    // MARK: Render scene

    /// Makes the target, the display passes and the automaton pair together with the host's registry (again after a
    /// context recreation) and uploads the last CPU field into the new target when there is one; the GPU automaton
    /// field is loaded from the CPU state at the next frame. A compile failure or an incomplete target throws, with
    /// nothing left allocated, and the host fails the session.
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        try makeResources(context)
        isLive = true
        if !lastPixels.isEmpty { try upload() }
    }

    /// A new drawable size: the GPU automaton field is loaded from the CPU state at the next frame.
    func resize(_ context: RenderContext) {
        invalidateMirror()
    }

    /// Draws the grid into the host's framebuffer: the automaton from its GPU field (loaded or stepped in lockstep
    /// with the engine first), the other families from the colour-mapped CPU field (uploaded when it changed).
    func draw(_ core: SimulationCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        gateHistogram(core)
        let width = max(1, context.pixelWidth), height = max(1, context.pixelHeight)
        lastCanvas = Vec2(Double(width), Double(height))
        let floatMissing = floatSupported == true
            && (grayScott == nil || wave == nil || reactionDisplay == nil || waveDisplay == nil)
        if target == nil || display == nil || automatonDisplay == nil || automaton == nil || floatMissing {
            releaseGPU()
            try makeResources(context)
        }
        guard let target, let display, let automatonDisplay, let automaton else { return }
        let field = core.model.field
        let onGPU = core.kind == .automaton || floatSupported == true
        if lastField != field || lastKind != core.kind {
            lastField = field
            lastKind = core.kind
            lastPixels = onGPU ? [] : SimulationPalette.rgba(field, kind: core.kind)
            uploaded = false
        }
        let square = Self.square(width: width, height: height, grid: SimulationCore.gridSize)
        lastSquare = square
        let output = FieldPass.Output.framebuffer(name: context.framebuffer, width: width, height: height)
        var uniforms: [String: FieldUniform] = ["uOrigin": .vec2(SIMD2(Float(square.x), Float(square.y))),
                                                "uSide": .float(Float(square.side)),
                                                "uGrid": .int(Int32(SimulationCore.gridSize)),
                                                "uBackground": .vec4(SimulationPalette.backgroundRGBA)]
        if core.kind == .automaton {
            try mirrorAutomaton(core, into: automaton)
            uniforms["uAlive"] = .vec4(Self.rgba(SimulationPalette.alive))
            uniforms["uDead"] = .vec4(Self.rgba(SimulationPalette.dead))
            try automatonDisplay.run(output: output, inputs: ["uField": automaton.current], uniforms: uniforms)
        } else if core.kind == .reactionDiffusion, let grayScott, let reactionDisplay {
            try mirrorFloat(core)
            uniforms["uScale"] = .float(SimulationPalette.reactionScale)
            uniforms["uStop0"] = .vec4(Self.rgba(SimulationPalette.reactionStops[0]))
            uniforms["uStop1"] = .vec4(Self.rgba(SimulationPalette.reactionStops[1]))
            uniforms["uStop2"] = .vec4(Self.rgba(SimulationPalette.reactionStops[2]))
            try reactionDisplay.run(output: output, inputs: ["uField": grayScott.pair.read], uniforms: uniforms)
        } else if core.kind == .wave, let wave, let waveDisplay {
            try mirrorFloat(core)
            uniforms["uZero"] = .vec4(Self.rgba(SimulationPalette.waveZero))
            uniforms["uNegative"] = .vec4(Self.rgba(SimulationPalette.waveNegative))
            uniforms["uPositive"] = .vec4(Self.rgba(SimulationPalette.wavePositive))
            try waveDisplay.run(output: output, inputs: ["uField": wave.current], uniforms: uniforms)
        } else {
            invalidateMirror()
            if !uploaded { try upload() }
            try display.run(output: output, inputs: ["uField": target], uniforms: uniforms)
        }
    }

    /// Releases the target, the passes and the automaton pair together.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
    }

    /// Brings the GPU automaton field in line with `core` (clarification Q2): it is loaded from the CPU field when
    /// it mirrors nothing (setup, context recreation, resize, another family before), when the spec changed (family,
    /// preset or restore), when the step count went down (reset, restore) or jumped forward by more than
    /// ``maxStepsPerFrame``, or when the field changed at an unchanged step count; otherwise it runs exactly the
    /// iterations the engine ran since the last frame. Reads the core only.
    private func mirrorAutomaton(_ core: SimulationCore, into automaton: AutomatonGPU) throws {
        let spec = core.model.spec
        let delta = core.stepCount - mirroredStep
        if mustLoad(core, delta: delta, reloads: false) {
            guard automaton.load(core.model.field.current) else { throw SimulationDrawError.uploadFailed }
            gpuLoadCount += 1
            uploadCount += 1
        } else if delta > 0 {
            try automaton.step(rule: spec.automatonRule, count: delta)
            gpuStepCount += delta
        }
        remember(core)
    }

    /// Brings the float mirror of the current family in line with `core` (clarification Q3 of feature 119): loaded
    /// on the automaton's triggers and also when the delta would take it past ``reloadInterval`` GPU steps since the
    /// last load; otherwise stepped by the engine's iteration delta with the spec's parameters. Reads the core only.
    private func mirrorFloat(_ core: SimulationCore) throws {
        let spec = core.model.spec
        let delta = core.stepCount - mirroredStep
        if mustLoad(core, delta: delta, reloads: true) {
            let loaded = spec.kind == .wave ? wave?.load(core.model.field) : grayScott?.load(core.model.field.current)
            guard loaded == true else { throw SimulationDrawError.uploadFailed }
            floatLoadCount += 1
            uploadCount += 1
            stepsSinceLoad = 0
        } else if delta > 0 {
            if spec.kind == .wave {
                try wave?.step(courant: Float(spec.courantNumber),
                               damping: Float(spec.value(ParameterCatalog.damping.name)), count: delta)
            } else {
                try grayScott?.step(feed: Float(spec.value(ParameterCatalog.feed.name)),
                                    kill: Float(spec.value(ParameterCatalog.kill.name)),
                                    timeStep: Float(spec.timeStep), count: delta)
            }
            floatStepCount += delta
            stepsSinceLoad += delta
        }
        remember(core)
    }

    /// Whether the mirror must be loaded from `core` rather than stepped by `delta` (see the file header).
    private func mustLoad(_ core: SimulationCore, delta: Int, reloads: Bool) -> Bool {
        mirroredSpec != core.model.spec || delta < 0 || delta > Self.maxStepsPerFrame
            || (delta == 0 && mirroredField != core.model.field)
            || (reloads && stepsSinceLoad + delta > Self.reloadInterval)
    }

    /// Records what the mirror now holds.
    private func remember(_ core: SimulationCore) {
        mirroredSpec = core.model.spec
        mirroredStep = core.stepCount
        mirroredField = core.model.field
    }

    /// Forgets what the GPU automaton field mirrors, so the next automaton frame loads it from the CPU state.
    private func invalidateMirror() {
        mirroredSpec = nil
        mirroredStep = 0
        mirroredField = nil
        stepsSinceLoad = 0
    }

    /// `color` as RGBA floats n / 255 with alpha 1.
    private static func rgba(_ color: SimulationPalette.RGB) -> SIMD4<Float> {
        SIMD4(Float(color.r) / 255, Float(color.g) / 255, Float(color.b) / 255, 1)
    }

    /// The square of the grid on a `width` × `height` pixel canvas: side ⌊0.92 · min / grid⌋ · grid (⌊0.92 · min⌋
    /// when that is 0), centred, origin rounded down to whole pixels.
    nonisolated static func square(width: Int, height: Int, grid: Int) -> (x: Double, y: Double, side: Double) {
        let room = (Double(min(width, height)) * coverage).rounded(.down)
        let whole = (room / Double(grid)).rounded(.down) * Double(grid)
        let side = max(1, whole > 0 ? whole : room)
        let x = ((Double(width) - side) / 2).rounded(.down), y = ((Double(height) - side) / 2).rounded(.down)
        return (x, y, side)
    }

    /// Uploads ``lastPixels`` into the target; throws ``SimulationDrawError/uploadFailed`` when the target refuses.
    private func upload() throws {
        guard let target, !lastPixels.isEmpty else { return }
        guard target.upload(rgbaFloats: SimulationPalette.floats(lastPixels)) else {
            throw SimulationDrawError.uploadFailed
        }
        uploaded = true
        uploadCount += 1
    }

    /// Makes the 64 × 64 `rgba8` target, the two display passes and the automaton pair with its step pass together;
    /// a failure releases what was made and rethrows.
    private func makeResources(_ context: RenderContext) throws {
        let registry = context.resources
        let n = SimulationCore.gridSize
        let made = try registry.makeRenderTarget(width: n, height: n, format: .rgba8, label: "a16.field")
        var madeDisplay: FieldPass?
        var madeAutomatonDisplay: FieldPass?
        do {
            let plain = try FieldPass(registry: registry, fragment: Self.displayFragment, inputs: ["uField"],
                                      label: "a16.display")
            madeDisplay = plain
            let cells = try FieldPass(registry: registry, fragment: SimulationShaders.automatonDisplay,
                                      inputs: ["uField"], label: "a16.automaton.display")
            madeAutomatonDisplay = cells
            automaton = try AutomatonGPU(registry: registry, gridSize: n,
                                         stepFragment: Self.stepFragmentOverride ?? SimulationShaders.automatonStep)
            display = plain
            automatonDisplay = cells
            let supported = !Self.forceFloatUnsupported && FloatRenderSupport.detect(in: registry).supported
            floatSupported = supported
            if supported {
                reactionDisplay = try FieldPass(registry: registry, fragment: SimulationShaders.reactionDisplay,
                                                inputs: ["uField"], label: "a16.reaction.display")
                waveDisplay = try FieldPass(registry: registry, fragment: SimulationShaders.waveDisplay,
                                            inputs: ["uField"], label: "a16.wave.display")
                grayScott = try GrayScottGPU(registry: registry, gridSize: n)
                wave = try WaveGPU(registry: registry, gridSize: n)
            }
        } catch {
            madeAutomatonDisplay?.release()
            madeDisplay?.release()
            automaton?.release()
            automaton = nil
            releaseFloat()
            display = nil
            automatonDisplay = nil
            registry.release(made)
            throw error
        }
        target = made
        self.registry = registry
        uploaded = false
        invalidateMirror()
        resourceBuildCount += 1
    }

    /// Releases the target, the display passes and the automaton pair, together.
    private func releaseGPU() {
        if let target { registry?.release(target) }
        target = nil
        display?.release()
        display = nil
        automatonDisplay?.release()
        automatonDisplay = nil
        automaton?.release()
        automaton = nil
        releaseFloat()
        uploaded = false
        invalidateMirror()
    }

    /// Releases the float pairs and their display passes.
    private func releaseFloat() {
        grayScott?.release()
        grayScott = nil
        wave?.release()
        wave = nil
        reactionDisplay?.release()
        reactionDisplay = nil
        waveDisplay?.release()
        waveDisplay = nil
    }

    // MARK: Probes, words and controls

    /// The probe `background` at (0.01, 0.01), always on the dark margin; none before the first frame.
    func probes(_ core: SimulationCore) -> [FrameProbe] {
        guard lastCanvas != nil,
              let background = FrameProbe(name: "background", x: 0.01, y: 0.01,
                                          expected: FrameColorClass.dark.rawValue) else { return [] }
        return [background]
    }

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: SimulationCore) {
        if !mirror.ready { mirror.ready = true }
        let family = core.familyIndex
        if mirror.family != family { mirror.family = family }
        let familyTitle = SimulationCore.familyTitle(index: family)
        if mirror.familyTitle != familyTitle { mirror.familyTitle = familyTitle }
        let preset = core.preset
        if mirror.preset != preset { mirror.preset = preset }
        let titles = SimulationCore.presetTitles(core.kind)
        if mirror.presetTitles != titles { mirror.presetTitles = titles }
        let words = SimulationCore.presetWords(core.model.spec)
        if mirror.presetWords != words { mirror.presetWords = words }
        if mirror.running != core.isRunning { mirror.running = core.isRunning }
        if mirror.speedIndex != core.speedIndex { mirror.speedIndex = core.speedIndex }
        if mirror.stepCount != core.stepCount { mirror.stepCount = core.stepCount }
        let unsupported = floatSupported == false
        let status = unsupported && core.kind != .automaton ? core.status + ". " + Self.unsupportedSentence : core.status
        if mirror.status != status { mirror.status = status }
        let legend = SimulationLegendValues.of(core.model.field, kind: core.kind)
        if mirror.legend != legend { mirror.legend = legend }
        let timeStep = core.model.spec.timeStep
        if mirror.timeStep != timeStep { mirror.timeStep = timeStep }
        if mirror.floatFamiliesAvailable == unsupported { mirror.floatFamiliesAvailable = !unsupported }
        let approximation = SimulationCore.approximationWords(core.kind)
        if mirror.approximation != approximation { mirror.approximation = approximation }
        let cap = speedCap(kind: core.kind)
        if mirror.speedCap != cap { mirror.speedCap = cap }
        if mirror.spec != core.model.spec { mirror.spec = core.model.spec }
        if mirror.histogram == nil { updateHistogram(core) }
        lastCore = core
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        if result == .rejected(.rule(code: SimulationRule.unsupported)) { return unsupportedSentence }
        if result == .rejected(.rule(code: SimulationRule.reducedMotion)) { return reducedMotionSentence }
        if result == .rejected(.rule(code: SimulationRule.unstable)) {
            return "Those settings are beyond the stability limit and were refused."
        }
        switch control {
        case "sim.family": return "There is no such simulation family."
        case "sim.preset": return "This family has no such preset."
        case "sim.run": return "The simulation is already running."
        case "sim.pause": return "The simulation is already paused."
        case "sim.step": return "Pause the simulation to step it one iteration at a time."
        case "sim.speed": return "There is no such speed."
        case "sim.timestep": return "The time step must stay within 0.05 to 2."
        default: return "That is not possible here."
        }
    }

    /// Sends `control` with `values` through `port` and shows the answer in the mirror (empty when accepted).
    @discardableResult
    /// Without float support, choosing reaction-diffusion or the wave is refused here with `a16.unsupported` (the
    /// deterministic core does not know the device). A refused time step shows the core's own sentence for it.
    func send(_ control: String, _ values: [Double] = [], through port: ExperienceActionPort) -> ActionResult {
        if control == "sim.family", floatSupported == false, let value = values.first, value == 1 || value == 2 {
            let refused = ActionResult.rejected(.rule(code: SimulationRule.unsupported))
            mirror.message = Self.answerWords(control: control, result: refused)
            return refused
        }
        if control == "sim.speed", let value = values.first, let kind = lastCore?.kind,
           value > Double(speedCap(kind: kind)) {
            let refused = ActionResult.rejected(.rule(code: SimulationRule.reducedMotion))
            mirror.message = Self.answerWords(control: control, result: refused)
            return refused
        }
        let before = lastCore
        let result = port.send(control, values)
        if control == "sim.family", result.isAccepted, let value = values.first,
           let index = SimulationCore.choice(value, count: SimulationCore.families.count) {
            let cap = speedCap(kind: SimulationCore.families[index])
            if let speed = before?.speedIndex, speed > cap { _ = port.send("sim.speed", [Double(cap)]) }
        }
        if control == "sim.timestep", !result.isAccepted, let value = values.first,
           let sentence = before?.timeStepRefusal(value)?.sentence {
            mirror.message = sentence
        } else {
            mirror.message = Self.answerWords(control: control, result: result)
        }
        return result
    }

    /// The fastest speed index for `kind`: ×1 (index 2) under Reduce Motion, the automaton ×0.25 (index 0) under
    /// Reduce Flashing, otherwise ×4 (index 4).
    func speedCap(kind: SimulationKind) -> Int {
        var cap = SimulationScheduler.speeds.count - 1
        if reduceMotion || reduceFlashing { cap = min(cap, 2) }
        if reduceFlashing, kind == .automaton { cap = 0 }
        return cap
    }

    /// Recomputes the histogram once ``histogramInterval`` frames passed while running, or at once after a non-step
    /// change (another spec, a step count that went down, or a changed field at an unchanged step count).
    private func gateHistogram(_ core: SimulationCore) {
        framesSinceHistogram += 1
        guard let source = histogramSource else { updateHistogram(core); return }
        let field = core.model.field
        guard field != source.field else { return }
        let nonStep = source.spec != core.model.spec || core.stepCount <= source.step
        if nonStep || !core.isRunning || framesSinceHistogram >= Self.histogramInterval { updateHistogram(core) }
    }

    /// Computes the histogram of `core`'s field into the mirror.
    private func updateHistogram(_ core: SimulationCore) {
        let histogram = SimulationHistogram.of(core.model.field, kind: core.kind)
        if mirror.histogram != histogram { mirror.histogram = histogram }
        histogramSource = (core.model.spec, core.stepCount, core.model.field)
        framesSinceHistogram = 0
        histogramUpdateCount += 1
    }

    /// The cell under `location` (points, top-left origin) on a `viewSize` canvas, or nil outside the grid square.
    nonisolated static func cell(at location: Vec2, viewSize: Vec2) -> (x: Int, y: Int)? {
        let n = SimulationCore.gridSize
        let width = max(1, Int(viewSize.x.rounded(.down))), height = max(1, Int(viewSize.y.rounded(.down)))
        let square = Self.square(width: width, height: height, grid: n)
        let top = Double(height) - square.y - square.side
        let u = (location.x - square.x) / square.side, v = (location.y - top) / square.side
        guard u >= 0, u < 1, v >= 0, v < 1 else { return nil }
        let x = min(n - 1, Int((u * Double(n)).rounded(.down)))
        let rowFromTop = min(n - 1, Int((v * Double(n)).rounded(.down)))
        return (x, n - 1 - rowFromTop)
    }

    /// Touches paint cells (see the file header): a tap sends `sim.paint [x, y, 0]`, a drag `sim.paint [x, y, 1]` per
    /// cell entered.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        let cell = Self.cell(at: event.location, viewSize: viewSize)
        switch event.phase {
        case .began:
            if let cell { touches[event.id] = ((cell.x, cell.y), (cell.x, cell.y), false) }
        case .moved:
            guard var touch = touches[event.id], let cell, cell != touch.last else { return }
            if !touch.moved {
                send("sim.paint", [Double(touch.first.0), Double(touch.first.1), 1], through: port)
                touch.moved = true
            }
            send("sim.paint", [Double(cell.x), Double(cell.y), 1], through: port)
            touch.last = (cell.x, cell.y)
            touches[event.id] = touch
        case .ended:
            if let touch = touches.removeValue(forKey: event.id), !touch.moved {
                send("sim.paint", [Double(touch.first.0), Double(touch.first.1), 0], through: port)
            }
        case .cancelled:
            touches[event.id] = nil
        }
    }

    /// Forgets the touches in progress.
    func cancelPointers() { touches = [:] }

    /// The action the canvas touches send.
    var gestureActions: Set<String> { ["sim.paint"] }

    /// Captures the field as a 1024 × 1024 PNG through `render` (the host's still renderer): a running simulation is
    /// paused by `sim.pause` first and resumed by `sim.run` after, so the field and the step count are unchanged.
    func captureStill(through port: ExperienceActionPort, render: (Int, Int) throws -> StillImage) {
        let wasRunning = lastCore?.isRunning == true
        if wasRunning { _ = port.send("sim.pause", []) }
        capture.capture(render)
        if wasRunning { _ = port.send("sim.run", []) }
    }

    /// The legend over the canvas (FR-A16-320).
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(SimulationLegendOverlay(mirror: mirror))
    }

    /// The canvas description of `core` (see `SimulationCore.canvasDescription`).
    func describe(_ core: SimulationCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(SimulationControls(port: port, mirror: mirror, presenter: self))
    }

    /// The actions the native controls send: every action (`sim.paint` also from the Seed row).
    var nativeActions: Set<String> {
        Set(SimulationCore.actionIDs)
    }
}
