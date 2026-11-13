// FractalPreview.swift — a deterministic, bounded CPU picture of a fractal state (feature 026 T-A03-103; FR-A03-106;
// clarification 4). It proves the math end to end before the Phase 02 GPU render and becomes its comparison fixture.
import Foundation
import VisualCoreMath

/// RGBA pixels of a state's current view, at most `maximumSide` on the longer side, with the request that made it.
public struct FractalPreview: Sendable, Equatable {
    /// The pixel budget per side.
    public static let maximumSide = 160

    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// RGBA bytes, rows top-down, alpha 255.
    public let rgba: [UInt8]
    /// The identifier of the request (newer requests replace older ones).
    public let requestID: Int

    /// The RGB of pixel (x, y), top-left origin.
    public func rgb(_ x: Int, _ y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(rgba[i..<i + 3])
    }

    /// Renders `state` at most `maxSide` (≤ `maximumSide`) pixels on the longer side, keeping the view's aspect.
    /// Interior points are black; escaping points get a gray from the smooth value (brighter near the set).
    public static func render(_ state: FractalState, maxSide: Int = maximumSide, requestID: Int) -> FractalPreview {
        let side = min(max(maxSide, 1), maximumSide)
        let size = state.viewport.size
        let scale = Double(side) / max(size.x, size.y)
        let w = max(1, Int((size.x * scale).rounded())), h = max(1, Int((size.y * scale).rounded()))
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let screen = Vec2((Double(x) + 0.5) / Double(w) * size.x, (Double(y) + 0.5) / Double(h) * size.y)
                let r = state.escape(at: state.viewport.plane(fromScreen: screen))
                let v: UInt8 = r.interior ? 0 : UInt8(60 + 195 * (1 - exp(-max(r.smooth, 0) / 16)))
                let i = (y * w + x) * 4
                bytes[i] = v; bytes[i + 1] = v; bytes[i + 2] = v
            }
        }
        return FractalPreview(width: w, height: h, rgba: bytes, requestID: requestID)
    }
}
