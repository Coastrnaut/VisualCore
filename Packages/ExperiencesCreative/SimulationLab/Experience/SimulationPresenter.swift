// SimulationPresenter — feature 117 (A16-P01) T-A16-105 (FR-A16-130; plan "Lifecycle"). Draws Simulation Lab through
// the one host's drawing path: the 64 × 64 CPU field is colour-mapped per family (``SimulationPalette``) and uploaded
// into a 64 × 64 `rgba8` `RenderTarget`, which one `FieldPass` display program draws into the host's framebuffer.
//
// The display program fits the grid into a square of side ⌊0.92 · min(width, height) / 64⌋ · 64 pixels (or
// ⌊0.92 · min(width, height)⌋ on a canvas under 70 pixels) centred on the canvas, and reads the cell under each pixel
// with `texelFetch` at the integer cell index (`gl_FragCoord` scaled to the grid), so cells are crisp squares and no
// filtering blends them; outside the square it draws the dark background. The margin is at least 4 % of the shorter
// side, so the probe `background` at (0.01, 0.01) always lands on it.
//
// Lifecycle: `setup` makes the target and the display pass together (releasing whatever an earlier context left) and,
// after a context recreation, uploads the last CPU field again at once; `draw` uploads the colour-mapped field only
// when the field or the family differ from the last upload, then runs the display pass; `teardown` releases both
// together.
// Something missing at draw time (a failed setup) releases both and makes both again, never one at a time. Drawing
// reads the core only: it never changes the state or its digest.
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

    /// The display program: the grid in a centred square with crisp cells, the background around it.
    nonisolated static let displayFragment = """
    precision highp float;
    uniform highp sampler2D uField;
    uniform vec2 uOrigin;
    uniform float uSide;
    uniform int uGrid;
    uniform vec4 uBackground;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec2 p = (gl_FragCoord.xy - uOrigin) / uSide;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
            color = uBackground;
            return;
        }
        ivec2 cell = clamp(ivec2(floor(p * float(uGrid))), ivec2(0), ivec2(uGrid - 1));
        color = vec4(texelFetch(uField, cell, 0).rgb, 1.0);
    }
    """

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = SimulationMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// The 64 × 64 field target; nil outside `setup` … `teardown`.
    private(set) var target: RenderTarget?
    /// The display pass; nil outside `setup` … `teardown`.
    private(set) var display: FieldPass?
    /// How many times the target and the pass were made (together each time).
    private(set) var resourceBuildCount = 0
    /// How many times a colour-mapped field was uploaded.
    private(set) var uploadCount = 0
    /// The field last colour-mapped (CPU data; survives a context loss); nil before the first state.
    private(set) var lastField: SimulationField?
    /// The family of ``lastField``.
    private(set) var lastKind: SimulationKind?
    /// The colour-mapped pixels of ``lastField`` (RGBA8, rows bottom-up).
    private(set) var lastPixels: [UInt8] = []
    /// Whether the target holds ``lastPixels`` (false after a new field or a new target).
    private(set) var uploaded = false
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

    /// Makes the target and the display pass together with the host's registry (again after a context recreation)
    /// and uploads the last CPU field into the new target when there is one.
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        try makeResources(context)
        isLive = true
        if !lastPixels.isEmpty { try upload() }
    }

    /// Uploads the colour-mapped field when it changed, then draws the grid into the host's framebuffer.
    func draw(_ core: SimulationCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = max(1, context.pixelWidth), height = max(1, context.pixelHeight)
        lastCanvas = Vec2(Double(width), Double(height))
        if target == nil || display == nil {
            releaseGPU()
            try makeResources(context)
        }
        guard let target, let display else { return }
        let field = core.model.field
        if lastField != field || lastKind != core.kind {
            lastField = field
            lastKind = core.kind
            lastPixels = SimulationPalette.rgba(field, kind: core.kind)
            uploaded = false
        }
        if !uploaded { try upload() }
        let square = Self.square(width: width, height: height, grid: SimulationCore.gridSize)
        lastSquare = square
        try display.run(output: .framebuffer(name: context.framebuffer, width: width, height: height),
                        inputs: ["uField": target],
                        uniforms: ["uOrigin": .vec2(SIMD2(Float(square.x), Float(square.y))),
                                   "uSide": .float(Float(square.side)),
                                   "uGrid": .int(Int32(SimulationCore.gridSize)),
                                   "uBackground": .vec4(SimulationPalette.backgroundRGBA)])
    }

    /// Releases the target and the pass together.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
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

    /// Makes the 64 × 64 `rgba8` target and the display pass together; a failure releases what was made and
    /// rethrows.
    private func makeResources(_ context: RenderContext) throws {
        let registry = context.resources
        let n = SimulationCore.gridSize
        let made = try registry.makeRenderTarget(width: n, height: n, format: .rgba8, label: "a16.field")
        do {
            display = try FieldPass(registry: registry, fragment: Self.displayFragment, inputs: ["uField"],
                                    label: "a16.display")
        } catch {
            registry.release(made)
            throw error
        }
        target = made
        self.registry = registry
        uploaded = false
        resourceBuildCount += 1
    }

    /// Releases the target and the display pass, together.
    private func releaseGPU() {
        if let target { registry?.release(target) }
        target = nil
        display?.release()
        display = nil
        uploaded = false
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
