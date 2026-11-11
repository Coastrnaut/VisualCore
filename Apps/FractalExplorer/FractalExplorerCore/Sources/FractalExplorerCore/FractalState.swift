// FractalState.swift — the explorer's validated state: mode, plane viewport, Julia seed, iteration cap and escape
// radius, with the spoken description (feature 026 T-A03-103; FR-A03-101, FR-A03-105; clarification 5).
import Foundation
import VisualCoreMath

/// The two fractal families.
public enum FractalMode: String, CaseIterable, Sendable, Codable {
    case mandelbrot, julia

    /// The display name.
    public var name: String { self == .mandelbrot ? "Mandelbrot" : "Julia" }
}

/// Everything that defines the picture; every value is validated when it is set.
public struct FractalState: Sendable, Equatable {
    /// The default Julia seed c = −0.8 + 0.156i.
    public static let defaultSeed = Vec2(-0.8, 0.156)
    /// Plane width across the shorter side at zoom 1.
    public static func defaultWidth(for mode: FractalMode) -> Double { mode == .mandelbrot ? 4.0 : 3.2 }
    /// Plane center at zoom 1.
    public static func defaultCenter(for mode: FractalMode) -> Vec2 { mode == .mandelbrot ? Vec2(-0.5, 0) : .zero }

    /// The family; changing it reframes the viewport to that family's default view (the size is kept).
    public var mode: FractalMode {
        didSet { if mode != oldValue { viewport = Self.framing(mode, size: viewport.size) } }
    }
    /// The plane viewport (VisualCoreMath).
    public var viewport: PlaneViewport
    /// The Julia seed c; a non-finite value keeps the previous seed. Seeds outside |c| ≤ 2 are allowed.
    public var juliaSeed: Vec2 { didSet { if !juliaSeed.isFinite { juliaSeed = oldValue } } }
    /// Iterations per point, clamped to `FractalMath.capRange` (default 200).
    public var iterationCap: Int {
        didSet { iterationCap = min(max(iterationCap, FractalMath.capRange.lowerBound), FractalMath.capRange.upperBound) }
    }
    /// Escape radius R, at least 2 (non-finite values become 2).
    public var escapeRadius: Double {
        didSet { escapeRadius = escapeRadius.isFinite ? max(escapeRadius, FractalMath.minimumRadius) : FractalMath.minimumRadius }
    }

    /// The default state for a view of `size` points: Mandelbrot, default framing, default seed, cap 200, R = 2.
    public init(mode: FractalMode = .mandelbrot, size: Vec2) {
        self.mode = mode
        viewport = Self.framing(mode, size: size)
        juliaSeed = Self.defaultSeed
        iterationCap = 200
        escapeRadius = 2
    }

    private static func framing(_ mode: FractalMode, size: Vec2) -> PlaneViewport {
        PlaneViewport.framing(width: defaultWidth(for: mode), center: defaultCenter(for: mode), size: size)
    }

    /// Magnification relative to the mode's default framing.
    public var zoom: Double {
        Self.defaultWidth(for: mode) / (viewport.unitsPerPoint * min(viewport.size.x, viewport.size.y))
    }

    /// The escape result for a plane point in the current mode.
    public func escape(at p: Vec2) -> EscapeResult {
        mode == .mandelbrot
            ? FractalMath.mandelbrot(p, cap: iterationCap, radius: escapeRadius)
            : FractalMath.julia(p, seed: juliaSeed, cap: iterationCap, radius: escapeRadius)
    }

    /// The spoken picture description, for example "Julia set for seed −0.8 + 0.156i, centered at 0 + 0i, zoom 1×".
    /// Coordinates use up to 6 significant digits; the zoom is a whole number below 10,000×, scientific above, and two
    /// significant digits below 1×.
    public var spokenDescription: String {
        let place = "centered at \(Self.complex(viewport.center)), zoom \(Self.zoomText(zoom))"
        switch mode {
        case .mandelbrot: return "Mandelbrot set, \(place)"
        case .julia: return "Julia set for seed \(Self.complex(juliaSeed)), \(place)"
        }
    }

    /// "a + bi" / "a − bi" with up to 6 significant digits and a true minus sign.
    public static func complex(_ v: Vec2) -> String {
        let re = number(v.x), im = number(abs(v.y))
        return "\(re) \(v.y < 0 ? "−" : "+") \(im)i"
    }

    private static func number(_ x: Double) -> String {
        let s = String(format: "%.6g", x == 0 ? 0 : x)   // no "-0"
        return s.replacingOccurrences(of: "-", with: "−")
    }

    /// The zoom as spoken: a whole number below 10,000×, scientific above, two significant digits below 1×.
    public static func zoomText(_ z: Double) -> String {
        if z.rounded() >= 10_000 {
            let exponent = Int(log10(z).rounded(.down))
            var mantissa = z / pow(10, Double(exponent))
            var e = exponent
            if (mantissa * 10).rounded() / 10 >= 10 { mantissa /= 10; e += 1 }   // 9.96e7 rounds to 1e8
            let m = String(format: "%.1f", mantissa).replacingOccurrences(of: ".0", with: "")
            return "\(m)e\(e)×"
        }
        if z >= 1 { return "\(Int(z.rounded()))×" }
        return String(format: "%.2g×", z)
    }
}
