// StoneShape — feature 147 (A20-P03) T-A20-302 (FR-A20-301, FR-A20-302, FR-A20-303; clarification Q1; data-model.md
// "StoneShape"; gap G-STONES). The procedural outline and height of one stone, shared by drawing (`StoneLayer`) and
// selection (`StoneSelection`), so what is seen is what is picked:
//
//   - Outline: a superellipse |x/rx|^n + |y/ry|^n = 1 in the stone's own frame, with the exponent n of its kind
//     (river-pebble 2.0, flat-slate 2.6, round-granite 2.0, tall-basalt 3.0, moss-boulder 2.2) and the radii of its
//     kind times its scale (tray widths). The frame is turned by the stone's rotation: a positive rotation turns the
//     stone's x axis towards the tray's +y (down), clockwise on the screen.
//   - Wobble: the outline's radius is multiplied by 1 + 0.03 sin(3φ + a) + 0.02 sin(5φ + b) + 0.01 sin(7φ + c), φ
//     the angle in the stone's normalized frame and a, b, c fixed phases from a SplitMix64 hash of the stone's id: at
//     most ±6 %, the same for the same id on every run.
//   - Height: a dome, (1 − d²)^½ times the kind's height (0.6, 0.35, 0.7, 1.0, 0.8), d the normalized radial distance
//     (1 on the outline); 0 outside.
//
// Distances are in tray widths: a normalized tray point (x, y) is (x, y × yScale) there. Pure arithmetic: no GPU,
// UIKit, clock or randomness.
import Foundation
import VisualCoreMath

/// The procedural shape of one stone (see the file header).
public struct StoneShape: Equatable, Sendable {
    /// The superellipse exponents, by index of `GardenPalette.stones`.
    public static let exponents: [Double] = [2.0, 2.6, 2.0, 3.0, 2.2]
    /// The dome heights, by index of `GardenPalette.stones` (the tallest, tall basalt, is 1).
    public static let heights: [Double] = [0.6, 0.35, 0.7, 1.0, 0.8]
    /// The largest share by which the wobble moves the outline in or out (6 %).
    public static let maxWobble = 0.06
    /// The wobble's amplitudes and frequencies: their amplitudes add up to ``maxWobble``.
    static let wobbleTerms: [(amplitude: Double, frequency: Double)] = [(0.03, 3), (0.02, 5), (0.01, 7)]

    /// The stone's id (it seeds the wobble).
    public let id: UInt32
    /// The index of the stone's kind in `GardenPalette.stones`.
    public let kindIndex: Int
    /// The centre in normalized tray coordinates.
    public let centre: Vec2
    /// The radius along the stone's own x axis, in tray widths (the kind's radius times the scale).
    public let radiusX: Double
    /// The radius along the stone's own y axis, in tray widths (the kind's radius times the scale).
    public let radiusY: Double
    /// The rotation in radians (positive turns the x axis towards the tray's +y).
    public let rotation: Double
    /// The superellipse exponent of the kind.
    public let exponent: Double
    /// The dome's height at the centre (the kind's height).
    public let peak: Double
    /// The wobble phases seeded by the id.
    let phases: [Double]

    /// The shape of `stone`; nil when its kind is not in `GardenPalette.stones`.
    public init?(stone: Stone) {
        guard let index = GardenPalette.stones.firstIndex(where: { $0.id == stone.kind }) else { return nil }
        let kind = GardenPalette.stones[index]
        self.id = stone.id
        kindIndex = index
        centre = stone.position
        radiusX = kind.radiusX * stone.scale
        radiusY = kind.radiusY * stone.scale
        rotation = stone.rotation
        exponent = Self.exponents[index]
        peak = Self.heights[index]
        phases = Self.phases(seed: stone.id)
    }

