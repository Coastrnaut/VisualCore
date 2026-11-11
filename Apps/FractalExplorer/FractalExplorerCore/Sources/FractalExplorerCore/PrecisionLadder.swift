// PrecisionLadder.swift — the device precision measurement's plan and verdict (feature 030 T-A03-504; FR-A03-502;
// US1; spec 030 clarification 1 and implementation finding). Pure and host-testable: the automation mode renders each
// step and fills in the agreement; this file decides which views to draw and whether the app's precision rules held.
import Foundation
import VisualCoreMath

/// A zoom ladder from the Seahorse Valley point, drawn at the screen's own pixel step.
public enum PrecisionLadder {
    /// The ladder's center (Seahorse Valley; a boundary point with detail at every scale).
    public static let center = Vec2(-0.743643887, 0.131825904)
    /// Zoom factor between steps.
    public static let factor = 4.0
    /// The most steps.
    public static let maxSteps = 24
    /// Pixels on each side of a measured patch.
    public static let patchPixels = 64
    /// Agreement needed for a step to count as drawn correctly.
    public static let threshold = 0.99

    /// One measured step.
    public struct Step: Codable, Equatable, Sendable {
        /// 0-based step.
        public let index: Int
        /// Magnification (factor^index).
        public let zoom: Double
        /// The app's precision level for the full canvas at this zoom.
        public let level: PrecisionMode.Level
        /// True when the app would clamp this zoom (it never shows it).
        public let clamped: Bool
        /// Share of patch pixels explained by the CPU reference (0…1): the class matches, or the pixel lies next to a
        /// CPU class change (boundary pixels may differ between 32-bit and 64-bit arithmetic; feature 027's rule).
        public let agreement: Double

        /// Creates a step.
        public init(index: Int, zoom: Double, level: PrecisionMode.Level, clamped: Bool, agreement: Double) {
            self.index = index; self.zoom = zoom; self.level = level; self.clamped = clamped; self.agreement = agreement
        }
    }

    /// The outcome.
    public struct Verdict: Equatable, Sendable {
        /// True when the app's rules held on this device.
        public let pass: Bool
        /// First step the app clamps, if any.
        public let clampStep: Int?
        /// First step drawn below the threshold, if any (the measured breakdown).
        public let breakdownStep: Int?
        /// The lowest agreement among steps the app calls reliable.
        public let minReliableAgreement: Double?
        /// Why it failed, or "ok".
        public let reason: String
    }

    /// The zooms of the ladder for a canvas of `canvas` points: factor^i for i = 0…, stopping before PlaneViewport's
    /// own finest scale would be reached (analyze I1) and after `maxSteps`.
    public static func zooms(canvas: Vec2, steps: Int = maxSteps) -> [Double] {
        let shortSide = max(1, min(canvas.x, canvas.y))
        var result: [Double] = []
        for i in 0..<max(0, min(steps, maxSteps)) {
            let zoom = pow(factor, Double(i))
            let unitsPerPoint = FractalState.defaultWidth(for: .mandelbrot) / zoom / shortSide
            if unitsPerPoint < PlaneViewport.minUnitsPerPoint { break }
            result.append(zoom)
        }
        return result
    }

    /// The full-canvas viewport of a zoom (what the app would show).
    public static func canvasViewport(zoom: Double, canvas: Vec2) -> PlaneViewport {
        PlaneFraming(center: center, span: FractalState.defaultWidth(for: .mandelbrot) / zoom).viewport(size: canvas)
    }

    /// The measured patch: the same center and plane step per device pixel as the canvas, `patchPixels` wide.
    public static func patchViewport(zoom: Double, canvas: Vec2, pixelsPerPoint: Double) -> PlaneViewport {
        let full = canvasViewport(zoom: zoom, canvas: canvas)
        let side = Double(patchPixels) / max(pixelsPerPoint, 0.01)
        return PlaneViewport(center: full.center, unitsPerPoint: full.unitsPerPoint, size: Vec2(side, side))
    }

    /// Whether the app clamps this zoom (its unitsPerPoint is below the advisor minimum × the display scale).
    public static func isClamped(zoom: Double, canvas: Vec2, mantissaBits: Int, pixelsPerPoint: Double) -> Bool {
        let v = canvasViewport(zoom: zoom, canvas: canvas)
        let minStep = PrecisionAdvisor.minimumPixelStep(mantissaBits: mantissaBits, magnitude: max(abs(v.center.x), abs(v.center.y)))
        return v.unitsPerPoint < minStep * pixelsPerPoint
    }

    /// The verdict: fail when a step the app calls reliable is drawn below the threshold (the advisor is overconfident
    /// on this device), or when the device breaks down within the ladder but the app never clamps. Steps near the
    /// limit carry the app's "details may blur" warning and are recorded, not judged.
    public static func verdict(_ steps: [Step]) -> Verdict {
        let clamp = steps.first { $0.clamped }?.index
        let breakdown = steps.first { $0.agreement < threshold }?.index
        let reliable = steps.filter { $0.level == .reliable && !$0.clamped }
        let minReliable = reliable.map(\.agreement).min()
        if let bad = reliable.first(where: { $0.agreement < threshold }) {
            return Verdict(pass: false, clampStep: clamp, breakdownStep: breakdown, minReliableAgreement: minReliable,
                           reason: "step \(bad.index) is reliable for the app but agrees only \(bad.agreement)")
        }
        if breakdown != nil, clamp == nil {
            return Verdict(pass: false, clampStep: nil, breakdownStep: breakdown, minReliableAgreement: minReliable,
                           reason: "the device breaks down at step \(breakdown!) but the app never clamps")
        }
        return Verdict(pass: true, clampStep: clamp, breakdownStep: breakdown, minReliableAgreement: minReliable, reason: "ok")
    }
}
