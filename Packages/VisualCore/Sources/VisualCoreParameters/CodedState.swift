// CodedState — feature 210 (R02-F10) T-R02F10-004 (FR-R02F10-007, FR-R02F10-008, FR-R02F10-011; clarification Q5;
// research R6). A state that an experience codes by colour also carries a drawn shape, a fill pattern and a written
// name, so it can be read without colour. `CodedStateSet` refuses a set in which two states could be confused without
// colour. `ClueReference` is the CPU reference of the clue drawing in a unit cell −1…1 (y up): the signed distance of
// the shape (negative inside) and of the pattern's ink (negative on ink), and the antialiased coverage
// (1 − smoothstep(−aa, aa, d)) of both; `vc/clue.glsl` in VisualCoreRendering draws with the same formulas. The shape
// distances follow the well-known exact 2D distance functions (circle, box, equilateral triangle, hexagon, five-point
// star) documented by Inigo Quilez under the MIT licence; see docs/architecture/color-accessibility.md.
import Foundation

/// The drawn outline of a coded state's clue: eight shapes, learnable and drawable in code.
public enum ClueShape: Int, CaseIterable, Sendable, Codable {
    /// A disc.
    case circle = 0
    /// An axis-aligned square.
    case square = 1
    /// An equilateral triangle pointing up.
    case triangle = 2
    /// A square standing on a corner.
    case diamond = 3
    /// A regular hexagon with flat top and bottom.
    case hexagon = 4
    /// A plus sign.
    case plus = 5
    /// A ring (an annulus).
    case ring = 6
    /// A five-pointed star.
    case star = 7
}

/// The fill of a coded state's clue inside its shape: four patterns.
public enum CluePattern: Int, CaseIterable, Sendable, Codable {
    /// Filled completely.
    case solid = 0
    /// Diagonal stripes at 45°.
    case stripes = 1
    /// A grid of dots.
    case dots = 2
    /// Stripes along both diagonals.
    case crosshatch = 3
}

/// One state an experience codes by colour, with its non-colour clue (shape, pattern) and its written name.
public struct CodedState: Sendable, Equatable, Codable {
    /// Stable id, `^[a-z0-9-]{1,40}$`.
    public var id: String
    /// The state's colour, sRGB components 0…1.
    public var color: SIMD3<Double>
    /// The drawn shape.
    public var shape: ClueShape
    /// The fill pattern.
    public var pattern: CluePattern
    /// The written and spoken name, 1…40 characters after trimming white space.
    public var name: String

    /// Creates a coded state; it is checked when it joins a `CodedStateSet`.
    public init(id: String, color: SIMD3<Double>, shape: ClueShape, pattern: CluePattern, name: String) {
        self.id = id
        self.color = color
        self.shape = shape
        self.pattern = pattern
        self.name = name
    }
}

/// A checked set of coded states: no two can be confused without colour.
public struct CodedStateSet: Sendable, Equatable {
    /// The largest set: one state per (shape, pattern) pair, 8 × 4.
    public static let maxStates = ClueShape.allCases.count * CluePattern.allCases.count
    /// The longest name, in characters after trimming.
    public static let maxNameLength = 40
    /// The states, in the order given.
    public let states: [CodedState]

    /// Checks `states` and keeps them. Refuses, in this order: more than ``maxStates`` states (`tooManyStates`); per state
    /// in order, an id not matching `^[a-z0-9-]{1,40}$` (`duplicateID`), a colour component that is not finite
    /// (`nonFinite`) or outside 0…1 (`outOfRange`), a name empty after trimming or longer than ``maxNameLength``
    /// (`emptyName`); then a repeated id (`duplicateID`), a repeated trimmed name (`duplicateName`) and two states sharing
    /// shape and pattern (`sameClue`, the ids in submission order). An empty set and a set of one are accepted.
    public init(_ states: [CodedState]) throws(ColorAccessError) {
        guard states.count <= Self.maxStates else {
            throw .tooManyStates(count: states.count, limit: Self.maxStates)
        }
        for (index, state) in states.enumerated() {
            guard Self.isValidID(state.id) else { throw .duplicateID(state.id) }
            for c in 0..<3 {
                guard state.color[c].isFinite else { throw .nonFinite(index: index) }
                guard (0...1).contains(state.color[c]) else { throw .outOfRange(index: index) }
            }
            let trimmed = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= Self.maxNameLength else { throw .emptyName(index: index) }
        }
        var ids = Set<String>(), names = Set<String>()
        var clues: [Int: String] = [:]
        for state in states {
            guard ids.insert(state.id).inserted else { throw .duplicateID(state.id) }
            let trimmed = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard names.insert(trimmed).inserted else { throw .duplicateName(trimmed) }
            let key = state.shape.rawValue * CluePattern.allCases.count + state.pattern.rawValue
            if let other = clues[key] { throw .sameClue(other, state.id) }
            clues[key] = state.id
        }
        self.states = states
    }

    /// The colour pairs of the set that fall closer than `PaletteSeparation.threshold` under normal vision or a
    /// simulated deficiency. Advice only: the shapes and patterns already keep the states apart.
    public var separationIssues: [PaletteSeparationIssue] {
        PaletteSeparation.issues(states.map(\.color))
    }

    private static func isValidID(_ id: String) -> Bool {
        guard (1...40).contains(id.count) else { return false }
        return id.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" }
    }
}

