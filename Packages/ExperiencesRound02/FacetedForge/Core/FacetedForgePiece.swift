// FacetedForgePiece — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-002, 003, 013, 014; clarifications Q1 … Q3;
// research R1 … R4). The exact geometry of Faceted Forge: the 13 named plane directions (components in {−1, 0, 1}), the
// half-spaces sign·(n·p) ≤ sign·depth with integer depths −24 … 24, and a convex piece given by its bounding
// half-spaces. A piece's corners are the points where three of its planes meet and every other plane holds; a face is a
// plane with at least three corners, its corners ordered anticlockwise seen from outside; the volume is the sum of
// signed tetrahedra from the first corner over a fan of each face. A corner solves three planes whose normals have
// components in {−1, 0, 1}, so its denominator divides 12 (the determinant is at most 4 in size); every predicate below
// runs on the corners scaled to integers by the least common multiple of their denominators, so nothing is
// approximated. A piece keeps only the half-spaces that are faces (redundant planes are dropped), which makes equal
// solids equal values. A cut splits a piece into the "below" (sign +1) and "above" (sign −1) halves and is refused
// (`.miss`) unless a corner lies strictly on each side of the plane.
import Foundation

/// One of the 13 plane directions.
public struct FacetedForgeDirection: Sendable, Hashable, Codable {
    /// The index, 0 … 12.
    public let index: Int
    /// The x component, −1 … 1.
    public let x: Int
    /// The y component, −1 … 1.
    public let y: Int
    /// The z component, −1 … 1.
    public let z: Int

    /// The 13 directions: the axes, the six face diagonals and the four body diagonals (clarification Q1).
    public static let all: [FacetedForgeDirection] = [
        (1, 0, 0), (0, 1, 0), (0, 0, 1),
        (1, 1, 0), (1, -1, 0), (1, 0, 1), (1, 0, -1), (0, 1, 1), (0, 1, -1),
        (1, 1, 1), (1, 1, -1), (1, -1, 1), (-1, 1, 1),
    ].enumerated().map { FacetedForgeDirection(index: $0.offset, x: $0.element.0, y: $0.element.1, z: $0.element.2) }

    /// The direction's name in words: "x", "x+y", "x−y+z", "−x+y+z" ….
    public var name: String {
        var text: String = ""
        for (component, letter) in [(x, "x"), (y, "y"), (z, "z")] where component != 0 {
            if component < 0 { text += "−" } else if !text.isEmpty { text += "+" }
            text += letter
        }
        return text
    }
}

/// The half-space sign·(n·p) ≤ sign·depth of a direction n.
public struct FacetedForgeHalfSpace: Sendable, Hashable, Codable, Comparable {
    /// The direction's index, 0 … 12.
    public let direction: Int
    /// +1 (the side below the plane) or −1 (the side above it).
    public let sign: Int
    /// The plane's depth d in n·p = d, −24 … 24.
    public let depth: Int

    /// The allowed depths.
    public static let depths: ClosedRange<Int> = -24...24

    /// A half-space (the piece or level checks the ranges).
    public init(direction: Int, sign: Int, depth: Int) {
        self.direction = direction
        self.sign = sign
        self.depth = depth
    }

    /// Whether the direction, the sign and the depth are in range.
    public var isValid: Bool {
        FacetedForgeDirection.all.indices.contains(direction) && (sign == 1 || sign == -1)
            && Self.depths.contains(depth)
    }

    /// The outward normal (sign·n) as integers.
    var normal: (Int64, Int64, Int64) {
        let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
        return (Int64(sign * d.x), Int64(sign * d.y), Int64(sign * d.z))
    }

    /// The bound sign·depth.
    var bound: Int64 { Int64(sign * depth) }

    /// Ordered by direction, then sign, then depth.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.direction, lhs.sign, lhs.depth) < (rhs.direction, rhs.sign, rhs.depth)
    }
}

/// An exact point.
public struct FacetedForgePoint: Sendable, Hashable, Codable, Comparable {
    /// The x coordinate.
    public let x: FacetedForgeFraction
    /// The y coordinate.
    public let y: FacetedForgeFraction
    /// The z coordinate.
    public let z: FacetedForgeFraction

    /// A point of exact coordinates.
    public init(x: FacetedForgeFraction, y: FacetedForgeFraction, z: FacetedForgeFraction) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Ordered by x, then y, then z.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.x != rhs.x { return lhs.x < rhs.x }
        if lhs.y != rhs.y { return lhs.y < rhs.y }
        return lhs.z < rhs.z
    }
}

