// GeometryPresenter — feature 040 (A05-P01) T-A05-105 (FR-A05-121, FR-A05-132). Draws the core of Infinite Geometry
// through the host only: the host's context and registry, VisualCore's `PrimitiveRenderer` for the 2D compositions
// and `MeshRenderer` for the 3D one; no context, no second renderer, no network, no imported assets.
//
//   - The composition is rebuilt from the core's preset only when the core's composition digest changes, and the
//     2D scene tree with it (the palette is part of the preset, so a palette change is a new digest).
//   - 2D: a root `SceneNode` scaled so that the square −1…1 fills the shorter side of the view, one polygon node per
//     composition polygon, coloured from `Palette.builtIns[palette]` sampled by the polygon's colour index.
//   - 3D: one `MeshRenderer` for the current solid, recreated (the old one released) when the digest changes, seen
//     through `OrbitCamera(distance: 6, pitch: 0.5)`. Depth testing was left off here (A05-P03 draws the solid
//     through a depth-correct pass, below).
//   - The probe is a background point the CPU proves uncovered: a point of a fixed grid that lies outside every
//     polygon by a margin (2D), or outside the projected bounds of the mesh (3D); it must read `dark`.
//
// Feature 041 (A05-P02) T-A05-204, T-A05-207 (FR-A05-201, FR-A05-203, FR-A05-212):
//   - The kaleidoscope is drawn by `KaleidoscopeShader` on a `FullScreenShaderScene` the presenter owns: made and
//     compiled in `setup` (so it is remade after a context loss), released in `teardown`; a compile or link error
//     throws `KaleidoscopeShaderError`, which fails the session's setup with its message. The tilings keep the
//     primitive renderer and the 3D composition the mesh renderer.
//   - The core's 2D camera moves the tilings' root node (scale fit · zoom, position −centre · fit · zoom) and the
//     shader's world point; the core's orbit camera is the mesh renderer's camera.
//   - Canvas gestures become camera actions: one finger drags `camera.pan` (2D; screen points converted to world
//     units by the fit and zoom) or `camera.orbit` (3D; 0.01 rad per point), two fingers pinch `camera.zoom` (the
//     distance ratio), a double tap sends `camera.reset`. Each has a button in `GeometryControls`.
//
// Feature 042 (A05-P03) T-A05-304, T-A05-306 (FR-A05-301–303, FR-A05-315):
//   - The 3D composition is drawn through VisualCoreRendering's `DepthMeshPass` (one item: the solid's
//     `MeshRenderer` with its palette colour), so nearer petals hide farther ones from every angle, on screen and
//     offscreen; the pass is made in `setup` and released in `teardown` (it is remade after a context loss). The 2D
//     presets keep their Phase 02 renderers.
//   - Two fingers on the 3D composition pan the target with the centroid's movement (the composition follows the
//     fingers: world delta = −movement · 2 · distance · tan(fov / 2) / view height, y down on screen) alongside the
//     pinch zoom; the field of view has buttons only (`camera.fov`), and the canvas description states it.
//
// Feature 044 (A05-P05) T-A05-505 (FR-A05-506, FR-A05-510; spec Clarifications):
//   - The 3D composition is drawn at the quality tier's tessellation (`GeometryCore.drawSegments`: 24, 16, 12 or 8
//     segments), taken from a presenter-owned `MeshCache` keyed by `Composition.meshSignature(_:segments:)`; a
//     repeated signature (a preset drawn again, a tier set back) is not rebuilt. The core's reference composition
//     (digest, bounds, probe) stays at 24 segments; every lower tier's vertices lie inside its bounding sphere.
//   - The drawn mesh is chosen once at the start of a render, so a tier change switches the mesh between frames,
//     never during one; the `MeshRenderer` is recreated whenever the drawn signature changes.
//   - The cache holds CPU meshes only: a context recreation (teardown, setup) rebuilds the GPU renderer from the
//     cached mesh without building it again. `shedCaches()` empties it.
//   - `pixelPoint(world:size:view:)` is the one world-to-pixel mapping of the 2D presets (the fit of the shorter side
//     times the zoom, equal on both axes); the root node's transform, the probe and the proportion test use it.
import Foundation
import InfiniteGeometryCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreScenes

/// The latest core the presenter saw and the drawable size in pixels, for the controls and the probe.
@MainActor
@Observable
final class GeometryMirror {
    /// The core of the last description.
    var core: GeometryCore?
    /// The drawable size in pixels of the last draw.
    var canvasSize = Vec2(390, 390)
}

