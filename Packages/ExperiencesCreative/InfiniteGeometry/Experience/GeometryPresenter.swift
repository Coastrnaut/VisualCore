// GeometryPresenter — feature 040 (A05-P01) T-A05-105 (FR-A05-121, FR-A05-132). Draws the core of Infinite Geometry
// through the host only: the host's context and registry, VisualCore's `PrimitiveRenderer` for the 2D compositions
// and `MeshRenderer` for the 3D one; no context, no second renderer, no network, no imported assets.
//
//   - The composition is rebuilt from the core's preset only when the core's composition digest changes, and the
//     2D scene tree with it (the palette is part of the preset, so a palette change is a new digest).
//   - 2D: a root `SceneNode` scaled so that the square −1…1 fills the shorter side of the view, one polygon node per
//     composition polygon, coloured from `Palette.builtIns[palette]` sampled by the polygon's colour index.
//   - 3D: one `MeshRenderer` for the current solid, recreated (the old one released) when the digest changes, seen
//     through `OrbitCamera(distance: 6, pitch: 0.5)`. Depth testing is left off (the renderer culls back faces).
//   - The probe is a background point the CPU proves uncovered: a point of a fixed grid that lies outside every
//     polygon by a margin (2D), or outside the projected bounds of the mesh (3D); it must read `dark`.
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
    typealias Core = GeometryCore

    /// The camera of the 3D composition.
    static let orbit = OrbitCamera(distance: 6, pitch: 0.5)
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
    private var meshRenderer: MeshRenderer?
    /// The composition digest `meshRenderer` was made for.
    private var meshDigest: String?
    /// The composition digest of `composition`.
    private var compositionKey: String?
    /// The current composition, rebuilt only when the core's composition digest changes.
    private(set) var composition: Composition?
    /// The 2D scene tree of `composition`; nil for a solid.
    private var root: SceneNode?
    /// The number of elements of the last draw: polygons for a plane, triangles for a solid.
    private(set) var drawnCount = 0

    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
    }

    func draw(_ core: GeometryCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        mirror.canvasSize = Vec2(width, height)
        try clear.render(context, frame: frame)
        refresh(core)
        switch composition {
        case .plane(let polygons):
            guard let root else { drawnCount = 0; return }
            let fit = min(width, height) / 2
            root.scale = Vec2(fit, fit)
            if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
            try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
            drawnCount = polygons.count
        case .solid(let mesh):
            if meshRenderer == nil || meshDigest != compositionKey {
                meshRenderer?.release()
                meshRenderer = nil
                meshRenderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                meshDigest = compositionKey
            }
            try meshRenderer?.draw(camera: Self.orbit, aspect: width / height,
                                   color: Self.color(palette: core.preset.palette, index: 4))
            drawnCount = mesh.triangleCount
        case nil:
            drawnCount = 0
        }
    }

    func teardown(_ context: RenderContext) {
        primitives?.release()
        primitives = nil
        meshRenderer?.release()
        meshRenderer = nil
        meshDigest = nil
        drawnCount = 0
    }

    /// Drops the composition and its scene tree; the next draw rebuilds them from the core.
    func shedCaches() {
        composition = nil
        compositionKey = nil
        root = nil
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

    func describe(_ core: GeometryCore) -> String {
        mirror.core = core
        return "Infinite Geometry: \(GeometryCore.kindName(core.preset.kind)), \(GeometryCore.symmetryText(core.preset)), "
            + "\(core.elementCount) elements."
    }

    /// One background probe that must read `dark`: the first candidate the CPU proves uncovered by the composition.
    func probes(_ core: GeometryCore) -> [FrameProbe] {
        guard let built = core.composition() else { return [] }
        let size = mirror.canvasSize
        guard let point = Self.backgroundPoint(built, size: size) else { return [] }
        return [FrameProbe(name: "background", x: point.x, y: point.y, expected: "dark")].compactMap { $0 }
    }

    /// The first probe candidate that no element of `composition` covers in a view of `size` pixels, or nil.
    static func backgroundPoint(_ composition: Composition, size: Vec2) -> (x: Double, y: Double)? {
        let width = max(size.x, 1), height = max(size.y, 1)
        switch composition {
        case .plane(let polygons):
            let fit = min(width, height) / 2
            let margin = probeMarginPixels / fit
            return probeCandidates.first { candidate in
                let world = Vec2((candidate.x - 0.5) * width / fit, (0.5 - candidate.y) * height / fit)
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
        AnyView(GeometryControls(port: port, mirror: mirror))
    }

    /// The six actions of the native controls.
    var nativeActions: Set<String> {
        ["preset.select", "symmetry.order", "repeats.set", "scale.set", "palette.set", "reseed"]
    }
}
