// VoxelOrigamiLattice — feature 441 (R02-G15-01) T-R02G1501-002 (FR-R02G1501-002, 003, 004, 014; SC-R02G1501-003, 004;
// clarifications Q1 … Q4). The exact cube lattice of Voxel Origami: integer vectors, the 24 rotations of the cube
// (integer matrices with entries −1, 0, 1), poses computed from the root (x(i) = x(p) + O(p) · d(i),
// O(i) = O(p) · R(d(i), q(i)), right-hand rule), the cubes a hinge turn swings (cube i's descendants off its axis), the
// turn check (end-pose `collision` first, then the swept band `sweep`, every comparison in integer squares), and the
// canonical form, canonical hash and covered count of a cell set under an allowed rotation group. Nothing here uses
// floating point or a random source.
import Foundation
import VisualCoreMath

/// An integer lattice vector: a cube's cell or a unit direction.
public struct VoxelOrigamiVector: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public let x: Int
    public let y: Int
    public let z: Int

    /// A vector of the given coordinates.
    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// The origin.
    public static let zero = VoxelOrigamiVector(0, 0, 0)

    /// The six unit directions, in this order: +x, −x, +y, −y, +z, −z.
    public static let units: [VoxelOrigamiVector] = [
        VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(-1, 0, 0), VoxelOrigamiVector(0, 1, 0),
        VoxelOrigamiVector(0, -1, 0), VoxelOrigamiVector(0, 0, 1), VoxelOrigamiVector(0, 0, -1),
    ]

    /// Whether this is one of the six unit directions.
    public var isUnit: Bool { Self.units.contains(self) }

    /// The sum.
    public static func + (a: VoxelOrigamiVector, b: VoxelOrigamiVector) -> VoxelOrigamiVector {
        VoxelOrigamiVector(a.x + b.x, a.y + b.y, a.z + b.z)
    }

    /// The difference.
    public static func - (a: VoxelOrigamiVector, b: VoxelOrigamiVector) -> VoxelOrigamiVector {
        VoxelOrigamiVector(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    /// Lexicographic order on (x, y, z).
    public static func < (a: VoxelOrigamiVector, b: VoxelOrigamiVector) -> Bool {
        if a.x != b.x { return a.x < b.x }
        if a.y != b.y { return a.y < b.y }
        return a.z < b.z
    }

    /// "(x, y, z)".
    public var description: String { "(\(x), \(y), \(z))" }
}

/// A rotation of the cube: a 3 × 3 integer matrix with entries −1, 0 and 1 and determinant 1.
public struct VoxelOrigamiRotation: Sendable, Hashable, Comparable {
    /// The entries, row by row.
    public let m: [Int]

    /// The rotation of the given row-major entries (nine values).
    init(_ m: [Int]) {
        precondition(m.count == 9, "a rotation has nine entries")
        self.m = m
    }

    /// The identity.
    public static let identity = VoxelOrigamiRotation([1, 0, 0, 0, 1, 0, 0, 0, 1])

    /// A quarter turn counter-clockwise (right-hand rule) about +x, +y and +z.
    static let quarterX = VoxelOrigamiRotation([1, 0, 0, 0, 0, -1, 0, 1, 0])
    static let quarterY = VoxelOrigamiRotation([0, 0, 1, 0, 1, 0, -1, 0, 0])
    static let quarterZ = VoxelOrigamiRotation([0, -1, 0, 1, 0, 0, 0, 0, 1])

    /// `turns` quarter turns counter-clockwise (right-hand rule) about the unit direction `axis`; `turns` is taken
    /// modulo 4 (a negative count turns clockwise). A turn about a negative axis is the opposite turn about the
    /// positive one.
    public static func quarter(about axis: VoxelOrigamiVector, turns: Int) -> VoxelOrigamiRotation {
        precondition(axis.isUnit, "a quarter turn is about a unit direction")
        let base: VoxelOrigamiRotation
        let sign: Int
        if axis.x != 0 {
            base = quarterX
            sign = axis.x
        } else if axis.y != 0 {
            base = quarterY
            sign = axis.y
        } else {
            base = quarterZ
            sign = axis.z
        }
        let count: Int = ((turns * sign) % 4 + 4) % 4
        var result: VoxelOrigamiRotation = .identity
        for _ in 0..<count { result = base * result }
        return result
    }

    /// The 24 rotations of the cube, in a fixed order (sorted by their entries).
    public static let all: [VoxelOrigamiRotation] = {
        var found: Set<VoxelOrigamiRotation> = [.identity]
        var frontier: [VoxelOrigamiRotation] = [.identity]
        while let next = frontier.popLast() {
            for generator in [quarterX, quarterY] {
                let product: VoxelOrigamiRotation = generator * next
                if found.insert(product).inserted { frontier.append(product) }
            }
        }
        return found.sorted()
    }()

    /// The rotation applied to `v`.
    public func applied(to v: VoxelOrigamiVector) -> VoxelOrigamiVector {
        VoxelOrigamiVector(m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z,
                           m[6] * v.x + m[7] * v.y + m[8] * v.z)
    }

    /// The composition: `(a * b).applied(to: v) == a.applied(to: b.applied(to: v))`.
    public static func * (a: VoxelOrigamiRotation, b: VoxelOrigamiRotation) -> VoxelOrigamiRotation {
        var out: [Int] = Array(repeating: 0, count: 9)
        for row in 0..<3 {
            for column in 0..<3 {
                var sum: Int = 0
                for k in 0..<3 { sum += a.m[row * 3 + k] * b.m[k * 3 + column] }
                out[row * 3 + column] = sum
            }
        }
        return VoxelOrigamiRotation(out)
    }

    /// Lexicographic order on the entries.
    public static func < (a: VoxelOrigamiRotation, b: VoxelOrigamiRotation) -> Bool {
        a.m.lexicographicallyPrecedes(b.m)
    }
}

/// The orientations a level's match allows (never a mirror image).
public enum VoxelOrigamiOrientations: String, Sendable, Hashable, Codable, CaseIterable {
    /// The identity only.
    case fixed
    /// The 4 quarter turns about +y.
    case upright
    /// The 24 rotations of the cube.
    case any

    /// The rotations of this group, in a fixed order (the identity first).
    public var group: [VoxelOrigamiRotation] {
        switch self {
        case .fixed:
            return [.identity]
        case .upright:
            return (0..<4).map { VoxelOrigamiRotation.quarter(about: VoxelOrigamiVector(0, 1, 0), turns: $0) }
        case .any:
            return [.identity] + VoxelOrigamiRotation.all.filter { $0 != .identity }
        }
    }
}

/// One cube of a level: its parent (nil for cube 0), its rest direction in the parent's frame and its hinge's starting
/// quarter turn (0 for cube 0).
public struct VoxelOrigamiCube: Sendable, Hashable, Codable {
    /// The parent cube, a lower index; nil for the root.
    public let parent: Int?
    /// The rest direction from the parent, one of the six units, in the parent's frame (the zero vector for the root).
    public let direction: VoxelOrigamiVector
    /// The hinge's starting quarter turn, 0 … 3 (0 for the root).
    public let startTurn: Int

    /// A cube of the given values (checked by the level).
    public init(parent: Int?, direction: VoxelOrigamiVector, startTurn: Int = 0) {
        self.parent = parent
        self.direction = direction
        self.startTurn = startTurn
    }

    /// The root cube.
    public static let root = VoxelOrigamiCube(parent: nil, direction: .zero, startTurn: 0)
}

/// A pose: every cube's cell and orientation.
public struct VoxelOrigamiPose: Sendable, Equatable {
    /// The cell of every cube, by index.
    public let cells: [VoxelOrigamiVector]
    /// The orientation of every cube, by index.
    public let orientations: [VoxelOrigamiRotation]

    /// Whether no cell holds two cubes.
    public var isCollisionFree: Bool { Set(cells).count == cells.count }

    /// The occupied cells, sorted.
    public var occupied: [VoxelOrigamiVector] { cells.sorted() }
}

/// A kernel action: `turn(hinge, step)` turns hinge `hinge` (1 … n − 1) by `step` quarter turns (+1 counter-clockwise
/// about the hinge's axis by the right-hand rule, −1 clockwise); it spends one action.
public enum VoxelOrigamiAction: Sendable, Hashable, Codable {
    /// Turn a hinge by one quarter turn either way.
    case turn(Int, Int)
}

/// A failed hinge turn (clarification Q3) or a spent budget.
public enum VoxelOrigamiFailure: Sendable, Hashable, Codable {
    /// A swinging cube would land on a still cube's cell.
    case collision(hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)
    /// A still cube lies in a swinging cube's swept band.
    case sweep(hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)
    /// The budget was spent without a match; the payload is the index of the last action.
    case budget(Int)

    /// The stable failure code: `collision`, `sweep` or `budget`.
    public var code: String {
        switch self {
        case .collision: "collision"
        case .sweep: "sweep"
        case .budget: "budget"
        }
    }
}

/// The exact lattice rules of Voxel Origami.
public enum VoxelOrigamiLattice {
    /// The pose of `cubes` at the quarter turns `turns` (one per cube; the root's is ignored): cube 0 at the origin with
    /// the identity; x(i) = x(p) + O(p) · d(i) and O(i) = O(p) · R(d(i), q(i)).
    public static func pose(_ cubes: [VoxelOrigamiCube], turns: [Int]) -> VoxelOrigamiPose {
        var cells: [VoxelOrigamiVector] = []
        var orientations: [VoxelOrigamiRotation] = []
        cells.reserveCapacity(cubes.count)
        orientations.reserveCapacity(cubes.count)
        for (index, cube) in cubes.enumerated() {
            guard let parent = cube.parent else {
                cells.append(.zero)
                orientations.append(.identity)
                continue
            }
            let frame: VoxelOrigamiRotation = orientations[parent]
            cells.append(cells[parent] + frame.applied(to: cube.direction))
            let turn: Int = index < turns.count ? turns[index] : 0
            orientations.append(frame * VoxelOrigamiRotation.quarter(about: cube.direction, turns: turn))
        }
        return VoxelOrigamiPose(cells: cells, orientations: orientations)
    }

    /// The descendants of cube `hinge` (every cube whose chain of parents reaches it), ascending.
    public static func descendants(_ cubes: [VoxelOrigamiCube], of hinge: Int) -> [Int] {
        var inside: [Bool] = Array(repeating: false, count: cubes.count)
        if hinge >= 0, hinge < cubes.count { inside[hinge] = true }
        var result: [Int] = []
        for (index, cube) in cubes.enumerated() where index > hinge {
            if let parent = cube.parent, inside[parent] {
                inside[index] = true
                result.append(index)
            }
        }
        return result
    }

    /// The world axis of hinge `hinge` in `pose`: the direction from its parent to it.
    public static func axis(_ cubes: [VoxelOrigamiCube], pose: VoxelOrigamiPose, hinge: Int) -> VoxelOrigamiVector {
        guard let parent = cubes[hinge].parent else { return .zero }
        return pose.cells[hinge] - pose.cells[parent]
    }

    /// The cubes a turn of hinge `hinge` swings in `pose`: its descendants whose offset from the hinge's axis is not
    /// zero, ascending. Empty for the root, a leaf, or a hinge whose descendants all lie on its axis.
    public static func swinging(_ cubes: [VoxelOrigamiCube], pose: VoxelOrigamiPose, hinge: Int) -> [Int] {
        guard hinge > 0, hinge < cubes.count else { return [] }
        let a: VoxelOrigamiVector = axis(cubes, pose: pose, hinge: hinge)
        let centre: VoxelOrigamiVector = pose.cells[hinge]
        return descendants(cubes, of: hinge).filter { !isParallel(pose.cells[$0] - centre, a) }
    }

    /// Whether `r` lies on the line of the unit direction `a` (its cross product with `a` is zero).
    static func isParallel(_ r: VoxelOrigamiVector, _ a: VoxelOrigamiVector) -> Bool {
        r.y * a.z - r.z * a.y == 0 && r.z * a.x - r.x * a.z == 0 && r.x * a.y - r.y * a.x == 0
    }

    /// The turn of hinge `hinge` by `step` (±1) from the quarter turns `turns`: nil when it is clear, else the failure
    /// (`collision` checked first, naming the lowest swinging cube that lands on a still cube's cell; then `sweep`,
    /// naming the lowest swinging cube whose arc a still cube blocks and the lowest such still cube; the still cubes are
    /// every cube outside the hinge cube and its subtree). The caller has
    /// already refused an unknown hinge, a wrong step and an idle hinge.
    public static func check(_ cubes: [VoxelOrigamiCube], turns: [Int], hinge: Int,
                             step: Int) -> VoxelOrigamiFailure? {
        let current: VoxelOrigamiPose = pose(cubes, turns: turns)
        let moving: [Int] = swinging(cubes, pose: current, hinge: hinge)
        // The body that turns is cube `hinge` and its subtree; its cubes on the axis spin in place. Everything else
        // stands still.
        var body: Set<Int> = Set(descendants(cubes, of: hinge))
        body.insert(hinge)
        let still: [Int] = (0..<cubes.count).filter { !body.contains($0) }
        var stillAt: [VoxelOrigamiVector: Int] = [:]
        for index in still { stillAt[current.cells[index]] = index }
        let a: VoxelOrigamiVector = axis(cubes, pose: current, hinge: hinge)
        let centre: VoxelOrigamiVector = current.cells[hinge]
        let rotation: VoxelOrigamiRotation = .quarter(about: a, turns: step)
        var ends: [Int: VoxelOrigamiVector] = [:]
        for index in moving {
            let end: VoxelOrigamiVector = centre + rotation.applied(to: current.cells[index] - centre)
            ends[index] = end
        }
        for index in moving {
            if let end = ends[index], let other = stillAt[end] {
                return .collision(hinge: hinge, moving: index, still: other, cell: end)
            }
        }
        for index in moving {
            guard let end = ends[index] else { continue }
            for other in still where inBand(still: current.cells[other], start: current.cells[index], end: end,
                                             axisPoint: centre, axis: a, step: step) {
                return .sweep(hinge: hinge, moving: index, still: other, cell: current.cells[other])
            }
        }
        return nil
    }

    /// The quarter turns after a clear turn of hinge `hinge` by `step`.
    public static func turned(_ turns: [Int], hinge: Int, step: Int) -> [Int] {
        var next: [Int] = turns
        next[hinge] = ((next[hinge] + step) % 4 + 4) % 4
        return next
    }

    /// Whether the still cube at `still` blocks a cube moving from `start` to `end` by a quarter turn of `step` (±1)
    /// about the line through `axisPoint` along the unit direction `axis` (clarification Q3): the still cube lies in the
    /// same layer (the same coordinate along the axis) and the open quarter arc traced by the moving cube's centre
    /// passes strictly within one cell of the still cube's centre in both in-plane coordinates (inside the open square of
    /// half-side 1 around it). Decided exactly: the square is clipped to the arc's 90° wedge, and the arc enters the
    /// clipped polygon exactly when the polygon's least squared distance from the axis is below ρ² and its greatest is
    /// above ρ², with every coordinate a rational number of small integers.
    public static func inBand(still: VoxelOrigamiVector, start: VoxelOrigamiVector, end: VoxelOrigamiVector,
                              axisPoint: VoxelOrigamiVector, axis: VoxelOrigamiVector, step: Int) -> Bool {
        let r0: VoxelOrigamiVector = start - axisPoint
        let r1: VoxelOrigamiVector = end - axisPoint
        let s: VoxelOrigamiVector = still - axisPoint
        // The coordinate along the axis and the plane (u, v) in which a positive quarter turn maps (u, v) to (−v, u).
        let along: (VoxelOrigamiVector) -> Int
        let plane: (VoxelOrigamiVector) -> (Int, Int)
        let sign: Int
        if axis.x != 0 {
            along = { $0.x }
            plane = { ($0.y, $0.z) }
            sign = axis.x
        } else if axis.y != 0 {
            along = { $0.y }
            plane = { ($0.z, $0.x) }
            sign = axis.y
        } else {
            along = { $0.z }
            plane = { ($0.x, $0.y) }
            sign = axis.z
        }
        guard along(s) == along(r0) else { return false }
        let p0: (Int, Int) = plane(r0)
        let p1: (Int, Int) = plane(r1)
        let (su, sv): (Int, Int) = plane(s)
        let q: Int = p0.0 * p0.0 + p0.1 * p0.1
        guard q > 0 else { return false }
        // The counter-clockwise start a and end b of the arc.
        let counterClockwise: Bool = step * sign > 0
        let a: (Int, Int) = counterClockwise ? p0 : p1
        let b: (Int, Int) = counterClockwise ? p1 : p0
        // The closed square of half-side 1 around the still cube, clipped to the wedge from a to b.
        var polygon: [Point] = [Point(su - 1, sv - 1), Point(su + 1, sv - 1), Point(su + 1, sv + 1),
                                Point(su - 1, sv + 1)]
        polygon = clip(polygon) { p in Fraction(a.0) * p.v - Fraction(a.1) * p.u }   // cross(a, p) ≥ 0
        polygon = clip(polygon) { p in p.u * Fraction(b.1) - p.v * Fraction(b.0) }   // cross(p, b) ≥ 0
        guard polygon.count >= 3, area(polygon) > Fraction(0) else { return false }
        let radius = Fraction(q)
        var greatest = Fraction(0)
        for vertex in polygon where vertex.squaredLength > greatest { greatest = vertex.squaredLength }
        guard greatest > radius else { return false }
        let least: Fraction = leastSquaredDistance(polygon, originInside: abs(su) <= 1 && abs(sv) <= 1)
        return least < radius
    }

    /// An exact rational number with a positive denominator (small integers only).
    struct Fraction: Comparable {
        let n: Int
        let d: Int

        init(_ n: Int, _ d: Int = 1) {
            precondition(d != 0, "a fraction has a non-zero denominator")
            let g: Int = Self.gcd(abs(n), abs(d))
            let s: Int = d < 0 ? -1 : 1
            self.n = s * n / max(g, 1)
            self.d = s * d / max(g, 1)
        }

        static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        static func + (x: Fraction, y: Fraction) -> Fraction { Fraction(x.n * y.d + y.n * x.d, x.d * y.d) }
        static func - (x: Fraction, y: Fraction) -> Fraction { Fraction(x.n * y.d - y.n * x.d, x.d * y.d) }
        static func * (x: Fraction, y: Fraction) -> Fraction { Fraction(x.n * y.n, x.d * y.d) }
        static func / (x: Fraction, y: Fraction) -> Fraction { Fraction(x.n * y.d, x.d * y.n) }
        static func < (x: Fraction, y: Fraction) -> Bool { x.n * y.d < y.n * x.d }
        static func == (x: Fraction, y: Fraction) -> Bool { x.n * y.d == y.n * x.d }
    }

    /// A point of the plane with rational coordinates.
    struct Point {
        let u: Fraction
        let v: Fraction

        init(_ u: Int, _ v: Int) {
            self.u = Fraction(u)
            self.v = Fraction(v)
        }

        init(_ u: Fraction, _ v: Fraction) {
            self.u = u
            self.v = v
        }

        var squaredLength: Fraction { u * u + v * v }
    }

    /// `polygon` clipped to the closed half-plane where `side` is at least 0 (Sutherland–Hodgman).
    static func clip(_ polygon: [Point], _ side: (Point) -> Fraction) -> [Point] {
        guard !polygon.isEmpty else { return [] }
        var out: [Point] = []
        let zero = Fraction(0)
        for index in 0..<polygon.count {
            let p: Point = polygon[index]
            let q: Point = polygon[(index + 1) % polygon.count]
            let fp: Fraction = side(p)
            let fq: Fraction = side(q)
            let pIn: Bool = !(fp < zero)
            let qIn: Bool = !(fq < zero)
            if pIn { out.append(p) }
            if pIn != qIn {
                let t: Fraction = fp / (fp - fq)
                out.append(Point(p.u + (q.u - p.u) * t, p.v + (q.v - p.v) * t))
            }
        }
        return out
    }

    /// Twice the signed area of `polygon`, made non-negative.
    static func area(_ polygon: [Point]) -> Fraction {
        var sum = Fraction(0)
        for index in 0..<polygon.count {
            let p: Point = polygon[index]
            let q: Point = polygon[(index + 1) % polygon.count]
            sum = sum + (p.u * q.v - q.u * p.v)
        }
        return sum < Fraction(0) ? Fraction(0) - sum : sum
    }

    /// The least squared distance from the origin to the closed convex `polygon`: 0 when the origin lies in it (it can
    /// only when it lies in the square, the polygon's wedge having its apex at the origin), else the least over its
    /// edges.
    static func leastSquaredDistance(_ polygon: [Point], originInside: Bool) -> Fraction {
        if originInside { return Fraction(0) }
        var least: Fraction? = nil
        for index in 0..<polygon.count {
            let p: Point = polygon[index]
            let q: Point = polygon[(index + 1) % polygon.count]
            let du: Fraction = q.u - p.u
            let dv: Fraction = q.v - p.v
            let length: Fraction = du * du + dv * dv
            var distance: Fraction = p.squaredLength
            if length > Fraction(0) {
                // The projection parameter of the origin onto the edge, clamped to 0 … 1.
                var t: Fraction = (Fraction(0) - (p.u * du + p.v * dv)) / length
                if t < Fraction(0) { t = Fraction(0) }
                if Fraction(1) < t { t = Fraction(1) }
                let cu: Fraction = p.u + du * t
                let cv: Fraction = p.v + dv * t
                distance = cu * cu + cv * cv
            }
            if let current = least {
                if distance < current { least = distance }
            } else {
                least = distance
            }
        }
        return least ?? Fraction(0)
    }

    /// The canonical form of `cells` under `group`: the lexicographically smallest sorted cell list among the rotated
    /// sets, each translated so its smallest x, y and z are 0.
    public static func canonical(_ cells: [VoxelOrigamiVector], group: [VoxelOrigamiRotation]) -> [VoxelOrigamiVector] {
        var best: [VoxelOrigamiVector]? = nil
        for rotation in group {
            let candidate: [VoxelOrigamiVector] = normalised(cells.map { rotation.applied(to: $0) })
            if let current = best {
                if candidate.lexicographicallyPrecedes(current) { best = candidate }
            } else {
                best = candidate
            }
        }
        return best ?? []
    }

    /// `cells` translated so the smallest x, y and z are 0, sorted.
    static func normalised(_ cells: [VoxelOrigamiVector]) -> [VoxelOrigamiVector] {
        guard let first = cells.first else { return [] }
        var lowX: Int = first.x
        var lowY: Int = first.y
        var lowZ: Int = first.z
        for cell in cells {
            lowX = min(lowX, cell.x)
            lowY = min(lowY, cell.y)
            lowZ = min(lowZ, cell.z)
        }
        let shift = VoxelOrigamiVector(lowX, lowY, lowZ)
        return cells.map { $0 - shift }.sorted()
    }

    /// The SHA-256 hex of the canonical form's text, "x,y,z;x,y,z;…".
    public static func canonicalHash(_ cells: [VoxelOrigamiVector], group: [VoxelOrigamiRotation]) -> String {
        let text: String = canonical(cells, group: group).map { "\($0.x),\($0.y),\($0.z)" }.joined(separator: ";")
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// The most cells of `occupied` that one rotation of `group` and one translation of `target` cover, with that
    /// rotation's index in `group` and the translation: every rotation in group order and every translation that maps
    /// a rotated target cell onto an occupied cell (in ascending order) are tried; the first strictly best is kept.
    public static func covered(target: [VoxelOrigamiVector], occupied: [VoxelOrigamiVector],
                               group: [VoxelOrigamiRotation]) -> (count: Int, rotation: Int,
                                                                  translation: VoxelOrigamiVector) {
        let occupiedSet: Set<VoxelOrigamiVector> = Set(occupied)
        var best: (count: Int, rotation: Int, translation: VoxelOrigamiVector) = (0, 0, .zero)
        for (index, rotation) in group.enumerated() {
            let rotated: [VoxelOrigamiVector] = target.map { rotation.applied(to: $0) }
            var shifts: Set<VoxelOrigamiVector> = []
            for t in rotated {
                for o in occupied { shifts.insert(o - t) }
            }
            for shift in shifts.sorted() {
                var count: Int = 0
                for t in rotated where occupiedSet.contains(t + shift) { count += 1 }
                if count > best.count { best = (count, index, shift) }
            }
        }
        return best
    }
}
