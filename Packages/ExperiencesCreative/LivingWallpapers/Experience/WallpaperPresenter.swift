// WallpaperPresenter — feature 139 (A19-P02) T-A19-207 (FR-A19-203, FR-A19-204, FR-A19-205, FR-A19-207; clarifications
// Q2–Q5; contracts/experience.md). Draws Living Wallpapers through the host only and owns its presentation state:
//
//   - Scene: one `FullScreenShaderScene` (`SceneShaders.makeScene(scene:)`), made and set up in `setup` for the scene
//     shown, and made again in every repeated `setup` (after a context recreation the host calls `setup` again, so
//     the scene is rebuilt from the core's state). A scene change seen in `draw` tears the old scene down and sets
//     the new one up (`sceneBuildCount` counts the builds); a preset or parameter change only sets uniforms. A
//     compile or link error throws `SceneShaderError`, which fails the session's setup or draw with its message.
//   - Draw: the uniforms come from the core (the preset's colours in linear light, the three parameters, the seed's
//     offsets, the tier's level) and the time: `fixedTime` is the core's animation time when motion is off or
//     Reduce Motion is on (every frame identical), else the frame time × 1. An offscreen still at time t
//     (`ExperienceSession.renderStill(width:height:time:)`) therefore shows the scene at t while moving, and the
//     chosen animation time while still. One full-screen draw per frame.
//   - Overlay and words: the canvas overlay is `CropOverlay` (the template's frame and its approximate guides);
//     the canvas label is the scene, the preset, the template device, the orientation and the oriented pixel size
//     (`describe`). The probe is the canvas's top-leading corner, `dark` (the scenes shade their corners).
//   - Export: `export(using:)` runs the presenter's `StillExport` (one temporary folder) on the core's project with
//     the environment's timed still renderer and the edge limit recorded at `setup`
//     (`context.resources.maxTextureSize`; a size the host still refuses fails with the reason `render`).
//
// Feature 140 (A19-P03) T-A19-303, T-A19-307, T-A19-309 (FR-A19-301–305): the palette uniforms are the core's
// `palette`, the edited colours when `custom` is 1 and the preset's otherwise; the mirror carries `custom` and the
// twelve components for the colour editor; the controls get the presenter's export limit (`maxEdge`) and their
// ``EditorModel`` (notice, result line, help and the announcement of each export outcome).
//
// Feature 141 (A19-P04) T-A19-405, T-A19-407 (FR-A19-403, FR-A19-404): the controls export through the presenter's
// ``ExportJob`` (the one shipping path, over the same `StillExport` step code and folder), which records each written
// export in the presenter's ``HistoryStore`` when one is given; `export(using:)` and `export(plan:using:)` stay as
// the synchronous composition of the same steps for the tests. ``stillRender(_:)`` turns the environment's renderer
// into the job's renderer.
//
// No GL call: everything is drawn through VisualCoreRendering's scene; no platform-wallpaper call.
import Foundation
import LivingWallpapersCore
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// What the overlay and the controls show, updated only when a field changes.
@MainActor
@Observable
final class WallpaperMirror {
    /// The scene's index (0–3).
    var scene = 0
    /// The preset's index (0–2).
    var preset = 0
    /// The three parameter values (unused ones 0).
    var parameters = WallpaperCore.defaultParameters(scene: 0)
    /// The template's index (0–8).
    var template = WallpaperCore.defaultTemplate
    /// The orientation: 0 portrait, 1 landscape.
    var orientation = 0
    /// The animation time, seconds.
    var animationTime = 0.0
    /// The format's index (0 png, 1 jpeg, 2 heic).
    var format = 0
    /// Whether the scene moves.
    var motion = true
    /// Whether the colours are edited (0 or 1).
    var custom = 0
    /// The twelve colour components shown (the preset's while `custom` is 0).
    var colors = WallpaperCore.presetComponents(scene: 0, preset: 0)

    /// The template's definition.
    var templateDefinition: CanvasTemplate {
        CanvasTemplates.all[min(max(template, 0), CanvasTemplates.all.count - 1)]
    }

    /// The orientation as the core model names it.
    var orientationValue: Orientation { orientation == 1 ? .landscape : .portrait }
}

