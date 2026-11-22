// NocturneGardenBloomTests — feature 381 (R02-G09-01) T-R02G0901-003 (FR-R02G0901-003, 014; SC-R02G0901-003;
// clarifications Q1, Q2, Q4). The shadow geometry checked against an independent reference written here: the cast
// vertices recomputed on exact rationals with the common denominator 2 (x = c + s·x', y = r + (e/2)·s·y'), and every
// cell of the whole bed decided by even-odd ray casting towards +x (half-open crossing rule, the crossing abscissa
// compared by cross multiplication) after an explicit point-on-segment test that counts boundary points as inside; the
// Core's `contains` is never called. Over 500 seeded blooms (seed 2_381: every kind, sizes 1 … 3, elevations 1 … 4,
// beds 16 … 32 × 12 … 24, anchors near and over the bed edges) every cell decision matches; over seeded gardens the
// mask equals the union recomputed from scratch, and match (shared and either counts, the cross-multiplication
// decision for several ratios), leak and boundary deviation equal brute force over all cells and all cell pairs; every
// outline is simple, counter-clockwise and within its stated bounds. Explicit types, plain loops, short runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

/// A seeded sample of the reference: one bloom on one bed under one sun elevation.
struct NocturneGardenBloomRefSample {
    /// The bloom.
    let bloom: NocturneGardenBloom
    /// The sun elevation.
    let elevation: Int
    /// The bed's width.
    let width: Int
    /// The bed's height.
    let height: Int
}

/// A seeded garden of the reference: blooms, a target and forbidden cells on one bed.
struct NocturneGardenBloomRefGarden {
    /// The blooms.
    let blooms: [NocturneGardenBloom]
    /// The sun elevation.
    let elevation: Int
    /// The bed's width.
    let width: Int
    /// The bed's height.
    let height: Int
    /// The target cells (inside the bed).
    let target: Set<Int>
    /// The forbidden cells (inside the bed).
    let forbidden: Set<Int>
}

struct NocturneGardenBloomTests {
    /// The seed of the samples.
    static let refSeed: UInt64 = 2_381
    /// The number of seeded blooms.
    static let refBloomCount: Int = 500
    /// The number of seeded gardens.
    static let refGardenCount: Int = 200

    // MARK: - Reference generation

    /// The 500 seeded blooms: every kind, size and elevation, anchors from three cells left of / four below the bed
    /// to two cells past its right / top edge.
    static func refSamples() -> [NocturneGardenBloomRefSample] {
        var random: SeededRandom = SeededRandom(seed: refSeed)
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        var result: [NocturneGardenBloomRefSample] = []
        for index in 0..<refBloomCount {
            let width: Int = random.int(16...32)
            let height: Int = random.int(12...24)
            let kind: NocturneGardenKind = kinds[index % kinds.count]
            let size: Int = 1 + (index / kinds.count) % 3
            let elevation: Int = 1 + (index / (kinds.count * 3)) % 4
            let column: Int
            let row: Int
            switch random.int(0...3) {
            case 0:
                column = random.int(-3...1)
                row = random.int(-4...(height + 1))
            case 1:
                column = random.int((width - 3)...(width + 1))
                row = random.int(-4...(height + 1))
            case 2:
                column = random.int(-3...(width + 1))
                row = random.int((height - 6)...(height + 1))
            default:
                column = random.int(0...(width - 1))
                row = random.int(0...(height - 1))
            }
            let bloom: NocturneGardenBloom = NocturneGardenBloom(kind: kind, column: column, row: row, size: size)
            result.append(NocturneGardenBloomRefSample(bloom: bloom, elevation: elevation, width: width,
                                                       height: height))
        }
        return result
    }

