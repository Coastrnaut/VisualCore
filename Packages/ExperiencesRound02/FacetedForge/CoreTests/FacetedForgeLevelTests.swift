// FacetedForgeLevelTests — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-001, 009, 013, 014; SC-R02G0801-005;
// clarifications Q1, Q5). Levels: the direction names, the cube's corners, faces and volume, every range refusal, the
// stored form's round trip with its fingerprint, damaged, edited and newer forms refused, names in words, and the 500
// seeded fixtures valid with closed crystals. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import FacetedForgeCore

struct FacetedForgeLevelTests {
    /// A cube −a … a.
    static func cube(_ a: Int) -> [FacetedForgeHalfSpace] {
        (FacetedForgeFixtures.slab(0, -a, a) + FacetedForgeFixtures.slab(1, -a, a)
            + FacetedForgeFixtures.slab(2, -a, a))
            .sorted()
    }

    /// Two halves of the 2-cube.
    static func halves() throws -> [FacetedForgeTargetPiece] {
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        return [FacetedForgeTargetPiece(share: half, faces: 6), FacetedForgeTargetPiece(share: half, faces: 6)]
    }

    /// A valid level with the given overrides.
    static func level(planes: [FacetedForgeHalfSpace] = cube(2), budget: Int = 2, sliver: FacetedForgeFraction? = nil,
                      target: [FacetedForgeTargetPiece]? = nil, id: String = "cube-two",
                      difficulty: Int = 1) throws -> FacetedForgeLevel {
        try FacetedForgeLevel(id: id, seed: 7, difficulty: difficulty, planes: planes, budget: budget,
                              sliver: sliver ?? FacetedForgeFraction(1, 16), target: target ?? halves())
    }

    /// The 13 directions are named in words and distinct.
    @Test func directionsAreNamedAndDistinct() {
        let names: [String] = FacetedForgeDirection.all.map(\.name)
        #expect(names == ["x", "y", "z", "x+y", "x−y", "x+z", "x−z", "y+z", "y−z", "x+y+z", "x+y−z", "x−y+z", "−x+y+z"])
        #expect(Set(names).count == 13)
    }

    /// The cube −2 … 2 has 8 integer corners, 6 square faces and volume 64; every edge lies on two faces.
    @Test func theCubeHasItsCornersFacesAndVolume() throws {
        let cube: FacetedForgePiece = try FacetedForgePiece(halfSpaces: Self.cube(2))
        #expect(cube.corners.count == 8)
        #expect(cube.faceCount == 6)
        #expect(cube.faces.allSatisfy { $0.corners.count == 4 })
        #expect(cube.volume == (try FacetedForgeFraction(64)))
        #expect(cube.edges.count == 12)
        #expect(cube.edgeIncidence.allSatisfy { $0 == 2 })
    }

