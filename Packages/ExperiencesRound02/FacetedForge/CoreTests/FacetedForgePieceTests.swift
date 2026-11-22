// FacetedForgePieceTests — feature 371 (R02-G08-01) T-R02G0801-003 (FR-R02G0801-002, 003, 014; SC-R02G0801-003;
// clarifications Q1 … Q3). The piece geometry checked against an independent reference written here: corners by
// brute force over every triple of the accumulated planes (own Cramer solve on homogeneous Int64 points, own
// half-space test), and the volume by the divergence theorem from the origin, V = (1/6) Σ_faces Σ_fan q0 · (qi × qi+1),
// a decomposition different from the kernel's apex fan. Over the 500 seeded fixtures with their cuts plus random extra
// cuts (seed 2_376): corners, faces, orientation, volume, halves, conservation, edge incidence and canonical order
// after every cut; then degenerate planes refused as `.miss`, ranges refused as `.action("range")` and the cube's slab
// volumes at each depth.
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import FacetedForgeCore

/// An exact point x/w, y/w, z/w of the reference, reduced with w > 0.
struct FacetedForgeRefPoint: Hashable {
    let x: Int64
    let y: Int64
    let z: Int64
    let w: Int64
}

/// An integer vector of the reference.
struct FacetedForgeRefVector: Hashable {
    let x: Int64
    let y: Int64
    let z: Int64