/// A face of a piece: its plane and its corners, ordered anticlockwise seen from outside.
public struct FacetedForgeFace: Sendable, Hashable {
    /// The bounding half-space whose plane holds the face.
    public let plane: FacetedForgeHalfSpace
    /// The corners, anticlockwise around the outward normal, starting at the smallest.
    public let corners: [FacetedForgePoint]
}

/// A convex piece of the crystal, given by its bounding half-spaces (only those that are faces).
public struct FacetedForgePiece: Sendable, Hashable {
    /// The bounding half-spaces, sorted; each one is a face.
    public let halfSpaces: [FacetedForgeHalfSpace]
    /// The corners, sorted.
    public let corners: [FacetedForgePoint]
    /// The faces, in the order of ``halfSpaces``.
    public let faces: [FacetedForgeFace]
    /// The exact volume.
    public let volume: FacetedForgeFraction

    /// The number of faces.
    public var faceCount: Int { faces.count }

    /// A piece bounded by `halfSpaces` (sorted and deduplicated here; planes that are not faces are dropped).
    ///
    /// - Throws: `.level("plane")` for a half-space out of range; `.level("empty")` when the half-spaces bound no solid
    ///   with an interior (or an unbounded one); `.action("overflow")` if an exact value overflows.
    public init(halfSpaces: [FacetedForgeHalfSpace]) throws(FacetedForgeError) {
        let planes: [FacetedForgeHalfSpace] = Array(Set(halfSpaces)).sorted()
        guard planes.allSatisfy(\.isValid) else { throw .level("plane") }
        guard planes.count >= 4 else { throw .level("empty") }
        let raw: [RawPoint] = Self.corners(planes)
        guard raw.count >= 4 else { throw .level("empty") }
        let scale: Int64 = raw.reduce(1) { Self.lcm($0, $1.w) }
        let scaled: [Scaled] = raw.map { p in
            Scaled(x: p.x * (scale / p.w), y: p.y * (scale / p.w), z: p.z * (scale / p.w))
        }
        var kept: [FacetedForgeHalfSpace] = []
        var faceIndices: [[Int]] = []
        for plane in planes {
            let (a, b, c) = plane.normal
            let k: Int64 = plane.bound * scale
            let on: [Int] = scaled.indices.filter { a * scaled[$0].x + b * scaled[$0].y + c * scaled[$0].z == k }
            guard on.count >= 3 else { continue }
            kept.append(plane)
            faceIndices.append(Self.ordered(on, scaled: scaled, normal: (a, b, c)))
        }
        guard kept.count >= 4 else { throw .level("empty") }
        let apex: Scaled = scaled[0]
        var six: Int64 = 0
        for ring in faceIndices {
            for i in 1..<(ring.count - 1) {
                six += Self.triple(scaled[ring[0]] - apex, scaled[ring[i]] - apex, scaled[ring[i + 1]] - apex)
            }
        }
        guard six > 0 else { throw .level("empty") }
        let points: [FacetedForgePoint] = try raw.map { (p: RawPoint) throws(FacetedForgeError) -> FacetedForgePoint in
            try FacetedForgePoint(x: FacetedForgeFraction(p.x, p.w), y: FacetedForgeFraction(p.y, p.w),
                                  z: FacetedForgeFraction(p.z, p.w))
        }
        self.halfSpaces = kept
        self.corners = points.sorted()
        self.faces = zip(kept, faceIndices).map { plane, ring in
            FacetedForgeFace(plane: plane, corners: Self.rotatedToSmallest(ring.map { points[$0] }))
        }
        let cube: Int64 = try FacetedForgeFraction.mul(try FacetedForgeFraction.mul(scale, scale), scale)
        self.volume = try FacetedForgeFraction(six, try FacetedForgeFraction.mul(6, cube))
    }

    /// The edges: each as its two corners (sorted), every edge once, sorted.
    public var edges: [[FacetedForgePoint]] {
        var set: Set<[FacetedForgePoint]> = []
        for face in faces {
            for i in face.corners.indices {
                let a: FacetedForgePoint = face.corners[i]
                let b: FacetedForgePoint = face.corners[(i + 1) % face.corners.count]
                set.insert(a < b ? [a, b] : [b, a])
            }
        }
        return set.sorted { $0[0] != $1[0] ? $0[0] < $1[0] : $0[1] < $1[1] }
    }