    /// The seeded gardens: 1 … 5 blooms, a random target (sometimes empty, sometimes the exact mask) and forbidden
    /// cells, on beds 16 … 32 × 12 … 24.
    static func refGardens() -> [NocturneGardenBloomRefGarden] {
        var random: SeededRandom = SeededRandom(seed: refSeed &+ 1)
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        var result: [NocturneGardenBloomRefGarden] = []
        for index in 0..<refGardenCount {
            let width: Int = random.int(16...32)
            let height: Int = random.int(12...24)
            let elevation: Int = random.int(1...4)
            var blooms: [NocturneGardenBloom] = []
            let count: Int = index % 9 == 0 ? 0 : random.int(1...5)
            for _ in 0..<count {
                blooms.append(NocturneGardenBloom(kind: kinds[random.int(0...5)], column: random.int(-2...(width)),
                                                  row: random.int(-3...(height - 2)), size: random.int(1...3)))
            }
            var target: Set<Int> = []
            var forbidden: Set<Int> = []
            let mode: Int = random.int(0...3)
            if mode == 1 {
                for bloom in blooms {
                    target.formUnion(refCells(bloom, elevation: elevation, width: width, height: height))
                }
            } else if mode >= 2 {
                let originColumn: Int = random.int(0...(width - 1))
                let originRow: Int = random.int(0...(height - 1))
                let spanColumns: Int = random.int(1...12)
                let spanRows: Int = random.int(1...12)
                for row in originRow..<min(height, originRow + spanRows) {
                    for column in originColumn..<min(width, originColumn + spanColumns) where random.int(0...4) > 0 {
                        target.insert(row * width + column)
                    }
                }
            }
            for cell in 0..<(width * height) where !target.contains(cell) && random.int(0...5) == 0 {
                forbidden.insert(cell)
            }
            result.append(NocturneGardenBloomRefGarden(blooms: blooms, elevation: elevation, width: width,
                                                       height: height, target: target, forbidden: forbidden))
        }
        return result
    }

    // MARK: - Reference geometry (exact rationals, denominator 2)

    /// The cast vertices recomputed here as numerators over the common denominator 2:
    /// x = c + s·x' → 2c + 2s·x'; y = r + (e/2)·s·y' → 2r + e·s·y'.
    static func refCast(_ bloom: NocturneGardenBloom, elevation: Int) -> [(x: Int, y: Int)] {
        var result: [(x: Int, y: Int)] = []
        for vertex in bloom.kind.outline {
            let x: Int = 2 * bloom.column + 2 * bloom.size * vertex.x
            let y: Int = 2 * bloom.row + elevation * bloom.size * vertex.y
            result.append((x: x, y: y))
        }
        return result
    }

    /// Whether (px, py) lies on the closed segment a–b: collinear and inside the segment's box.
    static func refOnSegment(_ ax: Int, _ ay: Int, _ bx: Int, _ by: Int, _ px: Int, _ py: Int) -> Bool {
        let cross: Int = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        if cross != 0 { return false }
        let inX: Bool = px >= min(ax, bx) && px <= max(ax, bx)
        let inY: Bool = py >= min(ay, by) && py <= max(ay, by)
        return inX && inY
    }

    /// Even-odd ray casting towards +x with boundary points inside: an edge crosses the ray when exactly one end lies
    /// strictly above py (half-open rule), and the crossing abscissa ax + (py − ay)(bx − ax)/(by − ay) is compared with
    /// px by cross multiplication with the sign of (by − ay).
    static func refInside(_ polygon: [(x: Int, y: Int)], _ px: Int, _ py: Int) -> Bool {
        let count: Int = polygon.count
        if count < 3 { return false }
        var inside: Bool = false
        for index in 0..<count {
            let a: (x: Int, y: Int) = polygon[index]
            let b: (x: Int, y: Int) = polygon[(index + 1) % count]
            if refOnSegment(a.x, a.y, b.x, b.y, px, py) { return true }
            let aAbove: Bool = a.y > py
            let bAbove: Bool = b.y > py
            if aAbove == bAbove { continue }
            let dy: Int = b.y - a.y
            // crossing − px = ((ax − px)·dy + (py − ay)·(bx − ax)) / dy; to the right when it is positive.
            let numerator: Int = (a.x - px) * dy + (py - a.y) * (b.x - a.x)
            let right: Bool = dy > 0 ? numerator > 0 : numerator < 0
            if right { inside.toggle() }
        }
        return inside
    }

    /// The reference cells of `bloom`: every cell of the whole bed whose doubled centre is inside or on the boundary.
    static func refCells(_ bloom: NocturneGardenBloom, elevation: Int, width: Int, height: Int) -> Set<Int> {
        let polygon: [(x: Int, y: Int)] = refCast(bloom, elevation: elevation)
        var result: Set<Int> = []
        for row in 0..<height {
            for column in 0..<width where refInside(polygon, 2 * column + 1, 2 * row + 1) {
                result.insert(row * width + column)
            }
        }
        return result
    }