    /// `a − b`.
    static func - (a: Self, b: Self) -> Self { Self(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }

    /// The cross product `a × b`.
    func cross(_ b: Self) -> Self {
        Self(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
    }

    /// The dot product `a · b`.
    func dot(_ b: Self) -> Int64 { x * b.x + y * b.y + z * b.z }
}

/// A piece of the reference walk with every half-space added since the crystal (redundant ones kept).
struct FacetedForgeRefEntry {
    let piece: FacetedForgePiece
    let planes: [FacetedForgeHalfSpace]
}

/// The independent reference geometry.
enum FacetedForgeReference {
    /// The greatest common divisor of two non-negative integers.
    static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var p: Int64 = a
        var q: Int64 = b
        while q != 0 {
            let r: Int64 = p % q
            p = q
            q = r
        }
        return p
    }

    /// The outward normal sign·n of a half-space.
    static func normal(_ h: FacetedForgeHalfSpace) -> FacetedForgeRefVector {
        let d: FacetedForgeDirection = FacetedForgeDirection.all[h.direction]
        return FacetedForgeRefVector(x: Int64(h.sign * d.x), y: Int64(h.sign * d.y), z: Int64(h.sign * d.z))
    }

    /// The bound sign·depth of a half-space.
    static func bound(_ h: FacetedForgeHalfSpace) -> Int64 { Int64(h.sign * h.depth) }

    /// Every distinct point where three of `planes` meet and every plane holds.
    static func corners(_ planes: [FacetedForgeHalfSpace]) -> [FacetedForgeRefPoint] {
        let normals: [FacetedForgeRefVector] = planes.map(normal)
        let bounds: [Int64] = planes.map(bound)
        var found: Set<FacetedForgeRefPoint> = []
        let count: Int = planes.count
        for i in 0..<count {
            for j in 0..<count where j > i {
                for k in 0..<count where k > j {
                    let a: FacetedForgeRefVector = normals[i]
                    let b: FacetedForgeRefVector = normals[j]
                    let c: FacetedForgeRefVector = normals[k]
                    // Cramer: p = (ki (b × c) + kj (c × a) + kk (a × b)) / (a · (b × c)).
                    let bc: FacetedForgeRefVector = b.cross(c)
                    let ca: FacetedForgeRefVector = c.cross(a)
                    let ab: FacetedForgeRefVector = a.cross(b)
                    var w: Int64 = a.dot(bc)
                    if w == 0 { continue }
                    var x: Int64 = bounds[i] * bc.x + bounds[j] * ca.x + bounds[k] * ab.x
                    var y: Int64 = bounds[i] * bc.y + bounds[j] * ca.y + bounds[k] * ab.y
                    var z: Int64 = bounds[i] * bc.z + bounds[j] * ca.z + bounds[k] * ab.z
                    if w < 0 {
                        x = -x
                        y = -y
                        z = -z
                        w = -w
                    }
                    var inside: Bool = true
                    for m in 0..<count {
                        let n: FacetedForgeRefVector = normals[m]
                        if n.x * x + n.y * y + n.z * z > bounds[m] * w {
                            inside = false
                            break
                        }
                    }
                    if !inside { continue }
                    let g: Int64 = gcd(gcd(abs(x), abs(y)), gcd(abs(z), w))
                    found.insert(FacetedForgeRefPoint(x: x / g, y: y / g, z: z / g, w: w / g))
                }
            }
        }
        return Array(found)
    }

    /// A reference point as the kernel's exact point.
    static func point(_ p: FacetedForgeRefPoint) throws -> FacetedForgePoint {
        FacetedForgePoint(x: try FacetedForgeFraction(p.x, p.w), y: try FacetedForgeFraction(p.y, p.w),
                          z: try FacetedForgeFraction(p.z, p.w))
    }

    /// The least common multiple of every coordinate denominator of `points`.
    static func scale(_ points: [FacetedForgePoint]) -> Int64 {
        var l: Int64 = 1
        for p in points {
            for d in [p.x.denominator, p.y.denominator, p.z.denominator] { l = l / gcd(l, d) * d }
        }
        return l
    }

    /// `p` multiplied by `l` (a multiple of every denominator) as integers.
    static func scaled(_ p: FacetedForgePoint, _ l: Int64) -> FacetedForgeRefVector {
        FacetedForgeRefVector(x: p.x.numerator * (l / p.x.denominator), y: p.y.numerator * (l / p.y.denominator),
                              z: p.z.numerator * (l / p.z.denominator))
    }

    /// The volume by the divergence theorem from the origin over the faces' rings.
    static func volume(_ piece: FacetedForgePiece) throws -> FacetedForgeFraction {
        let l: Int64 = scale(piece.corners)
        var six: Int64 = 0
        for face in piece.faces {
            let ring: [FacetedForgeRefVector] = face.corners.map { scaled($0, l) }
            for i in 1..<(ring.count - 1) { six += ring[0].dot(ring[i].cross(ring[i + 1])) }
        }
        return try FacetedForgeFraction(six, 6 * l * l * l)
    }

    /// Whether `a` comes before `b`: volume descending, face count descending, sorted corners lexicographic.
    static func precedes(_ a: FacetedForgePiece, _ b: FacetedForgePiece) -> Bool {
        if a.volume != b.volume { return b.volume < a.volume }
        if a.faceCount != b.faceCount { return a.faceCount > b.faceCount }
        let n: Int = min(a.corners.count, b.corners.count)
        for i in 0..<n where a.corners[i] != b.corners[i] { return a.corners[i] < b.corners[i] }
        return a.corners.count < b.corners.count
    }

    /// Every failure of `piece` against the reference built from `planes`; empty when it agrees.
    static func check(_ piece: FacetedForgePiece, planes: [FacetedForgeHalfSpace]) throws -> [String] {
        var issues: [String] = []
        var expected: [FacetedForgePoint] = []
        for p in corners(planes) { expected.append(try point(p)) }
        expected.sort()
        if piece.corners != expected { issues.append("corners") }
        let l: Int64 = scale(expected)
        let points: [FacetedForgeRefVector] = expected.map { scaled($0, l) }
        // Faces: exactly the planes with at least three corners, each ring the convex hull of them, anticlockwise.
        var facePlanes: Set<FacetedForgeHalfSpace> = []
        for h in planes {
            let n: FacetedForgeRefVector = normal(h)
            var on: Int = 0
            for p in points where n.dot(p) == bound(h) * l { on += 1 }
            if on >= 3 { facePlanes.insert(h) }
        }
        if Set(piece.faces.map(\.plane)) != facePlanes || piece.faces.count != facePlanes.count {
            issues.append("faces")
        }
        if piece.faces.map(\.plane) != piece.halfSpaces { issues.append("face order") }
        for face in piece.faces {
            let n: FacetedForgeRefVector = normal(face.plane)
            var onPlane: Set<FacetedForgePoint> = []
            for (index, p) in points.enumerated() where n.dot(p) == bound(face.plane) * l {
                onPlane.insert(expected[index])
            }
            if Set(face.corners) != onPlane || face.corners.count != onPlane.count { issues.append("face corners") }
            if let first = face.corners.first, first != face.corners.min() { issues.append("face start") }
            let ring: [FacetedForgeRefVector] = face.corners.map { scaled($0, l) }
            for i in ring.indices {
                let a: FacetedForgeRefVector = ring[i]
                let b: FacetedForgeRefVector = ring[(i + 1) % ring.count]
                for j in ring.indices where j != i && j != (i + 1) % ring.count {
                    if n.dot((b - a).cross(ring[j] - a)) <= 0 { issues.append("orientation") }
                }
            }
        }
        if try volume(piece) != piece.volume { issues.append("volume") }
        if !piece.edgeIncidence.allSatisfy({ $0 == 2 }) { issues.append("incidence") }
        if piece.corners.count - piece.edges.count + piece.faceCount != 2 { issues.append("euler") }
        return issues
    }
}

struct FacetedForgePieceTests {
    /// A cube −a … a.
    static func cube(_ a: Int) -> [FacetedForgeHalfSpace] {
        let x: [FacetedForgeHalfSpace] = FacetedForgeFixtures.slab(0, -a, a)
        let y: [FacetedForgeHalfSpace] = FacetedForgeFixtures.slab(1, -a, a)
        let z: [FacetedForgeHalfSpace] = FacetedForgeFixtures.slab(2, -a, a)
        return (x + y + z).sorted()
    }