    /// Three phases in 0 ..< 2π from a SplitMix64 hash of `seed`.
    static func phases(seed: UInt32) -> [Double] {
        var state = UInt64(seed) &* 0x9E37_79B9_7F4A_7C15 &+ 0x2545_F491_4F6C_DD1D
        var out: [Double] = []
        for _ in 0..<wobbleTerms.count {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            out.append(Double(z >> 11) / Double(UInt64(1) << 53) * 2 * Double.pi)
        }
        return out
    }

    /// The wobble factor at the angle `angle` of the stone's normalized frame: 1 plus at most ±``maxWobble``.
    public func wobble(at angle: Double) -> Double {
        var factor = 1.0
        for index in Self.wobbleTerms.indices {
            let term = Self.wobbleTerms[index]
            factor += term.amplitude * sin(term.frequency * angle + phases[index])
        }
        return factor
    }

    /// The point `point` (normalized tray coordinates) in the stone's own frame divided by its radii: (x/rx, y/ry).
    func normalizedLocal(_ point: Vec2) -> Vec2 {
        let yScale = GardenPalette.smallTray.yScale
        let dx = point.x - centre.x
        let dy = (point.y - centre.y) * yScale
        let c = cos(rotation)
        let s = sin(rotation)
        let lx = dx * c + dy * s
        let ly = -dx * s + dy * c
        return Vec2(lx / max(radiusX, 1e-12), ly / max(radiusY, 1e-12))
    }

    /// The normalized radial distance of `point` (normalized tray coordinates): 0 at the centre, 1 on the wobbled
    /// outline, above 1 outside; infinity for a point that is not finite.
    public func radialDistance(_ point: Vec2) -> Double {
        guard point.isFinite else { return .infinity }
        let local = normalizedLocal(point)
        let n = exponent
        let r = pow(pow(abs(local.x), n) + pow(abs(local.y), n), 1 / n)
        guard r > 0 else { return 0 }
        return r / wobble(at: atan2(local.y, local.x))
    }

    /// Whether `point` (normalized tray coordinates) lies on or inside the outline.
    public func contains(_ point: Vec2) -> Bool {
        radialDistance(point) <= 1
    }

    /// The dome's height at `point` (normalized tray coordinates): (1 − d²)^½ × ``peak`` inside, 0 outside.
    public func height(at point: Vec2) -> Double {
        let d = radialDistance(point)
        guard d <= 1 else { return 0 }
        return (1 - d * d).squareRoot() * peak
    }

    /// The axis-aligned box that holds the whole outline in normalized tray coordinates: the rotated radii box widened
    /// by ``maxWobble``.
    public var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let c = abs(cos(rotation))
        let s = abs(sin(rotation))
        let grow = 1 + Self.maxWobble
        let extentX = (c * radiusX + s * radiusY) * grow
        let extentY = (s * radiusX + c * radiusY) * grow / GardenPalette.smallTray.yScale
        return (centre.x - extentX, centre.y - extentY, centre.x + extentX, centre.y + extentY)
    }

    /// `samples` points (at least 3) of the outline in normalized tray coordinates, in order around the stone.
    public func outline(samples: Int = 48) -> [Vec2] {
        let count = max(samples, 3)
        let yScale = GardenPalette.smallTray.yScale
        let c = cos(rotation)
        let s = sin(rotation)
        var points: [Vec2] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let t = 2 * Double.pi * Double(index) / Double(count)
            let ct = cos(t)
            let st = sin(t)
            // The superellipse's point at the parameter t (r = 1 before the wobble), in the normalized frame.
            var ux = (ct < 0 ? -1.0 : 1.0) * pow(abs(ct), 2 / exponent)
            var uy = (st < 0 ? -1.0 : 1.0) * pow(abs(st), 2 / exponent)
            let factor = wobble(at: atan2(uy, ux))
            ux *= factor
            uy *= factor
            let lx = ux * radiusX
            let ly = uy * radiusY
            let dx = lx * c - ly * s
            let dy = lx * s + ly * c
            points.append(Vec2(centre.x + dx, centre.y + dy / yScale))
        }
        return points
    }
}