    /// The reference boundary cells: cells of `set` inside the bed with a 4-neighbour outside the set or outside the
    /// bed, by (column, row).
    static func refBoundary(_ set: Set<Int>, width: Int, height: Int) -> [(column: Int, row: Int)] {
        var result: [(column: Int, row: Int)] = []
        for row in 0..<height {
            for column in 0..<width where set.contains(row * width + column) {
                let neighbours: [(Int, Int)] = [(column - 1, row), (column + 1, row), (column, row - 1),
                                                (column, row + 1)]
                var open: Bool = false
                for (c, r) in neighbours {
                    if c < 0 || c >= width || r < 0 || r >= height || !set.contains(r * width + c) { open = true }
                }
                if open { result.append((column: column, row: row)) }
            }
        }
        return result
    }

    /// The reference deviation: the symmetric Hausdorff distance in Chebyshev cells over all pairs of boundary cells;
    /// 0 for two empty boundaries, width + height when exactly one is empty.
    static func refDeviation(_ a: Set<Int>, _ b: Set<Int>, width: Int, height: Int) -> Int {
        let first: [(column: Int, row: Int)] = refBoundary(a, width: width, height: height)
        let second: [(column: Int, row: Int)] = refBoundary(b, width: width, height: height)
        if first.isEmpty && second.isEmpty { return 0 }
        if first.isEmpty || second.isEmpty { return width + height }
        var worst: Int = 0
        for p in first {
            var nearest: Int = Int.max
            for q in second {
                nearest = min(nearest, max(abs(p.column - q.column), abs(p.row - q.row)))
            }
            worst = max(worst, nearest)
        }
        for q in second {
            var nearest: Int = Int.max
            for p in first {
                nearest = min(nearest, max(abs(p.column - q.column), abs(p.row - q.row)))
            }
            worst = max(worst, nearest)
        }
        return worst
    }

    /// The sign of the cross product (b − a) × (c − a).
    static func refOrient(_ a: NocturneGardenLattice, _ b: NocturneGardenLattice, _ c: NocturneGardenLattice) -> Int {
        let value: Int = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        return value > 0 ? 1 : (value < 0 ? -1 : 0)
    }

    /// Whether the closed segments p1–p2 and q1–q2 share a point.
    static func refSegmentsTouch(_ p1: NocturneGardenLattice, _ p2: NocturneGardenLattice, _ q1: NocturneGardenLattice,
                                 _ q2: NocturneGardenLattice) -> Bool {
        let d1: Int = refOrient(q1, q2, p1)
        let d2: Int = refOrient(q1, q2, p2)
        let d3: Int = refOrient(p1, p2, q1)
        let d4: Int = refOrient(p1, p2, q2)
        if d1 * d2 < 0 && d3 * d4 < 0 { return true }
        if d1 == 0 && refOnSegment(q1.x, q1.y, q2.x, q2.y, p1.x, p1.y) { return true }
        if d2 == 0 && refOnSegment(q1.x, q1.y, q2.x, q2.y, p2.x, p2.y) { return true }
        if d3 == 0 && refOnSegment(p1.x, p1.y, p2.x, p2.y, q1.x, q1.y) { return true }
        if d4 == 0 && refOnSegment(p1.x, p1.y, p2.x, p2.y, q2.x, q2.y) { return true }
        return false
    }

    /// Whether `polygon` is simple: distinct vertices, no zero-length edge, adjacent edges meet only at their shared
    /// vertex (no fold back), non-adjacent edges never touch.
    static func refSimple(_ polygon: [NocturneGardenLattice]) -> Bool {
        let count: Int = polygon.count
        if count < 3 || Set(polygon).count != count { return false }
        for i in 0..<count {
            let a: NocturneGardenLattice = polygon[i]
            let b: NocturneGardenLattice = polygon[(i + 1) % count]
            let c: NocturneGardenLattice = polygon[(i + 2) % count]
            // Adjacent edges a–b and b–c: folding back means c lies on a–b or a lies on b–c.
            if refOrient(a, b, c) == 0 {
                let dot: Int = (b.x - a.x) * (c.x - b.x) + (b.y - a.y) * (c.y - b.y)
                if dot <= 0 { return false }
            }
            for j in 0..<count {
                let adjacent: Bool = j == i || j == (i + 1) % count || (j + 1) % count == i
                if adjacent { continue }
                let p: NocturneGardenLattice = polygon[j]
                let q: NocturneGardenLattice = polygon[(j + 1) % count]
                if refSegmentsTouch(a, b, p, q) { return false }
            }
        }
        return true
    }