    /// Cuts entry `index` of `entries` (reference canonical order) and checks the halves; returns the failures.
    static func cutAndCheck(_ entries: inout [FacetedForgeRefEntry], index: Int, direction: Int, depth: Int,
                            crystal: FacetedForgePiece) throws -> [String] {
        var issues: [String] = []
        let parent: FacetedForgeRefEntry = entries[index]
        // The reference agrees that the plane crosses the interior: a corner strictly on each side.
        let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
        var below: Bool = false
        var above: Bool = false
        for p in FacetedForgeReference.corners(parent.planes) {
            let s: Int64 = Int64(d.x) * p.x + Int64(d.y) * p.y + Int64(d.z) * p.z - Int64(depth) * p.w
            if s < 0 { below = true }
            if s > 0 { above = true }
        }
        if !(below && above) { issues.append("crossing") }
        let halves: (below: FacetedForgePiece, above: FacetedForgePiece) = try parent.piece.cut(direction: direction,
                                                                                               depth: depth)
        let lower: [FacetedForgeHalfSpace] = parent.planes + [FacetedForgeHalfSpace(direction: direction, sign: 1,
                                                                                    depth: depth)]
        let upper: [FacetedForgeHalfSpace] = parent.planes + [FacetedForgeHalfSpace(direction: direction, sign: -1,
                                                                                    depth: depth)]
        issues += try FacetedForgeReference.check(halves.below, planes: lower).map { "below " + $0 }
        issues += try FacetedForgeReference.check(halves.above, planes: upper).map { "above " + $0 }
        if try halves.below.volume.adding(halves.above.volume) != parent.piece.volume { issues.append("halves") }
        entries.remove(at: index)
        entries.append(FacetedForgeRefEntry(piece: halves.below, planes: lower))
        entries.append(FacetedForgeRefEntry(piece: halves.above, planes: upper))
        entries.sort { FacetedForgeReference.precedes($0.piece, $1.piece) }
        let pieces: [FacetedForgePiece] = entries.map(\.piece)
        if FacetedForgePiece.canonical(pieces) != pieces { issues.append("canonical") }
        for i in pieces.indices.dropFirst() where FacetedForgePiece.precedes(pieces[i], pieces[i - 1]) {
            issues.append("order")
        }
        var total: FacetedForgeFraction = .zero
        for piece in pieces { total = try total.adding(piece.volume) }
        if total != crystal.volume { issues.append("conservation") }
        return issues
    }

    /// SC-R02G0801-003: over 500 fixtures with their cuts and three extra random cuts each (seed 2_376), every piece
    /// equals the independent reference after every cut, the halves and all pieces conserve volume, every edge lies on
    /// two faces and the pieces stay in canonical order.
    @Test func everyCutMatchesTheIndependentReference() throws {
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: 2_376)
        var failures: [String] = []
        var cuts: Int = 0
        for fixture in FacetedForgeFixtures.fixtures(500) {
            let crystal: FacetedForgePiece = fixture.level.crystal
            let crystalIssues: [String] = try FacetedForgeReference.check(crystal, planes: fixture.level.planes)
            if !crystalIssues.isEmpty { failures.append("\(fixture.level.id) crystal \(crystalIssues)") }
            var entries: [FacetedForgeRefEntry] = [FacetedForgeRefEntry(piece: crystal, planes: fixture.level.planes)]
            var plan: [(Int, Int, Int)] = []
            for action in fixture.actions {
                switch action {
                case let .cut(index, direction, depth): plan.append((index, direction, depth))
                }
            }
            for step in 0..<(plan.count + 3) {
                let cut: (Int, Int, Int)
                if step < plan.count {
                    cut = plan[step]
                } else {
                    cut = FacetedForgeFixtures.randomCut(entries.map(\.piece), &random)
                }
                let issues: [String] = try Self.cutAndCheck(&entries, index: cut.0, direction: cut.1, depth: cut.2,
                                                            crystal: crystal)
                cuts += 1
                if !issues.isEmpty { failures.append("\(fixture.level.id) cut \(step) \(cut) \(issues)") }
            }
        }
        #expect(failures.isEmpty, "\(failures.prefix(10))")
        #expect(cuts >= 500 * 4)
    }

