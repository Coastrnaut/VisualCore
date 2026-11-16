// SimulationPresenter — feature 117 (A16-P01) T-A16-105 (FR-A16-130; plan "Lifecycle"); feature 118 (A16-P02)
// T-A16-203 (FR-A16-201, 202, 204; clarification Q2). Draws Simulation Lab through the one host's drawing path. The
// cellular automaton is drawn from its GPU field (``AutomatonGPU``, an RGBA8 ping-pong pair stepped in lockstep with
// the engine); reaction-diffusion and the wave are colour-mapped on the CPU (``SimulationPalette``) and uploaded into
// a 64 × 64 `rgba8` `RenderTarget` until A16-P03. One `FieldPass` display program per path
// (``SimulationShaders/automatonDisplay``, ``SimulationShaders/display``) draws into the host's framebuffer.
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
    private var mirroredField: FieldGrid?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The square the grid was drawn into, in pixels (origin x, origin y, side); nil before the first frame.
    private(set) var lastSquare: (x: Double, y: Double, side: Double)?
    /// The registry the target and the pass were made with (held weakly, as the host owns it).
    private weak var registry: ResourceRegistry?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
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
        let width = max(1, context.pixelWidth), height = max(1, context.pixelHeight)
        lastCanvas = Vec2(Double(width), Double(height))
        if target == nil || display == nil || automatonDisplay == nil || automaton == nil {
            releaseGPU()
            try makeResources(context)
        }
        guard let target, let display, let automatonDisplay, let automaton else { return }
        let field = core.model.field
        if lastField != field || lastKind != core.kind {
            lastField = field
            lastKind = core.kind
            lastPixels = core.kind == .automaton ? [] : SimulationPalette.rgba(field, kind: core.kind)
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
        let step = core.stepCount
        let current = core.model.field.current
        let delta = step - mirroredStep
        let mustLoad = mirroredSpec != spec || delta < 0 || delta > Self.maxStepsPerFrame
            || (delta == 0 && mirroredField != current)
        if mustLoad {
            guard automaton.load(current) else { throw SimulationDrawError.uploadFailed }
            gpuLoadCount += 1
            uploadCount += 1
        } else if delta > 0 {
            try automaton.step(rule: spec.automatonRule, count: delta)
            gpuStepCount += delta
        }
        mirroredSpec = spec
        mirroredStep = step
        mirroredField = current
    }

    /// Forgets what the GPU automaton field mirrors, so the next automaton frame loads it from the CPU state.
    private func invalidateMirror() {
        mirroredSpec = nil
        mirroredStep = 0
        mirroredField = nil
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
        } catch {
            madeAutomatonDisplay?.release()
            madeDisplay?.release()
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
        uploaded = false
        invalidateMirror()
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
        let status = core.status
        if mirror.status != status { mirror.status = status }
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
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
        default: return "That is not possible here."
        }
    }

    /// Sends `control` with `values` through `port` and shows the answer in the mirror (empty when accepted).
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], through port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.message = Self.answerWords(control: control, result: result)
        return result
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

    /// The actions the native controls send: every action.
    var nativeActions: Set<String> {
        Set(SimulationCore.actionIDs)
    }
}