    /// Twice the signed area (shoelace).
    static func refDoubleArea(_ polygon: [NocturneGardenLattice]) -> Int {
        var sum: Int = 0
        for i in 0..<polygon.count {
            let a: NocturneGardenLattice = polygon[i]
            let b: NocturneGardenLattice = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum
    }

    // MARK: - Tests

    /// The reference agrees with hand-computed cells: a lily of size 1 at (1, 0) under e = 2 on a 16 × 12 bed, its
    /// stem column (1, 0), (1, 1) dark, the cell left of the stem light, a vertex point counted inside.
    @Test func referenceAgreesWithHandCases() {
        let bloom: NocturneGardenBloom = NocturneGardenBloom(kind: .lily, column: 1, row: 0, size: 1)
        let cells: Set<Int> = Self.refCells(bloom, elevation: 2, width: 16, height: 12)
        #expect(cells.contains(0 * 16 + 1))
        #expect(cells.contains(1 * 16 + 1))
        #expect(!cells.contains(0 * 16 + 0))
        #expect(!cells.contains(0 * 16 + 2))
        // The square (0,0)–(2,0)–(2,2)–(0,2): corner, edge point and centre inside; outside points light.
        let square: [(x: Int, y: Int)] = [(x: 0, y: 0), (x: 2, y: 0), (x: 2, y: 2), (x: 0, y: 2)]
        #expect(Self.refInside(square, 0, 0))
        #expect(Self.refInside(square, 2, 1))
        #expect(Self.refInside(square, 1, 1))
        #expect(!Self.refInside(square, 3, 1))
        #expect(!Self.refInside(square, -1, 1))
        #expect(!Self.refInside(square, 1, 3))
        #expect(cells == bloom.cells(elevation: 2, width: 16, height: 12))
    }

    /// The 500 seeded blooms in five groups of 100: the cast polygon equals the reference's exact rational vertices and
    /// every cell of the whole bed is decided as the even-odd reference decides it (cells outside the polygon light).
    @Test(arguments: [0, 1, 2, 3, 4])
    func everyCellDecisionMatchesTheReference(group: Int) {
        let samples: [NocturneGardenBloomRefSample] = Self.refSamples()
        #expect(samples.count == Self.refBloomCount)
        var darkTotal: Int = 0
        var clipped: Int = 0
        for index in (group * 100)..<((group + 1) * 100) {
            let sample: NocturneGardenBloomRefSample = samples[index]
            let cast: [NocturneGardenLattice] = sample.bloom.castPolygon(elevation: sample.elevation)
            let reference: [(x: Int, y: Int)] = Self.refCast(sample.bloom, elevation: sample.elevation)
            #expect(cast.count == reference.count, "vertices \(index)")
            for vertex in 0..<min(cast.count, reference.count) {
                #expect(cast[vertex].x == reference[vertex].x && cast[vertex].y == reference[vertex].y,
                        "vertex \(vertex) of bloom \(index)")
            }
            let core: Set<Int> = sample.bloom.cells(elevation: sample.elevation, width: sample.width,
                                                    height: sample.height)
            for row in 0..<sample.height {
                for column in 0..<sample.width {
                    let cell: Int = row * sample.width + column
                    let expected: Bool = Self.refInside(reference, 2 * column + 1, 2 * row + 1)
                    #expect(core.contains(cell) == expected,
                            "bloom \(index) \(sample.bloom) e=\(sample.elevation) cell (\(column), \(row))")
                }
            }
            let bedSize: Int = sample.width * sample.height
            for cell in core { #expect(cell >= 0 && cell < bedSize, "bloom \(index) cell \(cell) outside the bed") }
            darkTotal += core.count
            let unclipped: Set<Int> = Self.refCells(sample.bloom, elevation: sample.elevation, width: sample.width + 40,
                                                    height: sample.height + 40)
            if core.count < unclipped.count || sample.bloom.column < 0 || sample.bloom.row < 0 { clipped += 1 }
        }
        #expect(darkTotal > 0)
        #expect(clipped > 0, "group \(group) has blooms at or over the bed edges")
    }