    /// Every range and rule is refused with its name.
    @Test func everyRangeIsRefusedByName() throws {
        let third: FacetedForgeFraction = try FacetedForgeFraction(1, 3)
        let two: FacetedForgeFraction = try FacetedForgeFraction(2, 3)
        #expect(throws: FacetedForgeError.level("id")) { try Self.level(id: "Bad Id") }
        #expect(throws: FacetedForgeError.level("difficulty")) { try Self.level(difficulty: 6) }
        #expect(throws: FacetedForgeError.level("planes")) { try Self.level(planes: Array(Self.cube(2).prefix(3))) }
        #expect(throws: FacetedForgeError.level("order")) { try Self.level(planes: Self.cube(2).reversed()) }
        #expect(throws: FacetedForgeError.level("box")) { try Self.level(planes: Self.cube(7)) }
        let open: [FacetedForgeHalfSpace] = Array(Self.cube(2).dropLast())
        // An unbounded crystal (one plane missing) bounds fewer than four faces: refused as empty before the closed
        // check.
        #expect(throws: FacetedForgeError.level("empty")) { try Self.level(planes: open) }
        let flat: [FacetedForgeHalfSpace] = (FacetedForgeFixtures.slab(0, 0, 0) + FacetedForgeFixtures.slab(1, -2, 2)
                                             + FacetedForgeFixtures.slab(2, -2, 2)).sorted()
        #expect(throws: FacetedForgeError.level("empty")) { try Self.level(planes: flat) }
        #expect(throws: FacetedForgeError.level("budget")) { try Self.level(budget: 0) }
        #expect(throws: FacetedForgeError.level("budget")) { try Self.level(budget: 21) }
        #expect(throws: FacetedForgeError.level("sliver")) { try Self.level(sliver: FacetedForgeFraction(1, 2)) }
        #expect(throws: FacetedForgeError.level("sliver")) { try Self.level(sliver: .zero) }
        #expect(throws: FacetedForgeError.level("target")) {
            try Self.level(target: [FacetedForgeTargetPiece(share: .one, faces: 6)])
        }
        #expect(throws: FacetedForgeError.level("target")) { try Self.level(budget: 1, target: [
            FacetedForgeTargetPiece(share: third, faces: 6), FacetedForgeTargetPiece(share: third, faces: 6),
            FacetedForgeTargetPiece(share: third, faces: 6)]) }
        #expect(throws: FacetedForgeError.level("faces")) { try Self.level(target: [
            FacetedForgeTargetPiece(share: two, faces: 35), FacetedForgeTargetPiece(share: third, faces: 6)]) }
        #expect(throws: FacetedForgeError.level("shares")) { try Self.level(target: [
            FacetedForgeTargetPiece(share: two, faces: 6), FacetedForgeTargetPiece(share: two, faces: 6)]) }
        #expect(throws: FacetedForgeError.level("order")) { try Self.level(target: [
            FacetedForgeTargetPiece(share: third, faces: 6), FacetedForgeTargetPiece(share: two, faces: 6)]) }
        #expect(throws: FacetedForgeError.level("plane")) {
            try Self.level(planes: (Self.cube(2) + [FacetedForgeHalfSpace(direction: 13, sign: 1, depth: 0)]).sorted())
        }
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        let level: FacetedForgeLevel = try Self.level()
        let data: Data = level.encoded()
        #expect(try FacetedForgeLevel.decode(data) == level)
        #expect(try JSONDecoder().decode(FacetedForgeLevel.self, from: data) == level)
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(throws: FacetedForgeError.malformed("fingerprint")) {
            try FacetedForgeLevel.decode(Data(text.replacingOccurrences(of: "\"budget\":2", with: "\"budget\":3").utf8))
        }
        #expect(throws: FacetedForgeError.newerSchema(2)) {
            try FacetedForgeLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
        #expect(throws: FacetedForgeError.malformed("unreadable")) { try FacetedForgeLevel.decode(Data("{".utf8)) }
        #expect(throws: FacetedForgeError.malformed("r02-g08.level")) {
            try FacetedForgeLevel.decode(Data(text.replacingOccurrences(of: "\"budget\":2", with: "\"budget\":0").utf8))
        }
    }

    /// Pieces and the target are named in words (FR-R02G0801-013).
    @Test func piecesAndTargetAreNamedInWords() throws {
        let level: FacetedForgeLevel = try Self.level()
        #expect(level.pieceName(0, share: try FacetedForgeFraction(1, 4), faces: 6)
                == "piece 1: a quarter of the crystal, 6 faces")
        let expected: String = "2 pieces: a half of the crystal with 6 faces; a half of the crystal with 6 faces"
        #expect(level.targetDescription() == expected)
        #expect(FacetedForgeLevel.shareText(try FacetedForgeFraction(3, 16)) == "3/16")
    }

    /// 500 seeded fixtures are valid levels with closed crystals whose shares sum to one and replay their cuts.
    @Test func fiveHundredFixturesAreValid() throws {
        for fixture in FacetedForgeFixtures.fixtures(500) {
            let level: FacetedForgeLevel = fixture.level
            #expect(level.crystal.edgeIncidence.allSatisfy { $0 == 2 })
            #expect(try FacetedForgeLevel.decode(level.encoded()) == level)
            var pieces: [FacetedForgePiece] = [level.crystal]
            for action in fixture.actions {
                guard case let .cut(index, direction, depth) = action else { continue }
                let halves = try pieces[index].cut(direction: direction, depth: depth)
                #expect(try halves.below.volume.adding(halves.above.volume) == pieces[index].volume)
                pieces.remove(at: index)
                pieces = FacetedForgePiece.canonical(pieces + [halves.below, halves.above])
            }
            var total: FacetedForgeFraction = .zero
            for piece in pieces {
                total = try total.adding(piece.volume)
                #expect(piece.edgeIncidence.allSatisfy { $0 == 2 })
            }
            #expect(total == level.crystal.volume)
            #expect(pieces.count == level.target.count)
        }
    }
}