    /// How many faces use each edge (FR-R02G0801-014: exactly two for a closed solid).
    public var edgeIncidence: [Int] {
        var count: [[FacetedForgePoint]: Int] = [:]
        for face in faces {
            for i in face.corners.indices {
                let a: FacetedForgePoint = face.corners[i]
                let b: FacetedForgePoint = face.corners[(i + 1) % face.corners.count]
                count[a < b ? [a, b] : [b, a], default: 0] += 1
            }
        }
        return edges.map { count[$0] ?? 0 }
    }

    /// The signed side of every corner relative to the plane n·p = depth of `direction`: negative below, zero on,
    /// positive above (scaled integers, exact).
    func sides(direction: Int, depth: Int) -> [Int64] {
        let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
        let scale: Int64 = corners.reduce(1) { s, p in
            Self.lcm(Self.lcm(s, p.x.denominator), Self.lcm(p.y.denominator, p.z.denominator))
        }
        return corners.map { p in
            Int64(d.x) * (p.x.numerator * (scale / p.x.denominator))
                + Int64(d.y) * (p.y.numerator * (scale / p.y.denominator))
                + Int64(d.z) * (p.z.numerator * (scale / p.z.denominator)) - Int64(depth) * scale
        }
    }

    /// Whether the plane of `direction` at `depth` passes through the piece's interior (a corner strictly on each
    /// side).
    public func isCrossed(direction: Int, depth: Int) -> Bool {
        guard FacetedForgeDirection.all.indices.contains(direction), FacetedForgeHalfSpace.depths.contains(depth) else {
            return false
        }
        let s: [Int64] = sides(direction: direction, depth: depth)
        return s.contains { $0 < 0 } && s.contains { $0 > 0 }
    }

    /// The two halves of the piece cut by the plane n·p = `depth` of `direction`: below (n·p ≤ depth) and above.
    ///
    /// - Throws: `.action("range")` for a direction or depth out of range; `.miss` when the plane does not pass through
    ///   the piece's interior; `.action("overflow")` if an exact value overflows.
    public func cut(direction: Int, depth: Int) throws(FacetedForgeError) -> (below: Self, above: Self) {
        guard FacetedForgeDirection.all.indices.contains(direction), FacetedForgeHalfSpace.depths.contains(depth) else {
            throw .action("range")
        }
        guard isCrossed(direction: direction, depth: depth) else { throw .miss }
        let below: Self
        let above: Self
        do {
            let lower = FacetedForgeHalfSpace(direction: direction, sign: 1, depth: depth)
            let upper = FacetedForgeHalfSpace(direction: direction, sign: -1, depth: depth)
            below = try Self(halfSpaces: halfSpaces + [lower])
            above = try Self(halfSpaces: halfSpaces + [upper])
        } catch .level {
            throw .miss
        }
        return (below, above)
    }