/// Draws Living Wallpapers and owns its presentation state (see the file header).
@MainActor
final class WallpaperPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = WallpaperCore

    /// Whether Reduce Motion was on when the experience was made: the scene is then still.
    let reduceMotion: Bool
    /// What the overlay and the controls show.
    let mirror = WallpaperMirror()
    /// The export attempt (its temporary folder is `LivingWallpapers-Export`).
    let stillExport: StillExport
    /// The editor's model: notice, result line, help and announcements (feature 140).
    let editor: EditorModel
    /// The stored history of written exports; nil when the experience was made without storage (feature 141).
    let history: HistoryStore?
    /// The export job of the controls, over `stillExport`'s step code and folder (feature 141).
    let job: ExportJob
    /// The scene drawn; made in `setup`, released in `teardown`.
    private(set) var scene: FullScreenShaderScene?
    /// The scene index of `scene`.
    private(set) var shownScene = 0
    /// How many times a scene program was built (each `setup` and each scene change).
    private(set) var sceneBuildCount = 0
    /// The uniform time of the last frame drawn.
    private(set) var lastUniformTime = 0.0
    /// The quality tier of the last frame drawn.
    private(set) var lastTier = 0
    /// The number of full-screen draws of the last frame (1 when drawn, 0 otherwise).
    private(set) var lastDrawCount = 0
    /// The largest edge an export may plan, pixels: the context's texture limit recorded at `setup`; 0 before.
    private(set) var maxEdge = 0
    /// The core of the last frame drawn or followed (the export's project).
    private(set) var lastCore = WallpaperCore()
    /// The frame cap: 30 frames per second (the scenes move slowly).
    var maxFramesPerSecond: Int { 30 }

    /// A presenter; with `reduceMotion` on the scene never moves; `stillExport` is the export attempt, `history` the
    /// stored history the job records in and `editor` the editor's model.
    init(reduceMotion: Bool = false, stillExport: StillExport = StillExport(), history: HistoryStore? = nil,
         editor: EditorModel = EditorModel()) {
        self.reduceMotion = reduceMotion
        self.stillExport = stillExport
        self.history = history
        self.editor = editor
        self.job = ExportJob(export: stillExport, editor: editor, history: history)
    }

    // MARK: Time

    /// The uniform time: `animationTime` when `motion` is off or `reduceMotion` is on, else `frameTime` × 1 (0 for a
    /// non-finite frame time).
    static func uniformTime(frameTime: Double, animationTime: Double, motion: Bool, reduceMotion: Bool) -> Double {
        guard motion, !reduceMotion else { return animationTime }
        return frameTime.isFinite ? frameTime : 0
    }

    // MARK: Render scene

    /// Makes and sets up the shown scene's program (again after a recreation, from the core's last state); a
    /// compile or link error throws ``SceneShaderError``.
    func setup(_ context: RenderContext) throws {
        scene = nil
        maxEdge = context.resources.maxTextureSize
        try build(sceneIndex: lastCore.scene, context: context)
    }

    /// Makes scene `index`'s program and sets it up; on an error it is torn down again and the error thrown.
    private func build(sceneIndex index: Int, context: RenderContext) throws {
        let made = SceneShaders.makeScene(scene: index)
        try made.setup(context)
        sceneBuildCount += 1
        if let message = made.errorMessage {
            made.teardown(context)
            throw SceneShaderError(scene: index, message: message)
        }
        scene = made
        shownScene = SceneShaders.clamped(index)
    }

    /// Passes the new drawable size to the scene.
    func resize(_ context: RenderContext) {
        scene?.resize(context)
    }

    /// Follows a new scene of `core` (rebuilding the program), sets the uniforms of `core` at `tier` and the time of
    /// `frame`, and draws once.
    func draw(_ core: WallpaperCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        lastDrawCount = 0
        lastCore = core
        if core.scene != shownScene || scene == nil {
            if let old = scene { old.teardown(context) }
            scene = nil
            try build(sceneIndex: core.scene, context: context)
        }
        guard let scene else { return }
        let time = Self.uniformTime(frameTime: frame.time, animationTime: core.animationTime, motion: core.motion,
                                    reduceMotion: reduceMotion)
        scene.resize(context)
        scene.palette = SceneShaders.palette(colors: core.palette)
        scene.parameters = SceneShaders.parameters(core.parameters, tier: tier)
        scene.seedOffsets = SceneShaders.seedOffsets(seed: core.seed)
        scene.fixedTime = time
        try scene.render(context, frame: frame)
        lastUniformTime = time
        lastTier = tier
        lastDrawCount = 1
    }

    /// Releases the scene's program.
    func teardown(_ context: RenderContext) {
        scene?.teardown(context)
        scene = nil
        lastDrawCount = 0
    }

    // MARK: Words, probes and views

    /// Brings the mirror up to `core` (each field written only when it changes).
    func follow(_ core: WallpaperCore) {
        lastCore = core
        if mirror.scene != core.scene { mirror.scene = core.scene }
        if mirror.preset != core.preset { mirror.preset = core.preset }
        if mirror.parameters != core.parameters { mirror.parameters = core.parameters }
        if mirror.template != core.template { mirror.template = core.template }
        if mirror.orientation != core.orientation { mirror.orientation = core.orientation }
        if mirror.animationTime != core.animationTime { mirror.animationTime = core.animationTime }
        if mirror.format != core.format { mirror.format = core.format }
        if mirror.motion != core.motion { mirror.motion = core.motion }
        if mirror.custom != core.custom { mirror.custom = core.custom }
        if mirror.colors != core.colors { mirror.colors = core.colors }
    }

    /// The canvas label: "<scene>, <preset>, <template label>", for example "Aurora Bands, Polar Night, iPhone 16
    /// Pro, portrait, 1206 by 2622 pixels".
    func describe(_ core: WallpaperCore) -> String {
        follow(core)
        return core.sceneDefinition.name + ", " + core.presetDefinition.name + ", "
            + CropOverlay.label(template: core.templateDefinition, orientation: core.orientationValue)
    }

    /// One probe at the top-leading corner, expected `dark` (every scene shades its corners).
    func probes(_ core: WallpaperCore) -> [FrameProbe] {
        [FrameProbe(name: "corner", x: 0, y: 0, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The crop frame and guides over the canvas (``CropOverlay``).
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(CropOverlay(mirror: mirror))
    }

    /// The native controls (``WallpaperControls``), sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(WallpaperControls(port: port, mirror: mirror, presenter: self, model: editor))
    }

    /// The actions of the native controls: all ten.
    var nativeActions: Set<String> { Set(WallpaperCore.actionIDs) }

    // MARK: Export

    /// Exports the core's project (the last core drawn or followed) with `renderer` at the recorded edge limit.
    @discardableResult
    func export(using renderer: ExperienceStillRenderer) -> StillExport.Output? {
        func render(_ width: Int, _ height: Int, _ time: Double) throws(OffscreenRenderError) -> StillImage {
            try renderer(width: width, height: height, time: time)
        }
        return stillExport.run(project: lastCore.project, maxEdge: maxEdge, render: render)
    }

    /// Exports the offered fallback `plan` (a refusal's `offeredPlan(format:)`) at the core's animation time with
    /// `renderer` (feature 140).
    @discardableResult
    func export(plan: ExportPlan, using renderer: ExperienceStillRenderer) -> StillExport.Output? {
        func render(_ width: Int, _ height: Int, _ time: Double) throws(OffscreenRenderError) -> StillImage {
            try renderer(width: width, height: height, time: time)
        }
        return stillExport.run(plan: plan, time: lastCore.animationTime, render: render)
    }

    /// The job's renderer over the environment's timed still `renderer` (feature 141).
    static func stillRender(_ renderer: ExperienceStillRenderer) -> StillExport.Render {
        { (width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage in
            try renderer(width: width, height: height, time: time)
        }
    }

    /// The core's project (the last core drawn or followed), what the job exports (feature 141).
    var project: WallpaperProject { lastCore.project }

    /// The planner's result for the core's project at the recorded edge limit (what the notice describes).
    var plannedExport: Result<ExportPlan, ExportRefusal> {
        ExportPlanner.plan(project: lastCore.project, maxEdge: maxEdge)
    }
}