    /// Kinds, sizes and elevations are all covered by the 500 samples.
    @Test func samplesCoverEveryKindSizeAndElevation() {
        let samples: [NocturneGardenBloomRefSample] = Self.refSamples()
        var kinds: Set<NocturneGardenKind> = []
        var sizes: Set<Int> = []
        var elevations: Set<Int> = []
        var widths: Set<Int> = []
        var heights: Set<Int> = []
        for sample in samples {
            kinds.insert(sample.bloom.kind)
            sizes.insert(sample.bloom.size)
            elevations.insert(sample.elevation)
            widths.insert(sample.width)
            heights.insert(sample.height)
        }
        #expect(kinds.count == 6)
        #expect(sizes == [1, 2, 3])
        #expect(elevations == [1, 2, 3, 4])
        #expect(widths.contains(32) && heights.contains(24))
    }

    /// Over the seeded gardens in two groups: the mask equals the union recomputed from scratch; shared and either
    /// counts, the match decision for several ratios, the leak and the boundary deviation equal brute force.
    @Test(arguments: [0, 1])
    func maskMatchLeakAndDeviationEqualBruteForce(group: Int) throws {
        let gardens: [NocturneGardenBloomRefGarden] = Self.refGardens()
        let half: Int = Self.refGardenCount / 2
        var ratios: [NocturneGardenRatio] = [NocturneGardenRatio.whole]
        let fractions: [(Int, Int)] = [(1, 2), (3, 4), (2, 3), (1, 1_000), (999, 1_000), (5, 8)]
        for (p, q) in fractions { ratios.append(try NocturneGardenRatio(p, q)) }
        var matchedSome: Bool = false
        var refusedSome: Bool = false
        for index in (group * half)..<((group + 1) * half) {
            let garden: NocturneGardenBloomRefGarden = gardens[index]
            let mask: NocturneGardenMask = NocturneGardenMask.union(garden.blooms, elevation: garden.elevation,
                                                                    width: garden.width, height: garden.height)
            var expected: Set<Int> = []
            for bloom in garden.blooms {
                expected.formUnion(Self.refCells(bloom, elevation: garden.elevation, width: garden.width,
                                                 height: garden.height))
            }
            #expect(mask.cells == expected, "garden \(index) mask")
            var shared: Int = 0
            var either: Int = 0
            var leak: Int = 0
            for cell in 0..<(garden.width * garden.height) {
                let dark: Bool = expected.contains(cell)
                let wanted: Bool = garden.target.contains(cell)
                if dark && wanted { shared += 1 }
                if dark || wanted { either += 1 }
                if dark && garden.forbidden.contains(cell) { leak += 1 }
            }
            #expect(mask.intersection(garden.target) == shared, "garden \(index) shared")
            #expect(mask.union(garden.target) == either, "garden \(index) either")
            #expect(mask.leak(forbidden: garden.forbidden) == leak, "garden \(index) leak")
            var checks: [NocturneGardenRatio] = ratios
            if shared > 0 { checks.append(try NocturneGardenRatio(shared, either)) }
            if shared > 1 { checks.append(try NocturneGardenRatio(shared - 1, either)) }
            if shared > 0 && shared < either { checks.append(try NocturneGardenRatio(shared + 1, either)) }
            for ratio in checks {
                let decision: Bool = either > 0 && shared * ratio.denominator >= ratio.numerator * either
                let core: Bool = NocturneGardenMask.matches(mask: mask, target: garden.target, required: ratio)
                #expect(core == decision, "garden \(index) match \(shared)/\(either) vs \(ratio.text)")
                if decision { matchedSome = true } else { refusedSome = true }
            }
            let deviation: Int = Self.refDeviation(expected, garden.target, width: garden.width,
                                                   height: garden.height)
            #expect(NocturneGardenMask.boundaryDeviation(mask.cells, garden.target, width: garden.width,
                                                         height: garden.height) == deviation,
                    "garden \(index) deviation")
            #expect(NocturneGardenMask.boundaryDeviation(garden.target, mask.cells, width: garden.width,
                                                         height: garden.height) == deviation,
                    "garden \(index) deviation symmetric")
            var boundary: Set<Int> = []
            for cell in Self.refBoundary(expected, width: garden.width, height: garden.height) {
                boundary.insert(cell.row * garden.width + cell.column)
            }
            #expect(NocturneGardenMask.boundary(expected, width: garden.width, height: garden.height) == boundary,
                    "garden \(index) boundary cells")
        }
        #expect(matchedSome && refusedSome)
    }

    /// The deviation's stated cases: both empty 0, one empty width + height, and an equal pair 0.
    @Test func deviationEdgeCasesEqualTheReference() {
        let empty: Set<Int> = []
        let block: Set<Int> = [17, 18, 33, 34]
        #expect(NocturneGardenMask.boundaryDeviation(empty, empty, width: 16, height: 12) == 0)
        #expect(NocturneGardenMask.boundaryDeviation(block, empty, width: 16, height: 12) == 28)
        #expect(NocturneGardenMask.boundaryDeviation(empty, block, width: 16, height: 12) == 28)
        #expect(NocturneGardenMask.boundaryDeviation(block, block, width: 16, height: 12) == 0)
        #expect(Self.refDeviation(block, empty, width: 16, height: 12) == 28)
        let far: Set<Int> = [11 * 16 + 15]
        #expect(NocturneGardenMask.boundaryDeviation(block, far, width: 16, height: 12)
                == Self.refDeviation(block, far, width: 16, height: 12))
        #expect(Self.refDeviation(block, far, width: 16, height: 12) == 14)
    }

    /// An empty union never matches, even at the smallest ratio.
    @Test func emptyUnionNeverMatches() throws {
        let mask: NocturneGardenMask = NocturneGardenMask(width: 16, height: 12, cells: [])
        #expect(!NocturneGardenMask.matches(mask: mask, target: [], required: try NocturneGardenRatio(1, 1_000)))
    }

    /// Every outline is simple, counter-clockwise, starts at the foot (0, 0), has at most 16 vertices and lies in
    /// x −1 … 2, y 0 … 6; every cast polygon (sizes 1 … 3, elevations 1 … 4) stays simple and counter-clockwise.
    @Test func everyOutlineIsSimpleAndWithinBounds() {
        for kind in NocturneGardenKind.allCases {
            let outline: [NocturneGardenLattice] = kind.outline
            #expect(outline.count >= 3 && outline.count <= 16, "\(kind) vertex count")
            #expect(outline.first == NocturneGardenLattice(x: 0, y: 0), "\(kind) foot")
            for vertex in outline {
                #expect(vertex.x >= -1 && vertex.x <= 2 && vertex.y >= 0 && vertex.y <= 6, "\(kind) \(vertex)")
            }
            #expect(Self.refSimple(outline), "\(kind) simple")
            #expect(Self.refDoubleArea(outline) > 0, "\(kind) counter-clockwise")
            for size in NocturneGardenBloom.sizes {
                for elevation in NocturneGardenBloom.elevations {
                    let bloom: NocturneGardenBloom = NocturneGardenBloom(kind: kind, column: 3, row: 2, size: size)
                    let cast: [NocturneGardenLattice] = bloom.castPolygon(elevation: elevation)
                    #expect(Self.refSimple(cast), "\(kind) s=\(size) e=\(elevation) simple")
                    #expect(Self.refDoubleArea(cast) > 0, "\(kind) s=\(size) e=\(elevation) counter-clockwise")
                }
            }
        }
        // The simplicity check itself refuses a bow tie and a fold back.
        let bowTie: [NocturneGardenLattice] = [NocturneGardenLattice(x: 0, y: 0), NocturneGardenLattice(x: 2, y: 2),
                                               NocturneGardenLattice(x: 2, y: 0), NocturneGardenLattice(x: 0, y: 2)]
        #expect(!Self.refSimple(bowTie))
        let fold: [NocturneGardenLattice] = [NocturneGardenLattice(x: 0, y: 0), NocturneGardenLattice(x: 2, y: 0),
                                             NocturneGardenLattice(x: 1, y: 0), NocturneGardenLattice(x: 1, y: 2)]
        #expect(!Self.refSimple(fold))
    }
}