    /// FR-R02G0801-003: planes through a corner only, through an edge, along a face or missing the cube are refused.
    @Test func degeneratePlanesOfTheCubeAreMisses() throws {
        let cube: FacetedForgePiece = try FacetedForgePiece(halfSpaces: Self.cube(2))
        let misses: [(Int, Int)] = [
            (9, 6), (9, -6), (12, 6), (10, -6),  // a body diagonal through one corner
            (3, 4), (4, -4), (7, 4), (6, 4),  // a face diagonal along an edge
            (0, 2), (1, -2), (2, 2),  // an axis along a face
            (0, 5), (5, -9), (9, 24), (3, -24),  // planes missing the cube
        ]
        for (direction, depth) in misses {
            #expect(throws: FacetedForgeError.miss) { try cube.cut(direction: direction, depth: depth) }
            #expect(!cube.isCrossed(direction: direction, depth: depth))
        }
    }

    /// FR-R02G0801-003: on every fixture piece, each supporting plane at an integer depth (touching a corner, an edge
    /// or a face) and the plane one beyond it are refused as misses, and the piece is unchanged.
    @Test func supportingPlanesOfEveryPieceAreMisses() throws {
        var failures: [String] = []
        for fixture in FacetedForgeFixtures.fixtures(500) {
            var pieces: [FacetedForgePiece] = [fixture.level.crystal]
            for action in fixture.actions {
                switch action {
                case let .cut(index, direction, depth):
                    let halves: (below: FacetedForgePiece, above: FacetedForgePiece) = try pieces[index]
                        .cut(direction: direction, depth: depth)
                    pieces.remove(at: index)
                    pieces = FacetedForgePiece.canonical(pieces + [halves.below, halves.above])
                }
            }
            for piece in pieces {
                let copy: FacetedForgePiece = piece
                for direction in 0..<13 {
                    let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
                    var values: [FacetedForgeFraction] = []
                    for p in piece.corners {
                        var v: FacetedForgeFraction = .zero
                        v = try v.adding(p.x.multiplying(try FacetedForgeFraction(Int64(d.x))))
                        v = try v.adding(p.y.multiplying(try FacetedForgeFraction(Int64(d.y))))
                        v = try v.adding(p.z.multiplying(try FacetedForgeFraction(Int64(d.z))))
                        values.append(v)
                    }
                    guard let low = values.min(), let high = values.max() else { continue }
                    var depths: [Int] = []
                    if high.denominator == 1 { depths += [Int(high.numerator), Int(high.numerator) + 1] }
                    if low.denominator == 1 { depths += [Int(low.numerator), Int(low.numerator) - 1] }
                    for depth in depths where FacetedForgeHalfSpace.depths.contains(depth) {
                        do {
                            _ = try piece.cut(direction: direction, depth: depth)
                            failures.append("\(fixture.level.id) \(direction) \(depth) accepted")
                        } catch FacetedForgeError.miss {
                        } catch {
                            failures.append("\(fixture.level.id) \(direction) \(depth) \(error)")
                        }
                    }
                }
                if copy != piece { failures.append("\(fixture.level.id) changed") }
            }
        }
        #expect(failures.isEmpty, "\(failures.prefix(10))")
    }

    /// FR-R02G0801-002: a direction outside 0 … 12 or a depth outside −24 … 24 is refused as `.action("range")`.
    @Test func outOfRangeCutsAreRefused() throws {
        let cube: FacetedForgePiece = try FacetedForgePiece(halfSpaces: Self.cube(2))
        let cuts: [(Int, Int)] = [(-1, 0), (13, 0), (100, 1), (0, -25), (0, 25), (9, 1_000), (-1, 25)]
        for (direction, depth) in cuts {
            #expect(throws: FacetedForgeError.action("range")) { try cube.cut(direction: direction, depth: depth) }
            #expect(!cube.isCrossed(direction: direction, depth: depth))
        }
    }

    /// FR-R02G0801-002: the cube −6 … 6 cut across each axis at every depth gives slabs of (d + 6)·144 and (6 − d)·144;
    /// depths outside −5 … 5 are misses.
    @Test func cubeSlabsHaveTheirVolumes() throws {
        let cube: FacetedForgePiece = try FacetedForgePiece(halfSpaces: Self.cube(6))
        #expect(cube.volume == (try FacetedForgeFraction(1_728)))
        for direction in 0..<3 {
            for depth in FacetedForgeHalfSpace.depths {
                if depth > -6 && depth < 6 {
                    let halves: (below: FacetedForgePiece, above: FacetedForgePiece) = try cube.cut(
                        direction: direction, depth: depth)
                    #expect(halves.below.volume == (try FacetedForgeFraction(Int64((depth + 6) * 144))))
                    #expect(halves.above.volume == (try FacetedForgeFraction(Int64((6 - depth) * 144))))
                    #expect(halves.below.faceCount == 6 && halves.above.faceCount == 6)
                    #expect(try FacetedForgeReference.volume(halves.below) == halves.below.volume)
                } else {
                    #expect(throws: FacetedForgeError.miss) { try cube.cut(direction: direction, depth: depth) }
                }
            }
        }
    }
}
