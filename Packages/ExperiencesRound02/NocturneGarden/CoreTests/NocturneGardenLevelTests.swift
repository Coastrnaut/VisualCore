// NocturneGardenLevelTests — feature 381 (R02-G09-01) T-R02G0901-002 (FR-R02G0901-001, 003, 005, 009, 011, 013, 014;
// SC-R02G0901-001, 005; clarifications Q1, Q2, Q5). Levels and the exact geometry: the reason codes, every range
// refusal, the stored form's round trip with its fingerprint, damaged, edited and newer forms refused, names in words,
// the six outlines simple and in bounds, hand-computed cell masks, the match, leak and deviation rules, and the 500
// seeded fixtures valid with arrangements that match their targets. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import NocturneGardenCore

struct NocturneGardenLevelTests {
    /// A valid level with the given overrides: a 16 × 12 bed, target cells 0 … 3, forbidden cells 4 and 5.
    static func level(id: String = "garden-one", difficulty: Int = 1, width: Int = 16, height: Int = 12,
                      target: Set<Int> = [0, 1, 2, 3], forbidden: Set<Int> = [4, 5],
                      supply: [NocturneGardenKind: Int] = [.tulip: 2, .rose: 1], sizes: Set<Int> = [1, 2],
                      elevations: Set<Int> = [1, 2, 3], sun: Int = 2, budget: Int = 6,
                      required: NocturneGardenRatio? = nil, leakAllowance: Int = 1) throws -> NocturneGardenLevel {
        try NocturneGardenLevel(id: id, seed: 9, difficulty: difficulty, width: width, height: height,
                                target: target, forbidden: forbidden, supply: supply, sizes: sizes,
                                elevations: elevations, sun: sun, budget: budget,
                                required: required ?? NocturneGardenRatio(3, 4), leakAllowance: leakAllowance)
    }

