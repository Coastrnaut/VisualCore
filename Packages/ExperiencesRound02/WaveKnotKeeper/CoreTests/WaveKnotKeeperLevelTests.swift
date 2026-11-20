// WaveKnotKeeperLevelTests — feature 321 (R02-G03-01) T-R02G0301-002 (FR-R02G0301-001, 007, 009; SC-R02G0301-005;
// clarifications Q1, Q4, Q5). Host checks of the level: every range refusal with its name, the start rules (simple,
// not won, tension within the bound), gates and targets, the stored form (exact round trip, fingerprint, sorted keys) and
// the refusal of damaged, edited and newer stored forms; the reason codes. Fixtures seed 2_321. Explicit types, plain
// loops, short runs.
import Foundation
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperLevelTests {
    typealias Point = WaveKnotKeeperPoint

    /// A simple hexagon in the plane z = 0 with z lifted on alternate points (no projected crossing).
    static let hexagon: [Point] = [Point(x: 4, y: 0, z: 0), Point(x: 2, y: 4, z: 1), Point(x: -2, y: 4, z: 0),
                                   Point(x: -4, y: 0, z: 1), Point(x: -2, y: -4, z: 0), Point(x: 2, y: -4, z: 1)]

    static func level(points: [Point] = hexagon, gates: [WaveKnotKeeperGate] = [], crossings: Int = 2, writhe: Int = 0,
                      bound: Int = 10_000, allowance: Int = 10, id: String = "hex",
                      band: Int = 1) throws -> WaveKnotKeeperLevel {
        try WaveKnotKeeperLevel(id: id, seed: 2_321, band: band, points: points, gates: gates,
                                target: try WaveKnotKeeperTarget(crossings: crossings, writhe: writhe),
                                tensionBound: bound, allowance: allowance)
    }

    @Test func aValidLevelAndItsRangeRefusals() throws {
        let level: WaveKnotKeeperLevel = try Self.level()
        #expect(level.points == Self.hexagon && level.fingerprint.count == 64)
        #expect(throws: WaveKnotKeeperError.level("id")) { try Self.level(id: "Hex") }
        #expect(throws: WaveKnotKeeperError.level("band")) { try Self.level(band: 6) }
        #expect(throws: WaveKnotKeeperError.level("points")) { try Self.level(points: Array(Self.hexagon.prefix(5))) }
        var outside: [Point] = Self.hexagon
        outside[0] = Point(x: 17, y: 0, z: 0)
        #expect(throws: WaveKnotKeeperError.level("points")) { try Self.level(points: outside) }
        var repeated: [Point] = Self.hexagon
        repeated[3] = repeated[0]
        #expect(throws: WaveKnotKeeperError.level("points")) { try Self.level(points: repeated) }
        #expect(throws: WaveKnotKeeperError.level("tension-bound")) { try Self.level(bound: 0) }
        #expect(throws: WaveKnotKeeperError.level("allowance")) { try Self.level(allowance: 65) }
        let gate: WaveKnotKeeperGate = try WaveKnotKeeperGate(min: Point(x: 0, y: 0, z: 0), max: Point(x: 1, y: 1, z: 1))
        #expect(throws: WaveKnotKeeperError.level("gates")) {
            try Self.level(gates: [gate, gate, gate, gate, gate])
        }
        #expect(throws: WaveKnotKeeperError.level("gate")) {
            try WaveKnotKeeperGate(min: Point(x: 2, y: 0, z: 0), max: Point(x: 1, y: 1, z: 1))
        }
        #expect(throws: WaveKnotKeeperError.level("target")) { try WaveKnotKeeperTarget(crossings: 33, writhe: 1) }
        #expect(throws: WaveKnotKeeperError.level("target")) { try WaveKnotKeeperTarget(crossings: 2, writhe: 1) }
        #expect(throws: WaveKnotKeeperError.level("target")) { try WaveKnotKeeperTarget(crossings: 1, writhe: 3) }
        #expect(gate.contains(Point(x: 1, y: 0, z: 1)) && !gate.contains(Point(x: 2, y: 0, z: 0)))
    }

    @Test func theStartMustBeSimpleUnwonAndWithinTheBound() throws {
        // The hexagon has no projected crossing: a target of 0 crossings is already won.
        #expect(throws: WaveKnotKeeperError.level("won-at-start")) { try Self.level(crossings: 0) }
        let tension: Int = WaveKnotKeeperGeometry.tension(Self.hexagon)
        #expect(throws: WaveKnotKeeperError.level("tension-at-start")) { try Self.level(bound: tension - 1) }
        #expect(try Self.level(bound: tension).tensionBound == tension)
        // A bow tie whose two long segments meet in space passes through itself.
        let bowTie: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 4, z: 0), Point(x: 6, y: 4, z: 0),
                               Point(x: 6, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 0, y: 4, z: 0)]
        #expect(throws: WaveKnotKeeperError.level("self-intersecting")) { try Self.level(points: bowTie) }
        // Lifting one crossing strand makes it simple, with one projected crossing.
        var lifted: [Point] = bowTie
        lifted[1] = Point(x: 4, y: 4, z: 2)
        lifted[2] = Point(x: 6, y: 4, z: 2)
        let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(lifted)
        #expect(summary.crossings == 1 && !summary.degenerate)
        #expect(throws: WaveKnotKeeperError.level("won-at-start")) {
            try Self.level(points: lifted, crossings: 1, writhe: summary.writhe)
        }
        // A rope that folds back on itself (three collinear points, the outer two on one side) is not simple.
        let folded: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 2, y: 0, z: 0),
                               Point(x: 2, y: 3, z: 0), Point(x: 0, y: 5, z: 1), Point(x: -2, y: 2, z: 1)]
        #expect(throws: WaveKnotKeeperError.level("self-intersecting")) { try Self.level(points: folded) }
    }

    @Test func storedLevelsRoundTripExactly() throws {
        for index in 0..<40 {
            let level: WaveKnotKeeperLevel = WaveKnotKeeperFixtures.fixture(index, gates: index % 3 == 0).level
            let data: Data = level.encoded()
            let decoded: WaveKnotKeeperLevel = try WaveKnotKeeperLevel.decode(data)
            #expect(decoded == level && decoded.encoded() == data)
            let viaCodable: WaveKnotKeeperLevel = try JSONDecoder().decode(WaveKnotKeeperLevel.self, from: data)
            #expect(viaCodable == level)
            let text: String = try #require(String(data: data, encoding: .utf8))
            #expect(text.hasPrefix("{\"allowance\":"))
        }
    }

    @Test func damagedEditedAndNewerFormsAreRefused() throws {
        let level: WaveKnotKeeperLevel = WaveKnotKeeperFixtures.fixture(1).level
        let text: String = try #require(String(data: level.encoded(), encoding: .utf8))
        #expect(throws: WaveKnotKeeperError.malformed("unreadable")) {
            try WaveKnotKeeperLevel.decode(Data(text.dropLast(3).utf8))
        }
        #expect(throws: WaveKnotKeeperError.newerSchema(2)) {
            try WaveKnotKeeperLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
        #expect(throws: WaveKnotKeeperError.malformed("schema 0")) {
            try WaveKnotKeeperLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8))
        }
        let edited: String = text.replacingOccurrences(of: "\"allowance\":\(level.allowance)",
                                                       with: "\"allowance\":\(level.allowance == 64 ? 63 : level.allowance + 1)")
        #expect(edited != text)
        #expect(throws: WaveKnotKeeperError.malformed("fingerprint")) { try WaveKnotKeeperLevel.decode(Data(edited.utf8)) }
        let outOfRange: String = text.replacingOccurrences(of: "\"band\":\(level.band)", with: "\"band\":9")
        #expect(throws: WaveKnotKeeperError.malformed("r02-g03.level")) {
            try WaveKnotKeeperLevel.decode(Data(outOfRange.utf8))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(WaveKnotKeeperLevel.self, from: Data(edited.utf8))
        }
    }

    @Test func everyFixtureIsWonByItsKnownSolution() throws {
        for index in 0..<100 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 4 == 0)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            for move in fixture.solution where play.stage == .playing {
                try play.apply(move, expecting: play.fingerprint)
            }
            #expect(play.stage == .won, "fixture \(index)")
            #expect(play.spent <= fixture.level.allowance)
        }
    }

    @Test func reasonCodesAreStable() {
        let errors: [WaveKnotKeeperError] = [.level("x"), .move("x"), .stage, .stale, .allowance, .newerSchema(2),
                                             .malformed("x")]
        let codes: [String] = ["r02-g03.level", "r02-g03.move", "r02-g03.stage", "r02-g03.stale", "r02-g03.allowance",
                               "r02-g03.newer-schema", "r02-g03.malformed"]
        for index in errors.indices { #expect(errors[index].reasonCode == codes[index]) }
    }
}
