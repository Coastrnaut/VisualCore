// AnatomyPresenter — feature 125 (A17-P02) T-A17-204 (FR-A17-202, FR-A17-204, FR-A17-205, FR-A17-207, FR-A17-208;
// clarifications Q2–Q5; contracts/scene.md; plan "Lifecycle"). Draws Interactive Anatomy through the host only (the
// host's context and registry, VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of
// its own, no second renderer, no assets). The presenter reads the core and never writes it:
//   - Renderers: one `MeshRenderer` per item mesh of the CURRENT tier's scene and one `DepthMeshPass` (backdrop
//     (0.07, 0.08, 0.10)), all made together in `setup` (after releasing everything; again after a context
//     recreation), all released and made again in `draw` when one is missing or the tier changed, and all released
//     together with the pass in `teardown`. Every mesh renderer shares one cached program in the host's registry and
//     releasing a renderer releases it for all, so no renderer is ever released on its own.
//   - Items: the scene's visible items (`visibleItems` of the shown layers) in item order, each with its model matrix
//     and its layer's colour (bones ivory, cartilage and menisci blue-grey, ligaments and tendons rose); the selected
//     part's items are amber.
//   - Camera: `AnatomyCore.camera(aspect:)` at the drawable's pixel aspect (the framed part's sphere, else the
//     region's). Framing and Reset view cut to the new view in one frame, so Reduce Motion changes nothing.
//   - Pointer: one tap declaration (`pick`, `.tap`, one finger) over VisualCore's `GestureArbiter`; a recognized tap
//     becomes a normalised device point and is picked with the camera and aspect of the LAST DRAWN frame
//     (`AnatomyPicker.pick(ndc:camera:aspect:scene:visible:)`), so what is tapped is what was seen: a hit sends
//     `structure.select [i]`, a miss `structure.clear`. Drags and any touch with a second finger send nothing.
//   - Probe: the backdrop at (0.5, 0.04) from the top, expected dark, when the line of sight there meets no visible
//     part.
//   - Words: the canvas description of `AnatomyCore.describe()`; the mirror holds what the controls show.
import Foundation
import InteractiveAnatomyCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// One row of the structure list: a part's English name and layer.
struct AnatomyPartRow: Equatable, Sendable {
    /// The English name.
    let name: String
    /// The layer.
    let layer: AnatomyLayer
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class AnatomyMirror {
    /// Whether a state was seen.
    var ready = false
    /// The parts in inventory order.
    var parts: [AnatomyPartRow] = []
    /// Whether each layer is shown (bones, cartilage, ligaments).
    var visibleLayers = [true, true, true]
    /// The selected part's index, or nil.
    var selected: Int?
    /// The camera steps.
    var camera = AnatomyCameraState.opening
    /// The answer to the last refused control action; empty when it was accepted.
    var message = ""
}

/// Draws Interactive Anatomy and owns its presentation state (renderers and the depth pass; see the file header).
@MainActor
public final class AnatomyPresenter: ExperiencePresenter {
    /// The backdrop colour.
    nonisolated static let backgroundColor = Vec4(0.07, 0.08, 0.10, 1)
    /// The bones' colour (ivory).
    nonisolated static let bonesColor = Vec4(0.90, 0.86, 0.76, 1)
    /// The cartilage and menisci colour (blue-grey).
    nonisolated static let cartilageColor = Vec4(0.55, 0.70, 0.85, 1)
    /// The ligaments and tendons colour (rose).
    nonisolated static let ligamentsColor = Vec4(0.80, 0.45, 0.45, 1)
    /// The selected part's colour (amber).
    nonisolated static let selectionColor = Vec4(1.00, 0.80, 0.20, 1)
    /// The ambient light fraction of every renderer.
    nonisolated static let ambient = 0.3
    /// The one canvas gesture: a single-finger tap that picks.
    nonisolated static let declarations = [GestureDeclaration(id: "pick", kind: .tap, priority: 1, pointers: 1)]

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = AnatomyMirror()
    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// The renderers of the current tier's item meshes, by mesh id; empty after `teardown`.
    private(set) var renderers: [String: MeshRenderer] = [:]
    /// The tier the renderers were made for; nil while there are none.
    private(set) var rendererTier: Int?
    /// The depth-correct pass; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?
    /// How many times the renderers were made (all together each time).
    private(set) var resourceBuildCount = 0
    /// The camera of the last frame; nil before the first frame.
    private(set) var lastCamera: OrbitCamera?
    /// The pixel aspect (width / height) of the last frame.
    private(set) var lastAspect = 1.0
    /// The mesh ids drawn by the last frame, in draw order.
    private(set) var lastDrawnMeshIDs: [String] = []
    /// The tier of the last frame.
    private(set) var lastTier = 0
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The core of the last frame or description; nil before the first.
    private(set) var lastCore: AnatomyCore?
    /// The tap arbiter.
    private var arbiter = GestureArbiter(AnatomyPresenter.declarations)
    /// The fingers down now.
    private var fingers: Set<Int> = []
    /// Whether a second finger landed since the first went down (the touch then sends nothing).
    private var multiTouch = false