/// The CPU reference of a clue drawing in a unit cell −1…1 with y up (see the file header).
public enum ClueReference {
    /// The signed distance from `p` to the edge of `shape` (negative inside), in cell units.
    public static func distance(shape: ClueShape, at p: SIMD2<Double>) -> Double {
        switch shape {
        case .circle: return length(p) - 0.8
        case .square: return box(p, SIMD2(0.7, 0.7))
        case .triangle: return triangle(p, r: 0.85)
        case .diamond: return (abs(p.x) + abs(p.y) - 0.9) / 2.0.squareRoot()
        case .hexagon: return hexagon(p, r: 0.75)
        case .plus: return min(box(p, SIMD2(0.8, 0.25)), box(p, SIMD2(0.25, 0.8)))
        case .ring: return abs(length(p) - 0.6) - 0.2
        case .star: return star5(p, r: 0.9, rf: 0.45)
        }
    }

    /// The signed distance from `p` to the edge of `pattern`'s ink (negative on ink), in cell units; `solid` is −1
    /// everywhere.
    public static func pattern(_ pattern: CluePattern, at p: SIMD2<Double>) -> Double {
        let frequency = 3.0
        let u = (p.x + p.y) / 2.0.squareRoot() * frequency, v = (p.x - p.y) / 2.0.squareRoot() * frequency
        switch pattern {
        case .solid: return -1
        case .stripes: return stripe(u) / frequency
        case .dots:
            let q = SIMD2(fract(p.x * frequency) - 0.5, fract(p.y * frequency) - 0.5)
            return (length(q) - 0.3) / frequency
        case .crosshatch: return min(stripe(u), stripe(v)) / frequency
        }
    }

    /// The antialiased coverage of the clue at `p`: (1 − smoothstep(−aa, aa, shape distance)) × (1 − smoothstep(−aa,
    /// aa, pattern distance)), 0…1; `antialias` is the half width of the soft edge in cell units.
    public static func coverage(shape: ClueShape, pattern: CluePattern, at p: SIMD2<Double>, antialias: Double) -> Double {
        let inside = 1 - smoothstep(-antialias, antialias, distance(shape: shape, at: p))
        let ink = 1 - smoothstep(-antialias, antialias, self.pattern(pattern, at: p))
        return inside * ink
    }

    /// The antialiased coverage of the outline band of `shape` at `p`: a band of `width` cell units centred on the edge.
    public static func outline(shape: ClueShape, at p: SIMD2<Double>, width: Double, antialias: Double) -> Double {
        1 - smoothstep(-antialias, antialias, abs(distance(shape: shape, at: p)) - width / 2)
    }

    /// GLSL `smoothstep`: 0 below `e0`, 1 above `e1`, Hermite in between.
    public static func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(max((x - e0) / (e1 - e0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    // MARK: Primitives (GLSL semantics)

    private static func length(_ p: SIMD2<Double>) -> Double { (p.x * p.x + p.y * p.y).squareRoot() }
    private static func dot(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.x + a.y * b.y }
    private static func fract(_ x: Double) -> Double { x - x.rounded(.down) }
    private static func sign(_ x: Double) -> Double { x > 0 ? 1 : (x < 0 ? -1 : 0) }
    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(max(x, lo), hi) }

    /// Distance to the ink of stripes of period 1 and half the period wide, in stripe units.
    private static func stripe(_ u: Double) -> Double { abs(fract(u) - 0.5) - 0.25 }

    private static func box(_ p: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let q = SIMD2(abs(p.x) - b.x, abs(p.y) - b.y)
        return length(SIMD2(max(q.x, 0), max(q.y, 0))) + min(max(q.x, q.y), 0)
    }

    private static func triangle(_ p0: SIMD2<Double>, r: Double) -> Double {
        let k = 3.0.squareRoot()
        var p = SIMD2(abs(p0.x) - r, p0.y + r / k)
        if p.x + k * p.y > 0 { p = SIMD2(p.x - k * p.y, -k * p.x - p.y) / 2 }
        p.x -= clamp(p.x, -2 * r, 0)
        return -length(p) * sign(p.y)
    }

    private static func hexagon(_ p0: SIMD2<Double>, r: Double) -> Double {
        let k = SIMD3(-0.866025404, 0.5, 0.577350269)
        var p = SIMD2(abs(p0.x), abs(p0.y))
        let kxy = SIMD2(k.x, k.y)
        p -= 2 * min(dot(kxy, p), 0) * kxy
        p -= SIMD2(clamp(p.x, -k.z * r, k.z * r), r)
        return length(p) * sign(p.y)
    }

    private static func star5(_ p0: SIMD2<Double>, r: Double, rf: Double) -> Double {
        let k1 = SIMD2(0.809016994375, -0.587785252292), k2 = SIMD2(-k1.x, k1.y)
        var p = SIMD2(abs(p0.x), p0.y)
        p -= 2 * max(dot(k1, p), 0) * k1
        p -= 2 * max(dot(k2, p), 0) * k2
        p.x = abs(p.x)
        p.y -= r
        let ba = rf * SIMD2(-k1.y, k1.x) - SIMD2(0, 1)
        let h = clamp(dot(p, ba) / dot(ba, ba), 0, r)
        return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y)
    }
}
