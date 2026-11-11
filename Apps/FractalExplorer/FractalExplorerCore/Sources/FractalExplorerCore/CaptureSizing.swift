// CaptureSizing.swift — the long edge of a still capture, limited by what the shader's precision can show (feature 029
// T-A03-407; FR-A03-405; US2; spec 029 clarification 1; research R5). A capture never claims more detail than the
// numbers hold: past the limit, more pixels would only repeat the same values.
import Foundation
import VisualCoreMath

/// The capture long edge for a view.
public enum CaptureSizing {
    /// The requested long edge of a capture.
    public static let requestedLongEdge = 4096

    /// The long edge in pixels: at most `requested`, at most what keeps each pixel's plane step at or above the
    /// precision advisor's minimum for `mantissaBits`, and never below the canvas's own long edge in pixels; even.
    /// `limited` is true when precision lowered it below `requested`.
    public static func longEdge(requested: Int = requestedLongEdge, viewport: PlaneViewport, pixelsPerPoint: Double,
                                mantissaBits: Int) -> (longEdge: Int, limited: Bool) {
        let longPoints = max(viewport.size.x, viewport.size.y)
        let spanLong = viewport.unitsPerPoint * longPoints
        let magnitude = max(abs(viewport.center.x), abs(viewport.center.y))
        let minStep = PrecisionAdvisor.minimumPixelStep(mantissaBits: mantissaBits, magnitude: magnitude)
        let precise = spanLong / minStep
        let canvas = (longPoints * (pixelsPerPoint.isFinite && pixelsPerPoint > 0 ? pixelsPerPoint : 1)).rounded(.down)
        let wanted = Double(max(2, requested))
        let edge = max(min(wanted, precise.rounded(.down)), min(canvas, wanted))
        let even = max(2, Int(edge) - Int(edge) % 2)
        return (even, even < max(2, requested) - requested % 2)
    }
}