    /// Whether `lhs` comes before `rhs` in the canonical order of pieces (clarification Q2): volume descending, then
    /// face count descending, then the sorted corner lists in lexicographic order.
    public static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.volume != rhs.volume { return rhs.volume < lhs.volume }
        if lhs.faceCount != rhs.faceCount { return lhs.faceCount > rhs.faceCount }
        return lhs.corners.lexicographicallyPrecedes(rhs.corners)
    }

    /// `pieces` in the canonical order.
    public static func canonical(_ pieces: [Self]) -> [Self] { pieces.sorted(by: precedes) }

    // MARK: Exact integer geometry

    /// A corner as integer numerators over a positive common denominator w.
    struct RawPoint: Hashable {
        let x: Int64
        let y: Int64
        let z: Int64
        let w: Int64
    }

    /// A corner scaled to integers.
    struct Scaled {
        let x: Int64
        let y: Int64
        let z: Int64

        static func - (a: Scaled, b: Scaled) -> Scaled { Scaled(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    }

    /// The least common multiple of two positive integers.
    static func lcm(_ a: Int64, _ b: Int64) -> Int64 { a / FacetedForgeFraction.gcd(a, b) * b }

    /// The 3 × 3 determinant of three rows.
    static func det(_ r0: (Int64, Int64, Int64), _ r1: (Int64, Int64, Int64), _ r2: (Int64, Int64, Int64)) -> Int64 {
        r0.0 * (r1.1 * r2.2 - r1.2 * r2.1) - r0.1 * (r1.0 * r2.2 - r1.2 * r2.0) + r0.2 * (r1.0 * r2.1 - r1.1 * r2.0)
    }

    /// The triple product a · (b × c).
    static func triple(_ a: Scaled, _ b: Scaled, _ c: Scaled) -> Int64 {
        det((a.x, a.y, a.z), (b.x, b.y, b.z), (c.x, c.y, c.z))
    }

    /// Every distinct point where three planes meet and every plane holds (reduced numerators over a positive w).
    static func corners(_ planes: [FacetedForgeHalfSpace]) -> [RawPoint] {
        var found: Set<RawPoint> = []
        let n: [(Int64, Int64, Int64)] = planes.map(\.normal)
        let k: [Int64] = planes.map(\.bound)
        let count: Int = planes.count
        for i in 0..<count {
            for j in (i + 1)..<max(i + 1, count) {
                for l in (j + 1)..<max(j + 1, count) {
                    let d: Int64 = det(n[i], n[j], n[l])
                    guard d != 0 else { continue }
                    var px: Int64 = det((k[i], n[i].1, n[i].2), (k[j], n[j].1, n[j].2), (k[l], n[l].1, n[l].2))
                    var py: Int64 = det((n[i].0, k[i], n[i].2), (n[j].0, k[j], n[j].2), (n[l].0, k[l], n[l].2))
                    var pz: Int64 = det((n[i].0, n[i].1, k[i]), (n[j].0, n[j].1, k[j]), (n[l].0, n[l].1, k[l]))
                    var w: Int64 = d
                    if w < 0 { (px, py, pz, w) = (-px, -py, -pz, -w) }
                    var inside: Bool = true
                    for m in 0..<count where n[m].0 * px + n[m].1 * py + n[m].2 * pz > k[m] * w {
                        inside = false
                        break
                    }
                    guard inside else { continue }
                    let g: Int64 = FacetedForgeFraction.gcd(FacetedForgeFraction.gcd(abs(px), abs(py)),
                                                            FacetedForgeFraction.gcd(abs(pz), w))
                    found.insert(RawPoint(x: px / g, y: py / g, z: pz / g, w: w / g))
                }
            }
        }
        return found.sorted { ($0.x * $1.w, $0.y * $1.w, $0.z * $1.w) < ($1.x * $0.w, $1.y * $0.w, $1.z * $0.w) }
    }

    /// The indices `on` ordered anticlockwise around the outward `normal` (exact angular sort about the centroid).
    static func ordered(_ on: [Int], scaled: [Scaled], normal: (Int64, Int64, Int64)) -> [Int] {
        let m: Int64 = Int64(on.count)
        let sum: Scaled = on.reduce(Scaled(x: 0, y: 0, z: 0)) { Scaled(x: $0.x + scaled[$1].x, y: $0.y + scaled[$1].y,
                                                                    z: $0.z + scaled[$1].z) }
        func rel(_ i: Int) -> Scaled {
            Scaled(x: scaled[i].x * m - sum.x, y: scaled[i].y * m - sum.y, z: scaled[i].z * m - sum.z)
        }
        let nrm: Scaled = Scaled(x: normal.0, y: normal.1, z: normal.2)
        let r: Scaled = rel(on[0])
        func crossDot(_ a: Scaled, _ b: Scaled) -> Int64 { triple(nrm, a, b) }  // n · (a × b)
        func dot(_ a: Scaled, _ b: Scaled) -> Int64 { a.x * b.x + a.y * b.y + a.z * b.z }
        func half(_ v: Scaled) -> Int {
            let s: Int64 = crossDot(r, v)
            return s > 0 || (s == 0 && dot(r, v) > 0) ? 0 : 1
        }
        return on.sorted { i, j in
            let a: Scaled = rel(i)
            let b: Scaled = rel(j)
            let ha: Int = half(a)
            let hb: Int = half(b)
            if ha != hb { return ha < hb }
            return crossDot(a, b) > 0
        }
    }

    /// `ring` rotated so it starts at its smallest corner (the orientation is kept).
    static func rotatedToSmallest(_ ring: [FacetedForgePoint]) -> [FacetedForgePoint] {
        guard let start = ring.indices.min(by: { ring[$0] < ring[$1] }) else { return ring }
        return Array(ring[start...] + ring[..<start])
    }
}

extension FacetedForgePiece: Codable {
    /// Decodes a piece from its half-spaces, recomputing everything.
    public init(from decoder: any Decoder) throws {
        let planes: [FacetedForgeHalfSpace] = try decoder.singleValueContainer().decode([FacetedForgeHalfSpace].self)
        do {
            self = try FacetedForgePiece(halfSpaces: planes)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// Encodes the half-spaces.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(halfSpaces)
    }
}

/// A player action: cut piece `piece` (its index in the canonical order) with the plane of `direction` at `depth`.
public enum FacetedForgeAction: Sendable, Hashable, Codable {
    /// Cut (piece, direction, depth).
    case cut(Int, Int, Int)
}
