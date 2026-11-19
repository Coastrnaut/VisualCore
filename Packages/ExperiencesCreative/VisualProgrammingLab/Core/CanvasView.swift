// CanvasView — feature 167 (A23-P02) T-A23-204 (FR-A23-204; SC-A23-203; clarification Q3; data-model.md
// "CanvasView"). The person's view of the node canvas on the screen: a centre (the canvas point at the middle of the
// view), a zoom (screen points per canvas point, 0.5…2, 1 by default) and the view size in screen points.
// Choices recorded here: it wraps VisualCoreMath's `PlaneViewport`, whose plane y grows up, so a canvas point (x, y)
// is the plane point (x, −y). After every viewport operation the zoom is clamped to 0.5…2 and the centre to ±4,096 on
// both axes; a pinch is applied with the scale that reaches the clamped zoom, so the canvas point under the anchor
// stays fixed unless the centre bound is reached. Non-finite input leaves the view unchanged; an invalid initial size
// becomes 1 × 1 (the viewport's rule). A view change never touches the graph. Pure; no UI, GPU or clock.
import Foundation
import VisualCoreMath

/// The mapping between the node canvas (canvas points, origin top-left, y down) and the screen (points, origin
/// top-left, y down), with a bounded zoom and a bounded centre.
public struct CanvasView: Equatable, Sendable {
    /// The smallest zoom (screen points per canvas point).
    public static let minZoom = 0.5
    /// The largest zoom (screen points per canvas point).
    public static let maxZoom = 2.0
    /// The bound of the centre on each axis, in canvas points.
    public static let centreBound = 4_096.0

    private var viewport: PlaneViewport

    /// A view of `size` screen points centred on `centre` at `zoom`. A non-finite centre becomes the origin and a
    /// non-finite or non-positive zoom becomes 1; both are then clamped to their bounds.
    public init(size: Vec2, centre: CanvasPoint = CanvasPoint(x: 0, y: 0), zoom: Double = 1) {
        let z = zoom.isFinite && zoom > 0 ? zoom : 1
        let c = centre.isFinite ? centre : CanvasPoint(x: 0, y: 0)
        viewport = Self.bounded(PlaneViewport(center: Vec2(c.x, -c.y), unitsPerPoint: 1 / z, size: size))
    }

    private init(viewport: PlaneViewport) {
        self.viewport = Self.bounded(viewport)
    }

    /// Screen points per canvas point, within ``minZoom``…``maxZoom``.
    public var zoom: Double { 1 / viewport.unitsPerPoint }

    /// The canvas point at the middle of the view, within ±``centreBound`` on each axis.
    public var centre: CanvasPoint { CanvasPoint(x: viewport.center.x, y: -viewport.center.y) }

    /// The view size in screen points (positive and finite).
    public var size: Vec2 { viewport.size }

    /// The canvas point under the screen point `p`.
    public func canvas(fromScreen p: Vec2) -> CanvasPoint {
        let plane = viewport.plane(fromScreen: p)
        return CanvasPoint(x: plane.x, y: -plane.y)
    }

    /// The screen point of the canvas point `p`.
    public func screen(fromCanvas p: CanvasPoint) -> Vec2 {
        viewport.screen(fromPlane: Vec2(p.x, -p.y))
    }

    /// The view zoomed by `scale` (> 1 magnifies) about the screen point `anchor`: the zoom is clamped to
    /// ``minZoom``…``maxZoom`` and the canvas point under `anchor` stays put (unless the centre bound is reached).
    /// A non-finite or non-positive scale or a non-finite anchor leaves the view unchanged.
    public func pinched(by scale: Double, anchor: Vec2) -> CanvasView {
        guard scale.isFinite, scale > 0, anchor.isFinite else { return self }
        let target = Self.clampZoom(zoom * scale)
        return CanvasView(viewport: viewport.pinched(by: target / zoom, anchor: anchor))
    }

    /// The view after a finger drag of `delta` screen points: the content follows the finger and the centre is
    /// clamped to ±``centreBound``. A non-finite delta leaves the view unchanged.
    public func panned(by delta: Vec2) -> CanvasView {
        guard delta.isFinite else { return self }
        return CanvasView(viewport: viewport.panned(by: delta))
    }

    /// The same centre and zoom on a view of `size` screen points (rotation, split view). A non-finite or
    /// non-positive size leaves the view unchanged.
    public func resized(to size: Vec2) -> CanvasView {
        CanvasView(viewport: viewport.resized(to: size))
    }

    private static func clampZoom(_ z: Double) -> Double {
        min(max(z, minZoom), maxZoom)
    }

    private static func clampCentre(_ v: Double) -> Double {
        min(max(v, -centreBound), centreBound)
    }

    private static func bounded(_ v: PlaneViewport) -> PlaneViewport {
        let z = clampZoom(1 / v.unitsPerPoint)
        let c = Vec2(clampCentre(v.center.x), clampCentre(v.center.y))
        if z == 1 / v.unitsPerPoint && c == v.center && !v.wasClamped { return v }
        return PlaneViewport(center: c, unitsPerPoint: 1 / z, size: v.size)
    }
}