    /// The number of renderers made now.
    var rendererCount: Int { renderers.count }

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass and the current tier's renderers with the host's registry (again after a recreation).
    public func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        if let core = lastCore {
            try makeRenderers(core.scene, tier: core.tier, context: context)
        } else if let prepared = try? AnatomyCore.bundled.get(), prepared.scenes.indices.contains(lastTier) {
            try makeRenderers(prepared.scenes[lastTier], tier: lastTier, context: context)
        }
        isLive = true
    }

    /// Draws the visible items with depth through the core's camera at the pixel aspect.
    public func draw(_ core: AnatomyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        let scene = core.scene
        if rendererTier != core.tier || renderers.count != scene.items.count
            || scene.items.contains(where: { renderers[$0.meshID] == nil }) {
            // Something is missing or the tier changed: release all together and make all again.
            releaseRenderers()
            try makeRenderers(scene, tier: core.tier, context: context)
        }
        guard let depthPass else { return }
        let aspect = width / height
        let camera = core.camera(aspect: aspect)
        let selected = core.selectedIndex
        depthPass.clearColor = Self.backgroundColor
        var items: [DepthMeshPass.Item] = []
        var drawn: [String] = []
        for item in scene.visibleItems(core.visibleLayers) {
            guard let renderer = renderers[item.meshID] else { continue }
            let color = item.structureIndex == selected ? Self.selectionColor : Self.color(item.layer)
            items.append(DepthMeshPass.Item(renderer: renderer, model: item.model, color: color))
            drawn.append(item.meshID)
        }
        try depthPass.draw(items, camera: camera, context: context)
        lastCamera = camera
        lastAspect = aspect
        lastDrawnMeshIDs = drawn
        lastTier = core.tier
        lastCanvas = Vec2(width, height)
    }

