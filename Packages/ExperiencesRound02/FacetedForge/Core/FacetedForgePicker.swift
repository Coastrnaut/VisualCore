// FacetedForgePicker — feature 374 (R02-G08-04) T-R02G0804-002 (FR-R02G0804-001, 002, 003, 005; SC-R02G0804-001;
// clarifications Q1 "How is a touch picked?", Q2 "How does a rim drag become a direction?" and Q3 "How does a depth
// drag move the plane?"). Analytic, deterministic picking of a touch in the drawn Faceted Forge crystal. The touch
// point (view points, origin top left, y down; the size is the view's size in points) becomes the ray of the drawn
// camera (`FacetedForgeSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected by the
// shared `ScreenProjection` (R02-F22). "Opened" means moved by
// `FacetedForgeSceneGeometry.offset(piece:_:reduceMotion:)` (the preview polygon with the chosen piece's offset). In
// order: the opened preview polygon's projected outline within 22 points (the minimum target) is the rim; the ray
// meeting the opened preview polygon, or the touch inside its projection, is the plane; the nearest opened face polygon
// of a piece hit by the ray picks that piece; else a projected opened piece centre within 22 points (the nearest, ties
// to the lower index); else empty space. `tilt` turns a rim drag into one of the 13 directions and the crossing depth
// nearest the plane through the preview centre; `depthSteps` turns a drag on the plane into whole depth steps of 24
// points along the plane's projected normal. Presentation only: the picker reads the drawn snapshot, the orbit and (for
// the crossing depths) the play, and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Faceted Forge crystal.
public enum FacetedForgePick: Sendable, Equatable {
    /// The preview rim: the touch lies within ``FacetedForgePicker/minimumTarget`` points of the opened preview
    /// polygon's projected outline (the handle that tilts the plane).
    case rim
    /// The preview interior (the depth slider): the touch ray meets the opened preview polygon, or the touch lies
    /// inside its projection.
    case plane
    /// Piece `index`: the nearest opened face polygon hit by the touch ray belongs to it, or (when no face is hit) its
    /// projected opened centre is the nearest within ``FacetedForgePicker/minimumTarget`` points.
    case piece(Int)
    /// Nothing: no preview, no piece face under the touch and no piece centre within
    /// ``FacetedForgePicker/minimumTarget`` points.
    case empty
}

/// The analytic picker of the Faceted Forge crystal: the touch ray against the opened preview polygon, its rim and the
/// opened pieces' faces, with a 22-point minimum touch target; the rim tilt and the depth steps of a drag.
public enum FacetedForgePicker {
    /// The minimum touch target in view points, 22: a touch at most this far from the opened preview polygon's
    /// projected outline picks the rim; when no face is hit, a piece whose projected opened centre lies at most this
    /// far from it is picked.
    public static let minimumTarget: Double = 22
    /// The drag in view points along the plane's projected normal that moves the depth by one crossing depth, 24.
    public static let pointsPerDepthStep: Double = 24
    /// The world length of the normal step whose projection gives the screen direction of a depth drag, 0.1.
    static let normalProbe: Double = 0.1

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: FacetedForgeCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let direction: SIMD3<Double> = FacetedForgeSceneGeometry.unit(SIMD3(r.direction.x, r.direction.y,
                                                                            r.direction.z))
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard direction != .zero, origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height, the pieces opened as drawn (`reduceMotion` as the
    /// scene's): ``FacetedForgePick/rim`` when the point lies within ``minimumTarget`` points of the opened preview
    /// polygon's projected outline; else ``FacetedForgePick/plane`` when the ray meets that polygon or the point lies
    /// inside its projection; else ``FacetedForgePick/piece(_:)`` for the piece owning the nearest opened face polygon
    /// the ray meets ahead (ties to the lower index); else the piece whose projected opened centre is nearest within
    /// ``minimumTarget`` points (ties to the lower index); else ``FacetedForgePick/empty``. ``FacetedForgePick/empty``
    /// too for non-finite input, an unusable size or a point outside the view. Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: FacetedForgeSceneSnapshot,
                            orbit: FacetedForgeOrbit, reduceMotion: Bool) -> FacetedForgePick {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        let preview: [SIMD3<Double>] = openedPreview(snapshot, reduceMotion: reduceMotion)
        if preview.count >= 3 {
            var outline: [SIMD2<Double>] = []
            for corner in preview {
                guard let v = FacetedForgeSceneGeometry.project(corner, camera: camera) else { break }
                outline.append(SIMD2(v.x * size.x, v.y * size.y))
            }
            let projected: Bool = outline.count == preview.count
            if projected, outlineDistance(point, outline) <= minimumTarget { return .rim }
            if polygonHit(origin: r.origin, direction: r.direction, polygon: preview) != nil { return .plane }
            if projected, inside(point, outline) { return .plane }
        }
        var nearest: Double = .infinity
        var hitPiece: Int?
        for (index, piece) in snapshot.pieces.enumerated() {
            let shift: SIMD3<Double> = FacetedForgeSceneGeometry.offset(piece: index, snapshot,
                                                                        reduceMotion: reduceMotion)
            for face in piece.faces {
                var polygon: [SIMD3<Double>] = []
                for corner in FacetedForgeSceneGeometry.points(face, piece.corners) { polygon.append(corner + shift) }
                guard let t = polygonHit(origin: r.origin, direction: r.direction, polygon: polygon),
                      t < nearest else { continue }
                nearest = t
                hitPiece = index
            }
        }
        if let hitPiece { return .piece(hitPiece) }
        var centres: [SIMD2<Double>?] = []
        for index in snapshot.pieces.indices {
            let centre: SIMD3<Double> = FacetedForgeSceneGeometry.pieceCentre(index, snapshot,
                                                                              reduceMotion: reduceMotion)
            centres.append(FacetedForgeSceneGeometry.project(centre, camera: camera).map {
                SIMD2($0.x * size.x, $0.y * size.y)
            })
        }
        if let index = nearestWithin(point, centres, limit: minimumTarget) { return .piece(index) }
        return .empty
    }