/// The presenter of Infinite Geometry.
@MainActor
final class GeometryPresenter: ExperiencePresenter {
    /// The scale that fits the square −1…1 into a `width` × `height` view: the same factor on both axes, half the
    /// shorter side, so a non-square view keeps geometric proportions (regression fixture 5; A05-P01).
    static func fitScale(width: Double, height: Double) -> Vec2 {
        let fit = min(width, height) / 2
        return Vec2(fit, fit)
    }

    /// The pixel position (x from the left, y up from the bottom) of world point `world` in a view of `size` pixels
    /// seen through the 2D camera `view`: `size / 2 + (world − centre) · fit · zoom`, with the same `fitScale` on
    /// both axes, so a world unit in x and in y spans the same number of pixels on every view shape (FR-A05-520).
    static func pixelPoint(world: Vec2, size: Vec2, view: GeometryCore.View2D) -> Vec2 {
        let fit = pixelsPerWorld(size: size, view: view)
        return Vec2(size.x / 2 + (world.x - view.centerX) * fit.x, size.y / 2 + (world.y - view.centerY) * fit.y)
    }

    /// Pixels per world unit on each axis in a view of `size` pixels through `view`: `fitScale` times the zoom (the
    /// same on both axes).
    static func pixelsPerWorld(size: Vec2, view: GeometryCore.View2D) -> Vec2 {
        fitScale(width: max(size.x, 1), height: max(size.y, 1)) * view.zoom
    }

    /// The world point at pixel `pixel` (x from the left, y up from the bottom): the inverse of `pixelPoint`.
    static func worldPoint(pixel: Vec2, size: Vec2, view: GeometryCore.View2D) -> Vec2 {
        let fit = pixelsPerWorld(size: size, view: view)
        return Vec2((pixel.x - size.x / 2) / fit.x + view.centerX, (pixel.y - size.y / 2) / fit.y + view.centerY)
    }

    typealias Core = GeometryCore

    /// The camera of the 3D composition at the preset's default.
    static let orbit = GeometryCore.Orbit3D.default.camera
    /// The orbit angle of one point of one-finger drag on the 3D composition, in radians.
    static let orbitPerPoint = 0.01
    /// The probe candidates, measured from the top left: the corners first, then the edge midpoints, then a grid.
    static let probeCandidates: [(x: Double, y: Double)] = {
        var points: [(x: Double, y: Double)] = [(0.04, 0.04), (0.96, 0.04), (0.04, 0.96), (0.96, 0.96),
                                               (0.5, 0.04), (0.04, 0.5), (0.96, 0.5), (0.5, 0.96)]
        for row in 1..<10 { for column in 1..<10 { points.append((Double(column) / 10, Double(row) / 10)) } }
        return points
    }()
    /// The margin around a polygon or the mesh's bounds that a probe point keeps, in pixels.
    static let probeMarginPixels = 4.0

    let experienceID: ExperienceID
    let mirror = GeometryMirror()
    private let clear = ClearColorScene()
    private var primitives: PrimitiveRenderer?
    /// The kaleidoscope's full-screen shader; made in `setup`, released in `teardown`.
    private var kaleidoscope: FullScreenShaderScene?
    /// The 2D camera of the last draw, for converting drag distances into world units.
    private var lastView = GeometryCore.View2D.default
    /// The kind of the last draw: drags orbit on the 3D composition and pan otherwise.
    private var lastKind = GeometryPreset.curated[0].kind
    /// The orbit camera of the last draw, for converting two-finger movement into a target pan.
    private var lastOrbit = GeometryCore.Orbit3D.default
    /// The depth-correct pass the 3D composition is drawn through; made in `setup`, released in `teardown`.
    private var depthPass: DepthMeshPass?

    // Touch translation (presentation state, never domain state).
    private var pointers = PointerTracker()
    private var doubleTap = DoubleTapRecognizer()
    private var lastPoint: [Int: Vec2] = [:]
    private var meshRenderer: MeshRenderer?
    /// The mesh signature `meshRenderer` was made for (`Composition.meshSignature(_:segments:)`).
    private var meshSignature: UInt64?
    /// The CPU meshes of the drawn 3D composition by signature (preset shape and tier); kept across context
    /// recreations, emptied by `shedCaches()` (FR-A05-510).
    let meshCache = MeshCache()
    /// The number of triangles of the 3D mesh drawn by the last render (0 when no solid was drawn).
    private(set) var drawnTriangleCount = 0
    /// The revolution segments of the 3D mesh drawn by the last render (0 when no solid was drawn).
    private(set) var drawnSegments = 0
    /// The composition digest of `composition`.
    private var compositionKey: String?
    /// The current composition, rebuilt only when the core's composition digest changes.
    private(set) var composition: Composition?
    /// The 2D scene tree of `composition`; nil for a solid.
    private var root: SceneNode?
    /// The number of elements of the last draw: polygons for a plane, triangles for a solid.
    private(set) var drawnCount = 0