    /// Releases every GPU object.
    public func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastDrawnMeshIDs = []
        cancelPointers()
    }

    /// Releases the renderers and the depth pass, together.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases every renderer, together.
    private func releaseRenderers() {
        for renderer in renderers.values { renderer.release() }
        renderers = [:]
        rendererTier = nil
    }

    /// Makes one renderer per item mesh of `scene` (the scene of `tier`), together; a failure releases those made
    /// and rethrows.
    private func makeRenderers(_ scene: AnatomyScene, tier: Int, context: RenderContext) throws {
        var made: [String: MeshRenderer] = [:]
        do {
            for item in scene.items where made[item.meshID] == nil {
                let renderer = try MeshRenderer(mesh: item.mesh, registry: context.resources)
                renderer.ambient = Self.ambient
                made[item.meshID] = renderer
            }
        } catch {
            for renderer in made.values { renderer.release() }
            throw error
        }
        renderers = made
        rendererTier = tier
        resourceBuildCount += 1
    }

    /// The colour of `layer`.
    nonisolated static func color(_ layer: AnatomyLayer) -> Vec4 {
        switch layer {
        case .bones: return bonesColor
        case .cartilage: return cartilageColor
        case .ligaments: return ligamentsColor
        }
    }

    /// The backdrop probe at (0.5, 0.04) from the top, expected dark, when its line of sight meets no visible part.
    public func probes(_ core: AnatomyCore) -> [FrameProbe] {
        guard let canvas = lastCanvas, canvas.y > 0 else { return [] }
        let aspect = canvas.x / canvas.y
        let hit = AnatomyPicker.pick(ndc: Vec2(0, 1 - 2 * 0.04), camera: core.camera(aspect: aspect), aspect: aspect,
                                     scene: core.scene, visible: core.visibleLayers)
        guard hit == nil,
              let probe = FrameProbe(name: "background", x: 0.5, y: 0.04, expected: FrameColorClass.dark.rawValue)
        else { return [] }
        return [probe]
    }

    // MARK: Words and controls

    /// Shows `core` in the mirror.
    func sync(_ core: AnatomyCore) {
        lastCore = core
        if !mirror.ready { mirror.ready = true }
        let parts = core.scene.parts.map { AnatomyPartRow(name: $0.englishName, layer: $0.layer ?? .bones) }
        if mirror.parts != parts { mirror.parts = parts }
        if mirror.visibleLayers != core.view.visibleLayers { mirror.visibleLayers = core.view.visibleLayers }
        if mirror.selected != core.selectedIndex { mirror.selected = core.selectedIndex }
        if mirror.camera != core.view.camera { mirror.camera = core.view.camera }
    }

    /// The canvas description (`AnatomyCore.describe()`).
    public func describe(_ core: AnatomyCore) -> String {
        sync(core)
        return core.describe()
    }

    /// The native controls, sending through `port`.
    public func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AnatomyControls(port: port, mirror: mirror, presenter: self))
    }

    /// Every action has a native control.
    public var nativeActions: Set<String> { Set(AnatomyCore.actionIDs) }

    /// The actions a canvas tap sends.
    public var gestureActions: Set<String> { ["structure.select", "structure.clear"] }

    /// The answer to a refused `control` in words; empty when accepted.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        if result == .rejected(.rule(code: AnatomyRule.hiddenStructure)) {
            return "That structure is on a hidden layer."
        }
        switch control {
        case "camera.turn": return "The camera turns one step left or right."
        case "camera.tilt": return "The camera is tilted as far as it goes."
        case "camera.zoom": return "The camera is zoomed as far as it goes."
        case "structure.select": return "There is no such structure."
        case "layer.show": return "There is no such layer."
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

    // MARK: Pointer and picking

    /// Forgets every touch in progress (suspension and teardown).
    public func cancelPointers() {
        _ = arbiter.cancelAll()
        fingers = []
        multiTouch = false
    }

    /// A canvas touch: a single-finger tap picks (``tap(atNDC:through:)``); drags and multi-touch send nothing.
    public func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        if event.phase == .began {
            fingers.insert(event.id)
            if fingers.count > 1 { multiTouch = true }
        }
        var taps: [Vec2] = []
        for outcome in arbiter.handle(event) where outcome.gesture == "pick" && outcome.phase == .recognized {
            if outcome.values.count >= 2 { taps.append(Vec2(outcome.values[0], outcome.values[1])) }
        }
        let single = !multiTouch
        if event.phase == .ended || event.phase == .cancelled {
            fingers.remove(event.id)
            if fingers.isEmpty { multiTouch = false }
        }
        guard single else { return }
        for point in taps {
            guard let ndc = Self.ndc(of: point, viewSize: viewSize) else { continue }
            tap(atNDC: ndc, through: port)
        }
    }

    /// The normalised device point (x, y in −1…1, y up) of the view point `point` in a view of `viewSize` points;
    /// nil for an empty view or a non-finite point.
    nonisolated static func ndc(of point: Vec2, viewSize: Vec2) -> Vec2? {
        guard viewSize.x > 0, viewSize.y > 0, point.isFinite, viewSize.isFinite else { return nil }
        return Vec2(2 * point.x / viewSize.x - 1, 1 - 2 * point.y / viewSize.y)
    }

    /// Picks the part under `ndc` with the camera and aspect of the last drawn frame and sends
    /// `structure.select [i]` on a hit, `structure.clear` on a miss. Nil (nothing sent) before the first frame.
    @discardableResult
    func tap(atNDC ndc: Vec2, through port: ExperienceActionPort) -> ActionResult? {
        guard let camera = lastCamera, let core = lastCore else { return nil }
        if let hit = AnatomyPicker.pick(ndc: ndc, camera: camera, aspect: lastAspect, scene: core.scene,
                                        visible: core.visibleLayers) {
            return send("structure.select", [Double(hit.index)], through: port)
        }
        return send("structure.clear", through: port)
    }
}
