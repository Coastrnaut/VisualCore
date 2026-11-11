// Camera2D.swift — pan / zoom / rotate camera for 2D scenes (feature 006 T-F503; FR-F501).
// World units are points at zoom 1, y up. `matrix` maps world → camera space (points from the view
// center, y up); ViewMetrics then maps camera space to view points, pixels and NDC.
import Foundation

public struct Camera2D: Sendable, Equatable {
    public static let zoomRange: ClosedRange<Double> = 0.1...100

    /// World point shown at the view center.
    public var center: Vec2
    /// Magnification, clamped to `zoomRange` (edge case: zoom limits).
    public var zoom: Double { didSet { zoom = Camera2D.clampZoom(zoom) } }
    /// Counter-clockwise rotation of the world on screen, radians.
    public var rotation: Double

    public init(center: Vec2 = .zero, zoom: Double = 1, rotation: Double = 0) {
        self.center = center
        self.zoom = Camera2D.clampZoom(zoom)
        self.rotation = rotation
    }

    static func clampZoom(_ z: Double) -> Double {
        guard z.isFinite else { return 1 }
        return min(max(z, zoomRange.lowerBound), zoomRange.upperBound)
    }

    /// World → camera space.
    public var matrix: Mat3 { Mat3.scale(Vec2(zoom, zoom)) * Mat3.rotation(rotation) * Mat3.translation(-center) }
    /// Camera space → world (always invertible: zoom > 0).
    public var inverse: Mat3 { Mat3.translation(center) * Mat3.rotation(-rotation) * Mat3.scale(Vec2(1 / zoom, 1 / zoom)) }

    /// Zooms by `factor` keeping the world point under `anchor` (camera space) fixed — pinch-to-zoom.
    public mutating func zoom(by factor: Double, around anchor: Vec2 = .zero) {
        guard factor.isFinite, factor > 0 else { return }
        let before = inverse.apply(anchor)
        zoom *= factor
        center += before - inverse.apply(anchor)
    }

    /// Pans by a camera-space delta (a drag moves the content with the finger).
    public mutating func pan(by delta: Vec2) { center -= Mat3.rotation(-rotation).applyVector(delta) / zoom }
}