    /// The choice after a rim drag of `drag` view points (x right, y down) in a view of `size` points showing
    /// `snapshot` from `orbit`: with n0 the unit normal of `choice`'s direction and R, U the camera's right and up unit
    /// vectors in world space, the dragged orientation is normalize(n0 + (dx·R − dy·U) · 2 / min(width, height)); the
    /// new direction is the one of the 13 whose unit vector has the largest |dot| with it (ties to the lower index).
    /// The depth is the crossing depth of the chosen piece (`FacetedForgeSolver.crossingDepths`) nearest to round(n ·
    /// c), n the new direction's integer vector and c the snapshot's preview centre in kernel coordinates (the plane
    /// through the same point; n · c snapped to 1e-6 first, so an exact half of the kernel's rational centre rounds
    /// away from zero whatever the Double error), ties to the smaller depth; the middle crossing depth when the
    /// snapshot has no preview; `choice`'s depth when no depth crosses. `choice` unchanged for an unknown piece,
    /// unusable input or a degenerate dragged orientation. A zero drag keeps the choice. Presentation only.
    ///
    /// Rounding note: n · c is snapped to a multiple of 1e-6, then rounded half away from zero (`roundedTarget`).
    public static func tilt(_ choice: FacetedForgePreviewChoice, drag: SIMD2<Double>, size: SIMD2<Double>,
                            snapshot: FacetedForgeSceneSnapshot, play: FacetedForgePlay,
                            orbit: FacetedForgeOrbit) -> FacetedForgePreviewChoice {
        guard play.pieces.indices.contains(choice.piece), drag.x.isFinite, drag.y.isFinite,
              let camera = camera(size: size, snapshot: snapshot, orbit: orbit) else { return choice }
        let axes: (right: SIMD3<Double>, up: SIMD3<Double>) = screenAxes(camera)
        let n0: SIMD3<Double> = unitNormal(choice.direction)
        let scale: Double = 2 / min(size.x, size.y)
        let dragged: SIMD3<Double> = FacetedForgeSceneGeometry.unit(
            n0 + (axes.right * drag.x - axes.up * drag.y) * scale)
        guard dragged != .zero else { return choice }
        let direction: Int = nearestDirection(dragged)
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[choice.piece], direction: direction)
        guard !crossing.isEmpty else {
            return FacetedForgePreviewChoice(piece: choice.piece, direction: direction, depth: choice.depth)
        }
        var depth: Int = crossing[crossing.count / 2]
        if let c = previewKernelCentre(snapshot, play: play) {
            let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
            let value: Double = Double(d.x) * c.x + Double(d.y) * c.y + Double(d.z) * c.z
            if let target = roundedTarget(value), let nearest = nearestDepth(crossing, to: target) { depth = nearest }
        }
        return FacetedForgePreviewChoice(piece: choice.piece, direction: direction, depth: depth)
    }

    /// The whole depth steps of a drag of `drag` view points (x right, y down) on the plane in a view of `size` points
    /// showing `snapshot` from `orbit`: round(s / ``pointsPerDepthStep``), s the drag's component along the unit screen
    /// direction from the projection of the opened preview centre to the projection of that centre plus 0.1 times the
    /// unit normal of the snapshot's direction (positive towards +n, the larger depths). 0 when there is no preview,
    /// for unusable input, or when the projection degenerates.
    public static func depthSteps(drag: SIMD2<Double>, size: SIMD2<Double>, snapshot: FacetedForgeSceneSnapshot,
                                  orbit: FacetedForgeOrbit, reduceMotion: Bool) -> Int {
        guard drag.x.isFinite, drag.y.isFinite,
              let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let centre = FacetedForgeSceneGeometry.previewCentre(snapshot, reduceMotion: reduceMotion),
              let a = FacetedForgeSceneGeometry.project(centre, camera: camera),
              let b = FacetedForgeSceneGeometry.project(centre + unitNormal(snapshot.choice.direction) * normalProbe,
                                                        camera: camera) else { return 0 }
        let along: SIMD2<Double> = SIMD2((b.x - a.x) * size.x, (b.y - a.y) * size.y)
        let length: Double = (along * along).sum().squareRoot()
        guard length > 1e-9, length.isFinite else { return 0 }
        let s: Double = (drag * along).sum() / length
        let steps: Double = (s / pointsPerDepthStep).rounded()
        guard steps.isFinite, abs(steps) < 1e6 else { return 0 }
        return Int(steps)
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size.
    static func camera(size: SIMD2<Double>, snapshot: FacetedForgeSceneSnapshot,
                       orbit: FacetedForgeOrbit) -> FacetedForgeCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else { return nil }
        return FacetedForgeSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// The camera's right and up unit vectors in world space: right = normalize(forward × +y), up = right × forward,
    /// forward the unit vector from the eye to the target (the axes of `Mat4.lookAt`).
    static func screenAxes(_ camera: FacetedForgeCamera) -> (right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = FacetedForgeSceneGeometry.unit(camera.target - camera.eye)
        let right: SIMD3<Double> = FacetedForgeSceneGeometry.unit(
            FacetedForgeSceneGeometry.cross(forward, SIMD3(0, 1, 0)))
        return (right, FacetedForgeSceneGeometry.cross(right, forward))
    }

    /// The unit vector of direction `index` (0 … 12, clamped).
    static func unitNormal(_ index: Int) -> SIMD3<Double> {
        let clamped: Int = min(max(index, 0), FacetedForgeDirection.all.count - 1)
        let d: FacetedForgeDirection = FacetedForgeDirection.all[clamped]
        return FacetedForgeSceneGeometry.unit(SIMD3(Double(d.x), Double(d.y), Double(d.z)))
    }

    /// The direction (0 … 12) whose unit vector has the largest |dot| with `v`, ties to the lower index.
    static func nearestDirection(_ v: SIMD3<Double>) -> Int {
        var best: Int = 0
        var bestDot: Double = -1
        for index in FacetedForgeDirection.all.indices {
            let value: Double = abs(FacetedForgeSceneGeometry.dot(unitNormal(index), v))
            if value > bestDot {
                bestDot = value
                best = index
            }
        }
        return best
    }

    /// `value` snapped to a multiple of 1e-6 (the kernel's preview centre is rational with small denominators, so this
    /// removes the Double error of its world round trip) and rounded half away from zero; nil when not finite.
    static func roundedTarget(_ value: Double) -> Double? {
        guard value.isFinite, abs(value) < 1e9 else { return nil }
        return ((value * 1e6).rounded() / 1e6).rounded()
    }

    /// The depth of `depths` nearest to `value`, ties to the smaller depth; nil for no depths.
    static func nearestDepth(_ depths: [Int], to value: Double) -> Int? {
        var best: Int?
        var bestDistance: Double = .infinity
        for depth in depths.sorted() {
            let distance: Double = abs(Double(depth) - value)
            if distance < bestDistance {
                bestDistance = distance
                best = depth
            }
        }
        return best
    }

    /// The index of the point of `points` nearest to `point` within `limit` (nil entries skipped), ties to the lower
    /// index; nil when none lies within `limit`.
    static func nearestWithin(_ point: SIMD2<Double>, _ points: [SIMD2<Double>?], limit: Double) -> Int? {
        var best: Int?
        var bestDistance: Double = .infinity
        for (index, candidate) in points.enumerated() {
            guard let candidate else { continue }
            let d: SIMD2<Double> = candidate - point
            let distance: Double = (d * d).sum().squareRoot()
            if distance <= limit && distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// The snapshot's preview polygon opened with the chosen piece's offset (empty without a preview).
    static func openedPreview(_ snapshot: FacetedForgeSceneSnapshot, reduceMotion: Bool) -> [SIMD3<Double>] {
        let shift: SIMD3<Double> = FacetedForgeSceneGeometry.offset(piece: snapshot.choice.piece, snapshot,
                                                                    reduceMotion: reduceMotion)
        var result: [SIMD3<Double>] = []
        for corner in snapshot.preview { result.append(corner + shift) }
        return result
    }

    /// The snapshot's preview centre in kernel coordinates: the mean of the preview corners times the snapshot's scale
    /// plus the crystal's corner centroid (computed from `play`'s crystal exactly as `FacetedForgeSceneSnapshot` does);
    /// nil without a preview.
    static func previewKernelCentre(_ snapshot: FacetedForgeSceneSnapshot, play: FacetedForgePlay) -> SIMD3<Double>? {
        guard !snapshot.preview.isEmpty else { return nil }
        let mean: SIMD3<Double> = snapshot.preview.reduce(SIMD3<Double>(0, 0, 0), +) / Double(snapshot.preview.count)
        let raw: [SIMD3<Double>] = play.level.crystal.corners.map(FacetedForgeSceneSnapshot.vector)
        let centroid: SIMD3<Double> = raw.reduce(SIMD3<Double>(0, 0, 0), +) / Double(max(raw.count, 1))
        return mean * snapshot.scale + centroid
    }

    /// The distance t > 0 along the unit `direction` from `origin` at which the ray meets the planar convex `polygon`
    /// (corners in order, either winding; the edges included); nil when it misses, runs parallel to the plane or the
    /// polygon is degenerate.
    static func polygonHit(origin: SIMD3<Double>, direction: SIMD3<Double>, polygon: [SIMD3<Double>]) -> Double? {
        guard polygon.count >= 3 else { return nil }
        let n: SIMD3<Double> = FacetedForgeSceneGeometry.newell(polygon)
        guard n != .zero else { return nil }
        let denominator: Double = FacetedForgeSceneGeometry.dot(n, direction)
        guard abs(denominator) > 1e-15 else { return nil }
        let t: Double = FacetedForgeSceneGeometry.dot(n, polygon[0] - origin) / denominator
        guard t > 0, t.isFinite else { return nil }
        let hit: SIMD3<Double> = origin + direction * t
        for i in polygon.indices {
            let a: SIMD3<Double> = polygon[i]
            let b: SIMD3<Double> = polygon[(i + 1) % polygon.count]
            if FacetedForgeSceneGeometry.dot(FacetedForgeSceneGeometry.cross(b - a, hit - a), n) < -1e-12 { return nil }
        }
        return t
    }

    /// The distance in view points from `point` to the closed polyline `outline` (the nearest point on any edge).
    static func outlineDistance(_ point: SIMD2<Double>, _ outline: [SIMD2<Double>]) -> Double {
        var best: Double = .infinity
        for k in outline.indices {
            let a: SIMD2<Double> = outline[k]
            let ab: SIMD2<Double> = outline[(k + 1) % outline.count] - a
            let lengthSquared: Double = (ab * ab).sum()
            let t: Double = lengthSquared > 0 ? min(max(((point - a) * ab).sum() / lengthSquared, 0), 1) : 0
            let d: SIMD2<Double> = a + ab * t - point
            best = min(best, (d * d).sum().squareRoot())
        }
        return best
    }

    /// Whether `point` lies inside (or on) the convex polygon `outline` of either winding.
    static func inside(_ point: SIMD2<Double>, _ outline: [SIMD2<Double>]) -> Bool {
        guard outline.count >= 3 else { return false }
        var positive: Bool = false
        var negative: Bool = false
        for k in outline.indices {
            let a: SIMD2<Double> = outline[k]
            let b: SIMD2<Double> = outline[(k + 1) % outline.count]
            let side: Double = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if side > 0 { positive = true }
            if side < 0 { negative = true }
        }
        return !(positive && negative)
    }
}