    /// The reason codes are the stable `r02-g09.*` set.
    @Test func reasonCodesAreStable() {
        let errors: [NocturneGardenError] = [.level("x"), .action("x"), .supply, .noop, .stage, .stale,
                                             .newerSchema(2), .malformed("x")]
        let codes: [String] = errors.map(\.reasonCode)
        #expect(codes == ["r02-g09.level", "r02-g09.action", "r02-g09.supply", "r02-g09.noop", "r02-g09.stage",
                          "r02-g09.stale", "r02-g09.newer-schema", "r02-g09.malformed"])
    }

    /// Every range and rule is refused with its name.
    @Test func everyRangeIsRefusedByName() throws {
        #expect(throws: NocturneGardenError.level("id")) { try Self.level(id: "Bad Id") }
        #expect(throws: NocturneGardenError.level("id")) { try Self.level(id: "") }
        #expect(throws: NocturneGardenError.level("difficulty")) { try Self.level(difficulty: 0) }
        #expect(throws: NocturneGardenError.level("difficulty")) { try Self.level(difficulty: 6) }
        #expect(throws: NocturneGardenError.level("width")) { try Self.level(width: 15) }
        #expect(throws: NocturneGardenError.level("width")) { try Self.level(width: 33) }
        #expect(throws: NocturneGardenError.level("height")) { try Self.level(height: 11) }
        #expect(throws: NocturneGardenError.level("height")) { try Self.level(height: 25) }
        #expect(throws: NocturneGardenError.level("target")) { try Self.level(target: []) }
        #expect(throws: NocturneGardenError.level("target")) { try Self.level(target: [192]) }
        #expect(throws: NocturneGardenError.level("target")) { try Self.level(target: [-1]) }
        #expect(throws: NocturneGardenError.level("forbidden")) { try Self.level(forbidden: [3]) }
        #expect(throws: NocturneGardenError.level("forbidden")) { try Self.level(forbidden: [192]) }
        #expect(throws: NocturneGardenError.level("supply")) { try Self.level(supply: [:]) }
        #expect(throws: NocturneGardenError.level("supply")) { try Self.level(supply: [.fern: 0]) }
        #expect(throws: NocturneGardenError.level("supply")) { try Self.level(supply: [.fern: 13]) }
        #expect(throws: NocturneGardenError.level("supply")) { try Self.level(supply: [.fern: 2, .lily: -1]) }
        #expect(throws: NocturneGardenError.level("sizes")) { try Self.level(sizes: []) }
        #expect(throws: NocturneGardenError.level("sizes")) { try Self.level(sizes: [0, 1]) }
        #expect(throws: NocturneGardenError.level("sizes")) { try Self.level(sizes: [4]) }
        #expect(throws: NocturneGardenError.level("elevations")) { try Self.level(elevations: []) }
        #expect(throws: NocturneGardenError.level("elevations")) { try Self.level(elevations: [2, 5]) }
        #expect(throws: NocturneGardenError.level("sun")) { try Self.level(sun: 4) }
        #expect(throws: NocturneGardenError.level("budget")) { try Self.level(budget: 0) }
        #expect(throws: NocturneGardenError.level("budget")) { try Self.level(budget: 41) }
        #expect(throws: NocturneGardenError.level("leak")) { try Self.level(leakAllowance: -1) }
        #expect(throws: NocturneGardenError.level("match")) { try NocturneGardenRatio(0, 4) }
        #expect(throws: NocturneGardenError.level("match")) { try NocturneGardenRatio(5, 4) }
        #expect(throws: NocturneGardenError.level("match")) { try NocturneGardenRatio(1, 1_001) }
        let edges: NocturneGardenLevel = try Self.level(width: 32, height: 24, target: [767], forbidden: [],
                                                        supply: [.star: 12], budget: 40, leakAllowance: 0)
        #expect(edges.cellCount == 768)
        #expect(edges.supplyTotal == 12)
        let reduced: NocturneGardenRatio = try NocturneGardenRatio(6, 8)
        #expect(reduced.numerator == 3 && reduced.denominator == 4)
        #expect(try NocturneGardenRatio(7, 7) == .whole)
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        let level: NocturneGardenLevel = try Self.level(supply: [.tulip: 2, .rose: 1, .fern: 0])
        #expect(level.supply == [.tulip: 2, .rose: 1])
        let data: Data = level.encoded()
        #expect(try NocturneGardenLevel.decode(data) == level)
        #expect(try JSONDecoder().decode(NocturneGardenLevel.self, from: data) == level)
        #expect(try Self.level().fingerprint == level.fingerprint)
        #expect(try Self.level(budget: 7).fingerprint != level.fingerprint)
        let text: String = try #require(String(data: data, encoding: .utf8))
        func edited(_ old: String, _ new: String) -> Data { Data(text.replacingOccurrences(of: old, with: new).utf8) }
        #expect(text.contains("\"target\":[0,1,2,3]"))
        #expect(text.contains("\"supply\":{\"rose\":1,\"tulip\":2}"))
        #expect(throws: NocturneGardenError.malformed("fingerprint")) {
            try NocturneGardenLevel.decode(edited("\"budget\":6", "\"budget\":7"))
        }
        #expect(throws: NocturneGardenError.malformed("fingerprint")) {
            try NocturneGardenLevel.decode(edited("[0,1,2,3]", "[0,1,2]"))
        }
        #expect(throws: NocturneGardenError.newerSchema(2)) {
            try NocturneGardenLevel.decode(edited("\"schema\":1", "\"schema\":2"))
        }
        #expect(throws: NocturneGardenError.malformed("schema 0")) {
            try NocturneGardenLevel.decode(edited("\"schema\":1", "\"schema\":0"))
        }
        #expect(throws: NocturneGardenError.malformed("unreadable")) { try NocturneGardenLevel.decode(Data("{".utf8)) }
        #expect(throws: NocturneGardenError.malformed("unreadable")) {
            try NocturneGardenLevel.decode(edited("\"numerator\":3", "\"numerator\":5"))
        }
        #expect(throws: NocturneGardenError.malformed("r02-g09.level")) {
            try NocturneGardenLevel.decode(edited("\"budget\":6", "\"budget\":0"))
        }
        #expect(throws: NocturneGardenError.malformed("r02-g09.level")) {
            try NocturneGardenLevel.decode(edited("\"rose\"", "\"daisy\""))
        }
        let newer: Data = edited("\"schema\":1", "\"schema\":2")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(NocturneGardenLevel.self, from: newer) }
    }

    /// Actions encode with named operands and round-trip.
    @Test func actionsHaveAStableEncoding() throws {
        let actions: [NocturneGardenAction] = [.plant(.lily, 3, 0, 2), .move(1, 4, 5), .resize(0, 3), .remove(2),
                                               .sun(4)]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data = try encoder.encode(actions)
        let text: String = try #require(String(data: data, encoding: .utf8))
        let expected: String = "[{\"column\":3,\"kind\":\"lily\",\"op\":\"plant\",\"row\":0,\"size\":2},"
            + "{\"bloom\":1,\"column\":4,\"op\":\"move\",\"row\":5},{\"bloom\":0,\"op\":\"resize\",\"size\":3},"
            + "{\"bloom\":2,\"op\":\"remove\"},{\"elevation\":4,\"op\":\"sun\"}]"
        #expect(text == expected)
        #expect(try JSONDecoder().decode([NocturneGardenAction].self, from: data) == actions)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(NocturneGardenAction.self, from: Data("{\"op\":\"grow\"}".utf8))
        }
    }

    /// Blooms, regions and measures are named in words (FR-R02G0901-013).
    @Test func bloomsRegionsAndMeasuresAreNamedInWords() throws {
        let level: NocturneGardenLevel = try Self.level()
        let bloom = NocturneGardenBloom(kind: .tulip, column: 3, row: 0, size: 2)
        #expect(level.bloomName(0, bloom: bloom) == "bloom 1: tulip at column 3, row 0, size 2")
        let names: [String] = NocturneGardenKind.allCases.map(\.name)
        #expect(names == ["tulip", "bell", "star", "fern", "rose", "lily"])
        #expect(Set(NocturneGardenKind.allCases.map(\.shape)).count == 6)
        #expect(level.cellName(19) == "column 3, row 1")
        #expect(level.regionName(2) == "target")
        #expect(level.regionName(5) == "forbidden")
        #expect(level.regionName(6) == "open")
        #expect(level.matchText(shared: 12, either: 16) == "match 12/16, needs 3/4")
        #expect(level.leakText(1) == "leak 1 cell, 1 allowed")
        #expect(level.leakText(2) == "leak 2 cells, 1 allowed")
        #expect(NocturneGardenLevel.sunName(1) == "sun 1 of 4, high, shadows half as tall")
        #expect(NocturneGardenLevel.sunName(4) == "sun 4 of 4, low, shadows twice as tall")
        let expected: String = "target 4 cells; forbidden 2 cells; needs a match of 3/4 with a leak of at most 1 cell; "
            + "6 moves; 3 blooms: 2 tulip, 1 rose; sun 2 of 4, upper middle, shadows as tall as the blooms"
        #expect(level.targetDescription() == expected)
    }

    /// Whether the closed segments a–b and c–d share a point (exact integers).
    static func touches(_ a: NocturneGardenLattice, _ b: NocturneGardenLattice, _ c: NocturneGardenLattice,
                        _ d: NocturneGardenLattice) -> Bool {
        func orient(_ p: NocturneGardenLattice, _ q: NocturneGardenLattice, _ r: NocturneGardenLattice) -> Int {
            let v: Int = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
            return v > 0 ? 1 : (v < 0 ? -1 : 0)
        }
        func on(_ p: NocturneGardenLattice, _ q: NocturneGardenLattice, _ r: NocturneGardenLattice) -> Bool {
            min(p.x, q.x) <= r.x && r.x <= max(p.x, q.x) && min(p.y, q.y) <= r.y && r.y <= max(p.y, q.y)
        }
        let o1: Int = orient(a, b, c)
        let o2: Int = orient(a, b, d)
        let o3: Int = orient(c, d, a)
        let o4: Int = orient(c, d, b)
        if o1 != o2 && o3 != o4 { return true }
        if o1 == 0 && on(a, b, c) { return true }
        if o2 == 0 && on(a, b, d) { return true }
        if o3 == 0 && on(c, d, a) { return true }
        if o4 == 0 && on(c, d, b) { return true }
        return false
    }

    /// The six outlines are simple, counter-clockwise, start at the foot (0, 0), have at most 16 vertices and lie
    /// within x −1 … 2 and y 0 … 6; they are pairwise different.
    @Test func theSixOutlinesAreSimpleAndInBounds() {
        var seen: Set<[NocturneGardenLattice]> = []
        for kind in NocturneGardenKind.allCases {
            let outline: [NocturneGardenLattice] = kind.outline
            let n: Int = outline.count
            #expect(n >= 3 && n <= 16, "\(kind.name) vertices")
            #expect(outline.first == NocturneGardenLattice(x: 0, y: 0), "\(kind.name) foot")
            #expect(Set(outline).count == n, "\(kind.name) repeated vertex")
            var minY: Int = Int.max
            var doubleArea: Int = 0
            for i in 0..<n {
                let p: NocturneGardenLattice = outline[i]
                let q: NocturneGardenLattice = outline[(i + 1) % n]
                #expect((-1...2).contains(p.x) && (0...6).contains(p.y), "\(kind.name) bounds")
                minY = min(minY, p.y)
                doubleArea += p.x * q.y - q.x * p.y
            }
            #expect(minY == 0, "\(kind.name) foot on the bottom edge")
            #expect(doubleArea > 0, "\(kind.name) counter-clockwise")
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let a: NocturneGardenLattice = outline[i]
                    let b: NocturneGardenLattice = outline[(i + 1) % n]
                    let c: NocturneGardenLattice = outline[j]
                    let d: NocturneGardenLattice = outline[(j + 1) % n]
                    let adjacent: Bool = j == i + 1 || (i == 0 && j == n - 1)
                    if adjacent {
                        // Adjacent edges share one vertex and must not fold back over each other.
                        let shared: NocturneGardenLattice = j == i + 1 ? b : a
                        let p: NocturneGardenLattice = j == i + 1 ? a : b
                        let r: NocturneGardenLattice = j == i + 1 ? d : c
                        let cross: Int = (p.x - shared.x) * (r.y - shared.y) - (p.y - shared.y) * (r.x - shared.x)
                        let dot: Int = (p.x - shared.x) * (r.x - shared.x) + (p.y - shared.y) * (r.y - shared.y)
                        #expect(cross != 0 || dot < 0, "\(kind.name) fold at edge \(i)")
                    } else {
                        #expect(!Self.touches(a, b, c, d), "\(kind.name) edges \(i) and \(j) cross")
                    }
                }
            }
            seen.insert(outline)
        }
        #expect(seen.count == 6)
    }

    /// A unit square cast at each elevation: 1, 1, 2 and 2 cells (its top edge reaches the next row's centre at
    /// elevation 3).
    @Test func aUnitSquareCastsTheHandComputedCells() {
        let square: [NocturneGardenLattice] = [NocturneGardenLattice(x: 0, y: 0), NocturneGardenLattice(x: 1, y: 0),
                                               NocturneGardenLattice(x: 1, y: 1), NocturneGardenLattice(x: 0, y: 1)]
        let expected: [Set<Int>] = [[35], [35], [35, 51], [35, 51]]
        for elevation in 1...4 {
            let polygon: [NocturneGardenLattice] = NocturneGardenBloom.cast(square, column: 3, row: 2, size: 1,
                                                                            elevation: elevation)
            #expect(polygon[2] == NocturneGardenLattice(x: 8, y: 4 + elevation))
            #expect(NocturneGardenBloom.cells(of: polygon, width: 16, height: 12) == expected[elevation - 1])
        }
        let large: [NocturneGardenLattice] = NocturneGardenBloom.cast(square, column: 0, row: 0, size: 3, elevation: 4)
        var block: Set<Int> = []
        for row in 0...5 { for column in 0...2 { block.insert(row * 16 + column) } }
        #expect(NocturneGardenBloom.cells(of: large, width: 16, height: 12) == block)
        let clipped: [NocturneGardenLattice] = NocturneGardenBloom.cast(square, column: 15, row: 11, size: 3,
                                                                        elevation: 4)
        #expect(NocturneGardenBloom.cells(of: clipped, width: 16, height: 12) == [191])
    }

    /// A rose of size 1 at column 5, row 1 under sun 2 (factor 1) darkens its stem (2 cells) and a 3 × 4 head, the
    /// head's slanted edges passing exactly through the corner cells' centres.
    @Test func aRoseCastsTheHandComputedCells() {
        let rose = NocturneGardenBloom(kind: .rose, column: 5, row: 1, size: 1)
        var expected: Set<Int> = [1 * 16 + 5, 2 * 16 + 5]
        for row in 3...6 { for column in 4...6 { expected.insert(row * 16 + column) } }
        #expect(rose.cells(elevation: 2, width: 16, height: 12) == expected)
        let polygon: [NocturneGardenLattice] = rose.castPolygon(elevation: 2)
        #expect(polygon[3] == NocturneGardenLattice(x: 14, y: 8))
        #expect(NocturneGardenBloom.contains(polygon, NocturneGardenLattice(x: 13, y: 7)))
        #expect(!NocturneGardenBloom.contains(polygon, NocturneGardenLattice(x: 13, y: 5)))
        let low: Set<Int> = rose.cells(elevation: 4, width: 16, height: 12)
        #expect(low.count > expected.count)
        #expect(rose.cells(elevation: 2, width: 16, height: 12).isSubset(of: Set(0..<192)))
    }

    /// The canonical order of blooms is row, column, kind, size.
    @Test func bloomsSortCanonically() {
        let blooms: [NocturneGardenBloom] = [NocturneGardenBloom(kind: .lily, column: 2, row: 1, size: 1),
                                             NocturneGardenBloom(kind: .tulip, column: 9, row: 0, size: 3),
                                             NocturneGardenBloom(kind: .tulip, column: 2, row: 1, size: 2),
                                             NocturneGardenBloom(kind: .tulip, column: 2, row: 1, size: 1)]
        let sorted: [NocturneGardenBloom] = blooms.sorted()
        #expect(sorted == [blooms[1], blooms[3], blooms[2], blooms[0]])
    }

    /// The match is decided by cross multiplication (equal wins, one short does not, an empty union never matches),
    /// the leak counts forbidden dark cells, and the boundary deviation follows its stated values.
    @Test func matchLeakAndDeviationFollowTheirRules() throws {
        let mask = NocturneGardenMask(width: 16, height: 12, cells: [0, 1, 2, 4, 500])
        #expect(mask.cells == [0, 1, 2, 4])
        let target: Set<Int> = [0, 1, 2, 3]
        #expect(mask.intersection(target) == 3)
        #expect(mask.union(target) == 5)
        #expect(NocturneGardenMask.matches(mask: mask, target: target, required: try NocturneGardenRatio(3, 5)))
        #expect(!NocturneGardenMask.matches(mask: mask, target: target, required: try NocturneGardenRatio(61, 100)))
        let empty = NocturneGardenMask(width: 16, height: 12, cells: [])
        #expect(!NocturneGardenMask.matches(mask: empty, target: [], required: try NocturneGardenRatio(1, 1_000)))
        #expect(!NocturneGardenMask.matches(mask: empty, target: target, required: try NocturneGardenRatio(1, 1_000)))
        #expect(mask.leak(forbidden: [4, 5, 6]) == 1)
        #expect(NocturneGardenMask.boundaryDeviation([], [], width: 16, height: 12) == 0)
        #expect(NocturneGardenMask.boundaryDeviation(target, [], width: 16, height: 12) == 28)
        #expect(NocturneGardenMask.boundaryDeviation(target, target, width: 16, height: 12) == 0)
        #expect(NocturneGardenMask.boundaryDeviation([0], [3 * 16 + 5], width: 16, height: 12) == 5)
        var block: Set<Int> = []
        for row in 2...6 { for column in 2...6 { block.insert(row * 16 + column) } }
        #expect(NocturneGardenMask.boundary(block, width: 16, height: 12).count == 16)
        #expect(!NocturneGardenMask.boundary(block, width: 16, height: 12).contains(4 * 16 + 4))
        #expect(NocturneGardenMask.boundaryDeviation(block, [4 * 16 + 4], width: 16, height: 12) == 2)
    }

    /// 500 seeded fixtures are valid levels whose arrangement casts exactly the target, matches without leaking and is
    /// won only by its last plant.
    @Test func fiveHundredFixturesAreValidAndWinnable() throws {
        var sunActions: Int = 0
        var fractional: Int = 0
        for fixture in NocturneGardenFixtures.fixtures(500) {
            let level: NocturneGardenLevel = fixture.level
            #expect(try NocturneGardenLevel.decode(level.encoded()) == level)
            #expect(fixture.actions.count <= level.budget)
            var elevation: Int = level.sun
            var planted: [NocturneGardenBloom] = []
            var plants: [NocturneGardenKind: Int] = [:]
            for action in fixture.actions {
                switch action {
                case let .sun(value):
                    #expect(planted.isEmpty && value != level.sun && level.elevations.contains(value))
                    elevation = value
                    sunActions += 1
                case let .plant(kind, column, row, size):
                    #expect(level.sizes.contains(size))
                    #expect(column >= 0 && column < level.width && row >= 0 && row < level.height)
                    planted.append(NocturneGardenBloom(kind: kind, column: column, row: row, size: size))
                    plants[kind, default: 0] += 1
                    let mask: NocturneGardenMask = NocturneGardenMask.union(planted, elevation: elevation,
                                                                            width: level.width, height: level.height)
                    #expect(mask.leak(forbidden: level.forbidden) == 0)
                    let won: Bool = NocturneGardenMask.matches(mask: mask, target: level.target,
                                                               required: level.required)
                    #expect(won == (planted.count == fixture.blooms.count))
                default:
                    Issue.record("unexpected action \(action)")
                }
            }
            #expect(elevation == fixture.elevation)
            #expect(planted == fixture.blooms)
            for (kind, count) in plants { #expect(count <= level.supplyCount(kind)) }
            let final: NocturneGardenMask = NocturneGardenMask.union(planted, elevation: elevation, width: level.width,
                                                                     height: level.height)
            #expect(final.cells == level.target)
            #expect(NocturneGardenMask.boundaryDeviation(final.cells, level.target, width: level.width,
                                                         height: level.height) == 0)
            if level.required != .whole { fractional += 1 }
        }
        #expect(sunActions > 100)
        #expect(fractional > 100)
    }
}
