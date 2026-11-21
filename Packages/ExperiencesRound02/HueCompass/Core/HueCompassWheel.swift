// HueCompassWheel — feature 331 (R02-G04-01) T-R02G0401-002 (FR-R02G0401-002, 003, 011; clarifications Q1, Q2). The
// exact compass wheel: 96 bearings counter-clockwise from +x and 24 hue bands of 4 bearings. The source's rule
// hue = (atan2(y, x) + offset) / 2π is decided in integers: bearing k's sector lies between the constant boundary vectors
// k and k + 1 (angle 2πk/96 scaled by 65 536 and rounded once, stored below), and a non-zero direction p is in sector k
// exactly when cross(boundary k, p) ≥ 0 and cross(boundary k + 1, p) < 0, so every direction is in exactly one sector.
// The band of bearing b is (⌊b/4⌋ + offset) mod 24. A clue at bearing β for target τ is the hue gap (circular band
// distance, 0 … 12; never reads fog) and the fog depth (the sum of the densities of the bearings strictly inside the
// shorter arc from β to τ, counter-clockwise from β when both arcs are 48 long; never reads hue or offset).

/// The exact compass wheel of Hue Compass.
public enum HueCompassWheel {
    /// The number of bearings.
    public static let bearings: Int = 96
    /// The number of hue bands.
    public static let bands: Int = 24
    /// The number of bearings in one band.
    public static let bearingsPerBand: Int = 4

    /// The 96 boundary vectors: boundary k is (cos, sin)(2πk/96) × 65 536, rounded once; constants, never recomputed.
    public static let boundaries: [(x: Int, y: Int)] = [
        (65536, 0), (65396, 4286), (64975, 8554), (64277, 12785),
        (63303, 16962), (62058, 21066), (60547, 25080), (58777, 28986),
        (56756, 32768), (54491, 36410), (51993, 39896), (49273, 43211),
        (46341, 46341), (43211, 49273), (39896, 51993), (36410, 54491),
        (32768, 56756), (28986, 58777), (25080, 60547), (21066, 62058),
        (16962, 63303), (12785, 64277), (8554, 64975), (4286, 65396),
        (0, 65536), (-4286, 65396), (-8554, 64975), (-12785, 64277),
        (-16962, 63303), (-21066, 62058), (-25080, 60547), (-28986, 58777),
        (-32768, 56756), (-36410, 54491), (-39896, 51993), (-43211, 49273),
        (-46341, 46341), (-49273, 43211), (-51993, 39896), (-54491, 36410),
        (-56756, 32768), (-58777, 28986), (-60547, 25080), (-62058, 21066),
        (-63303, 16962), (-64277, 12785), (-64975, 8554), (-65396, 4286),
        (-65536, 0), (-65396, -4286), (-64975, -8554), (-64277, -12785),
        (-63303, -16962), (-62058, -21066), (-60547, -25080), (-58777, -28986),
        (-56756, -32768), (-54491, -36410), (-51993, -39896), (-49273, -43211),
        (-46341, -46341), (-43211, -49273), (-39896, -51993), (-36410, -54491),
        (-32768, -56756), (-28986, -58777), (-25080, -60547), (-21066, -62058),
        (-16962, -63303), (-12785, -64277), (-8554, -64975), (-4286, -65396),
        (0, -65536), (4286, -65396), (8554, -64975), (12785, -64277),
        (16962, -63303), (21066, -62058), (25080, -60547), (28986, -58777),
        (32768, -56756), (36410, -54491), (39896, -51993), (43211, -49273),
        (46341, -46341), (49273, -43211), (51993, -39896), (54491, -36410),
        (56756, -32768), (58777, -28986), (60547, -25080), (62058, -21066),
        (63303, -16962), (64277, -12785), (64975, -8554), (65396, -4286),
    ]

    /// The bearing (sector) of the direction (x, y), or nil for (0, 0). Exact for |x|, |y| ≤ 2^40.
    public static func bearing(x: Int, y: Int) -> Int? {
        guard x != 0 || y != 0 else { return nil }
        for k in 0..<bearings {
            let a: (x: Int, y: Int) = boundaries[k]
            let b: (x: Int, y: Int) = boundaries[(k + 1) % bearings]
            if a.x * y - a.y * x >= 0 && b.x * y - b.y * x < 0 { return k }
        }
        preconditionFailure("the boundary table covers every direction")
    }

    /// The hue band of `bearing` under `offset`: (⌊bearing/4⌋ + offset) mod 24.
    public static func band(of bearing: Int, offset: Int) -> Int {
        (mod(bearing, bearings) / bearingsPerBand + offset) % bands
    }

    /// The circular distance between two bearings, 0 … 48.
    public static func bearingDistance(_ a: Int, _ b: Int) -> Int {
        let d: Int = mod(a - b, bearings)
        return min(d, bearings - d)
    }

    /// The circular distance between two bands, 0 … 12.
    public static func bandDistance(_ a: Int, _ b: Int) -> Int {
        let d: Int = mod(a - b, bands)
        return min(d, bands - d)
    }

    /// The bearings strictly inside the shorter arc from `from` to `to`, in order from `from`; counter-clockwise when
    /// both arcs are equally long; empty when the bearings are equal or adjacent.
    public static func arc(from: Int, to: Int) -> [Int] {
        let d: Int = mod(to - from, bearings)
        guard d > 1 && d < bearings - 1 else { return [] }
        if d <= bearings / 2 { return (1..<d).map { mod(from + $0, bearings) } }
        return (1..<(bearings - d)).map { mod(from - $0, bearings) }
    }

    /// The non-negative remainder of `value` divided by `modulus`.
    static func mod(_ value: Int, _ modulus: Int) -> Int {
        let r: Int = value % modulus
        return r < 0 ? r + modulus : r
    }
}

/// The clue a probe returns at one bearing.
public struct HueCompassClue: Sendable, Hashable, Codable {
    /// The probed bearing, 0 … 95.
    public let bearing: Int
    /// The circular band distance between the probed bearing's band and the target's, 0 … 12.
    public let hueGap: Int
    /// The fog depth between the probed bearing and the target, 0 … 423.
    public let depth: Int

    /// A clue of the given values (not checked).
    public init(bearing: Int, hueGap: Int, depth: Int) {
        self.bearing = bearing
        self.hueGap = hueGap
        self.depth = depth
    }
}

/// One player action.
public enum HueCompassAction: Sendable, Hashable, Codable {
    /// Turn the compass by the given non-zero number of bearings, −48 … 48 (positive is counter-clockwise); spends
    /// nothing.
    case turn(Int)
    /// Sample the clue at the current bearing; spends one unit.
    case probe
    /// Select a bearing (0 … 95) and a hue band (0 … 23); spends one unit and wins or fails.
    case select(bearing: Int, band: Int)
}