    /// The saved compositions shown by the controls (feature 043); nil in tests that need no library.
    let library: GeometryLibrary?

    init(experienceID: ExperienceID, library: GeometryLibrary? = nil) {
        self.experienceID = experienceID
        self.library = library
    }

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        let scene = KaleidoscopeShader.makeScene()
        try scene.setup(context)
        if let message = scene.errorMessage {
            scene.teardown(context)
            throw KaleidoscopeShaderError(message: message)
        }
        kaleidoscope = scene
        depthPass = Self.makeDepthPass(context)
    }

    /// A depth-correct mesh pass on the registry of `context`, clearing to the black background of the clear scene.
    private static func makeDepthPass(_ context: RenderContext) -> DepthMeshPass {
        let pass = DepthMeshPass(registry: context.resources)
        pass.clearColor = Vec4(0, 0, 0, 1)
        return pass
    }

    func resize(_ context: RenderContext) {
        kaleidoscope?.resize(context)
    }

    func draw(_ core: GeometryCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        mirror.canvasSize = Vec2(width, height)
        try clear.render(context, frame: frame)
        refresh(core)
        lastView = core.view2D
        lastKind = core.preset.kind
        lastOrbit = core.orbit3D
        drawnTriangleCount = 0       // set again below when a solid is drawn
        drawnSegments = 0
        switch composition {
        case .plane(let polygons) where core.preset.kind == .kaleidoscope:
            guard let kaleidoscope else { drawnCount = 0; return }
            kaleidoscope.resize(context)
            kaleidoscope.parameters = KaleidoscopeShader.parameters(for: core)
            kaleidoscope.palette = KaleidoscopeShader.palette(core.preset.palette)
            try kaleidoscope.render(context, frame: frame)
            drawnCount = polygons.count
        case .plane(let polygons):
            guard let root else { drawnCount = 0; return }
            // The node transform is `pixelPoint(world:size:view:)` about the view's centre.
            let perWorld = Self.pixelsPerWorld(size: Vec2(width, height), view: core.view2D)
            root.scale = perWorld
            root.position = Vec2(-core.view2D.centerX * perWorld.x, -core.view2D.centerY * perWorld.y)
            if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
            try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
            drawnCount = polygons.count
        case .solid(let reference):
            // The tier is read once, here at the start of the render: the drawn mesh switches between frames only.
            let segments = core.drawSegments
            let signature = Composition.meshSignature(core.preset, segments: segments)
            let preset = core.preset
            let mesh = try meshCache.mesh(for: signature) {
                // At full tessellation the reference composition's mesh is the drawn mesh (no second build).
                if segments == Composition.petalSegments { return reference }
                return try Composition.solidMesh(preset, segments: segments)
            }
            if meshRenderer == nil || meshSignature != signature {
                meshRenderer?.release()
                meshRenderer = nil
                meshRenderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                meshSignature = signature
            }
            guard let meshRenderer else { drawnCount = 0; return }
            if depthPass == nil { depthPass = Self.makeDepthPass(context) }
            let item = DepthMeshPass.Item(renderer: meshRenderer, color: Self.color(palette: core.preset.palette, index: 4))
            try depthPass?.draw([item], camera: core.orbit3D.camera, context: context)
            drawnCount = mesh.triangleCount
            drawnTriangleCount = mesh.triangleCount
            drawnSegments = segments
        case nil:
            drawnCount = 0
        }
    }

    func teardown(_ context: RenderContext) {
        primitives?.release()
        primitives = nil
        kaleidoscope?.teardown(context)
        kaleidoscope = nil
        meshRenderer?.release()
        meshRenderer = nil
        meshSignature = nil          // the CPU meshes in `meshCache` stay valid; only the GPU renderer is rebuilt
        depthPass?.release()
        depthPass = nil
        drawnCount = 0
    }

    /// Drops the composition, its scene tree and the cached CPU meshes; the next draw rebuilds them from the core.
    func shedCaches() {
        composition = nil
        compositionKey = nil
        root = nil
        meshCache.removeAll()
    }

    /// Rebuilds the composition and the 2D tree when the core's composition digest differs from the cached one.
    private func refresh(_ core: GeometryCore) {
        guard compositionKey != core.compositionDigest || composition == nil else { return }
        composition = core.composition()
        compositionKey = core.compositionDigest
        root = nil
        if case .plane(let polygons) = composition {
            let tree = SceneNode(id: "composition")
            for (index, polygon) in polygons.enumerated() {
                tree.add(SceneNode(id: "p\(index)", primitive: .polygon(polygon.points),
                                   color: Self.color(palette: core.preset.palette, index: polygon.colorIndex)))
            }
            root = tree
        }
    }

    /// The colour of colour index `index` in built-in palette `palette`: the palette sampled at (index mod 6 + 1) / 6,
    /// converted from linear light to sRGB, opaque. The darkest stop is skipped so a polygon stands out from black.
    static func color(palette: Int, index: Int) -> Vec4 {
        let palettes = Palette.builtIns
        let p = palettes[min(max(palette, 0), palettes.count - 1)]
        let slot = ((index % 6) + 6) % 6
        let c = p.sample(Double(slot + 1) / 6)
        return Vec4(Palette.sRGB(fromLinear: c.x), Palette.sRGB(fromLinear: c.y), Palette.sRGB(fromLinear: c.z), 1)
    }

    /// The canvas description: kind, symmetry and element count, and on the 3D composition the field of view
    /// (FR-A05-315), e.g. "…, 288 elements, field of view 60°."
    func describe(_ core: GeometryCore) -> String {
        mirror.core = core
        let fov = core.preset.kind == .solid ? ", field of view \(Self.degreesText(core.orbit3D.fovDegrees))" : ""
        return "Infinite Geometry: \(GeometryCore.kindName(core.preset.kind)), \(GeometryCore.symmetryText(core.preset)), "
            + "\(core.elementCount) elements\(fov)."
    }

    /// An angle in degrees as spoken and shown: whole degrees, e.g. "60°".
    static func degreesText(_ degrees: Double) -> String {
        String(format: "%.0f°", degrees)
    }

    /// One background probe that must read `dark`: the first candidate the CPU proves uncovered by the composition.
    func probes(_ core: GeometryCore) -> [FrameProbe] {
        guard let built = core.composition() else { return [] }
        let size = mirror.canvasSize
        guard let point = Self.backgroundPoint(built, size: size, view: core.view2D, orbit: core.orbit3D.camera)
        else { return [] }
        return [FrameProbe(name: "background", x: point.x, y: point.y, expected: "dark")].compactMap { $0 }
    }

    /// The first probe candidate that no element of `composition` covers in a view of `size` pixels seen through
    /// the 2D camera `view` (planes) or the orbit camera `orbit` (solids), or nil.
    static func backgroundPoint(_ composition: Composition, size: Vec2, view: GeometryCore.View2D = .default,
                                orbit: OrbitCamera = GeometryPresenter.orbit) -> (x: Double, y: Double)? {
        let width = max(size.x, 1), height = max(size.y, 1)
        switch composition {
        case .plane(let polygons):
            let fit = Self.fitScale(width: width, height: height).x * view.zoom
            let margin = probeMarginPixels / fit
            let size = Vec2(width, height)
            return probeCandidates.first { candidate in
                // Candidates are measured from the top left; `worldPoint` takes y up from the bottom.
                let world = worldPoint(pixel: Vec2(candidate.x * width, (1 - candidate.y) * height), size: size,
                                       view: view)
                return !polygons.contains { covers($0.points, world, margin: margin) }
            }
        case .solid(let mesh):
            let vp = orbit.viewProjection(aspect: width / height)
            var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
            for p in mesh.positions {
                let clip = vp * Vec4(p, 1)
                guard clip.w > 1e-9 else { return nil }
                minX = min(minX, clip.x / clip.w); maxX = max(maxX, clip.x / clip.w)
                minY = min(minY, clip.y / clip.w); maxY = max(maxY, clip.y / clip.w)
            }
            let mx = 2 * probeMarginPixels / width, my = 2 * probeMarginPixels / height
            return probeCandidates.first { candidate in
                let nx = candidate.x * 2 - 1, ny = 1 - candidate.y * 2
                return nx < minX - mx || nx > maxX + mx || ny < minY - my || ny > maxY + my
            }
        }
    }

    /// Whether `point` lies inside `polygon` or within `margin` of one of its edges.
    static func covers(_ polygon: [Vec2], _ point: Vec2, margin: Double) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            if distance(point, a, b) <= margin { return true }
            j = i
        }
        return inside
    }

    /// The distance from `p` to the segment `a`–`b`.
    private static func distance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a
        let lengthSquared = ab.dot(ab)
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let t = min(max((p - a).dot(ab) / lengthSquared, 0), 1)
        return p.distance(to: a + ab * t)
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(GeometryControls(port: port, mirror: mirror, library: library))
    }

    /// The six preset actions, the four camera actions and the field of view and the open action of the native controls (every gesture
    /// action has a button; the field of view has buttons and no gesture).
    var nativeActions: Set<String> {
        let presetActions: Set<String> = ["preset.select", "symmetry.order", "repeats.set", "scale.set", "palette.set", "reseed"]
        return presetActions.union(Self.cameraActions).union(["camera.fov", "composition.open"])
    }

    /// The camera actions a canvas gesture sends (FR-A05-212).
    var gestureActions: Set<String> { Self.cameraActions }

    /// The four camera action ids.
    static let cameraActions: Set<String> = ["camera.pan", "camera.zoom", "camera.orbit", "camera.reset"]

    /// Canvas touches as camera actions (FR-A05-212, FR-A05-315; spec Clarifications): one finger moving pans the 2D
    /// view by its movement converted to world units (the content follows the finger) or orbits the 3D composition
    /// by 0.01 rad per point; two fingers zoom by the ratio of their distances and, on the 3D composition, pan the
    /// target by the centroid's movement (`solidPan`); a double tap resets the camera. Values are clamped into the
    /// controls' ranges so a fast gesture is never refused as out of range.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        let side = min(viewSize.x, viewSize.y)
        guard side > 0 else { return }
        let previous = lastPoint
        pointers.handle(event)
        doubleTap.handle(event, tracker: pointers)
        if event.phase == .began, doubleTap.state == .failed {
            // A tap that came too late for the previous one starts a new double tap.
            doubleTap.reset()
            doubleTap.handle(event, tracker: pointers)
        }
        if doubleTap.state == .recognized {
            port.send("camera.reset")
            doubleTap.reset()
        }
        if event.phase == .moved, pointers.count >= 2 {
            let ids = Array(pointers.order.prefix(2))
            if let a0 = previous[ids[0]], let b0 = previous[ids[1]],
               let a1 = pointers.active[ids[0]], let b1 = pointers.active[ids[1]] {
                let d0 = a0.distance(to: b0), d1 = a1.distance(to: b1)
                if lastKind == .solid,
                   let pan = Self.solidPan(centroidMove: (a1 + b1) * 0.5 - (a0 + b0) * 0.5, viewHeight: viewSize.y,
                                           orbit: lastOrbit) {
                    port.send("camera.pan", pan)
                }
                if d0 > 0, d1 > 0, d1 != d0 {
                    port.send("camera.zoom", [Self.clamp(d1 / d0, GeometryCore.zoomFactorRange)])
                }
            }
        } else if event.phase == .moved, pointers.count == 1, let last = previous[event.id] {
            let move = event.location - last
            if move.x == 0, move.y == 0 {
                // No movement, no action.
            } else if lastKind == .solid {
                let range = GeometryCore.orbitRange
                port.send("camera.orbit", [Self.clamp(-move.x * Self.orbitPerPoint, range),
                                           Self.clamp(move.y * Self.orbitPerPoint, range)])
            } else {
                // Points per world unit: half the shorter side times the zoom (the fit in points).
                let perWorld = side / 2 * max(lastView.zoom, 1e-6)
                let range = GeometryCore.panRange
                port.send("camera.pan", [Self.clamp(-move.x / perWorld, range), Self.clamp(move.y / perWorld, range)])
            }
        }
        switch event.phase {
        case .began, .moved: lastPoint[event.id] = event.location
        case .ended, .cancelled: lastPoint[event.id] = nil
        }
        if pointers.count == 0 { lastPoint.removeAll() }
    }

    /// The `camera.pan` values of a two-finger centroid movement `centroidMove` (view points, y down) on the 3D
    /// composition seen through `orbit` in a view `viewHeight` points high, or nil when nothing moves: one point is
    /// 2 · distance · tan(fov / 2) / height world units at the target, and the target moves against the fingers so
    /// the composition follows them (x negated; y negated twice, as the screen's y points down).
    static func solidPan(centroidMove: Vec2, viewHeight: Double, orbit: GeometryCore.Orbit3D) -> [Double]? {
        guard viewHeight > 0, centroidMove.x != 0 || centroidMove.y != 0 else { return nil }
        let perPoint = 2 * orbit.distance * tan(orbit.fovDegrees * Double.pi / 360) / viewHeight
        let range = GeometryCore.panRange
        return [clamp(-centroidMove.x * perPoint, range), clamp(centroidMove.y * perPoint, range)]
    }

    /// `value` clamped into `range`; a non-finite value counts as 0.
    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        let v = value.isFinite ? value : 0
        return min(max(v, range.lowerBound), range.upperBound)
    }
}
