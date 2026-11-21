// ColorfallCanyonsLevelTests — feature 341 (R02-G05-01) T-R02G0501-002 (FR-R02G0501-001, 009, 011, 013;
// SC-R02G0501-005). The level's ranges and placement rules, its stored form (round trip, damage, edits, newer schema),
// the kinds, neighbours and carvability of cells, and the fixtures' validity and known solutions.
import Foundation
import XCTest
@testable import ColorfallCanyonsCore

final class ColorfallCanyonsLevelTests: XCTestCase {
    /// A small valid level whose values the refusal checks vary one at a time.
    private func make(columns: Int = 4, rows: Int = 4, heights: [Int]? = nil, grounds: [ColorfallCanyonsGround]? = nil,
                      springs: [ColorfallCanyonsSpring]? = nil, basins: [ColorfallCanyonsBasin]? = nil,
                      flowRate: Int = 2, budget: Int = 3, tickLimit: Int = 60,
                      difficulty: Int = 1, id: String = "small") throws(ColorfallCanyonsError) -> ColorfallCanyonsLevel {
        var g = [ColorfallCanyonsGround](repeating: .open, count: columns * rows)
        g[columns * rows - 1] = .drain
        return try ColorfallCanyonsLevel(
            id: id, seed: 1, difficulty: difficulty, columns: columns, rows: rows,
            heights: heights ?? [Int](repeating: 5, count: columns * rows), grounds: grounds ?? g,
            springs: springs ?? [ColorfallCanyonsSpring(cell: 0, color: .cyan, release: 1, supply: 10, open: true)],
            basins: basins ?? [ColorfallCanyonsBasin(cell: 5, capacity: 20, fill: 5, shares: [1_000, 0, 0],
                                                     tolerance: 0, isProtected: true, toleratedWrong: 0)],
            flowRate: flowRate, budget: budget, tickLimit: tickLimit)
    }

    private func refusal(_ body: () throws(ColorfallCanyonsError) -> ColorfallCanyonsLevel) -> String? {
        do {
            _ = try body()
            return nil
        } catch {
            if case .level(let name) = error { return name }
            return error.reasonCode
        }
    }

    func testEveryRangeAndPlacementRuleIsRefusedByName() throws {
        XCTAssertNoThrow(try make())
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(id: "Bad Id") }, "id")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(difficulty: 6) }, "difficulty")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(columns: 3) }, "columns")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(rows: 11) }, "rows")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(heights: [Int](repeating: 16, count: 16)) }, "heights")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(grounds: [ColorfallCanyonsGround](repeating: .open, count: 15)) }, "grounds")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(springs: []) }, "springs")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(springs: [ColorfallCanyonsSpring(cell: 0, color: .coral, release: 5, supply: 1, open: true)]) },
                       "spring")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(basins: []) }, "basins")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(basins: [ColorfallCanyonsBasin(cell: 5, capacity: 10, fill: 5, shares: [500, 400, 0],
                                                    tolerance: 0, isProtected: false, toleratedWrong: 0)]) }, "basin")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(basins: [ColorfallCanyonsBasin(cell: 0, capacity: 10, fill: 5, shares: [1_000, 0, 0],
                                                    tolerance: 0, isProtected: false, toleratedWrong: 0)]) },
                       "placement")
        var noDrain = [ColorfallCanyonsGround](repeating: .open, count: 16)
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(grounds: noDrain) }, "drain")
        noDrain[5] = .rock
        noDrain[15] = .drain
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(grounds: noDrain) }, "placement")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in
            try make(basins: [ColorfallCanyonsBasin(cell: 5, capacity: 10, fill: 0, shares: [1_000, 0, 0],
                                                    tolerance: 0, isProtected: false, toleratedWrong: 0)]) }, "target")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(flowRate: 9) }, "flow-rate")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(budget: 0) }, "budget")
        XCTAssertEqual(refusal { () throws(ColorfallCanyonsError) in try make(tickLimit: 3_601) }, "tick-limit")
        XCTAssertEqual(ColorfallCanyonsError.level("x").reasonCode, "r02-g05.level")
    }

    func testTheStoredFormRoundTripsAndRefusesDamageEditsAndNewerSchemas() throws {
        for index in 0..<50 {
            let level = ColorfallCanyonsFixtures.randomLevel(index, tutorial: index % 2 == 0)
            let data = level.encoded()
            XCTAssertEqual(try ColorfallCanyonsLevel.decode(data), level)
            XCTAssertEqual(try JSONDecoder().decode(ColorfallCanyonsLevel.self, from: data), level)
            XCTAssertEqual(level.encoded(), data, "canonical")
        }
        let level = ColorfallCanyonsFixtures.fixture(0).level
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: level.encoded()) as? [String: Any])
        json["flowRate"] = level.flowRate == 8 ? 7 : level.flowRate + 1
        let edited = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertThrowsError(try ColorfallCanyonsLevel.decode(edited)) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("fingerprint"))
        }
        json["schema"] = 2
        let newer = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertThrowsError(try ColorfallCanyonsLevel.decode(newer)) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .newerSchema(2))
        }
        XCTAssertThrowsError(try ColorfallCanyonsLevel.decode(Data("{".utf8))) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("unreadable"))
        }
        json["schema"] = 1
        json["budget"] = 0
        let broken = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertThrowsError(try ColorfallCanyonsLevel.decode(broken)) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("r02-g05.level"))
        }
    }

    func testKindsNeighboursAndCarvability() throws {
        let level = try make()
        XCTAssertEqual(level.kind(of: 0), .spring(0))
        XCTAssertEqual(level.kind(of: 5), .basin(0))
        XCTAssertEqual(level.kind(of: 15), .drain)
        XCTAssertEqual(level.kind(of: 1), .open)
        XCTAssertEqual(level.neighbours(of: 5), [6, 9, 4, 1], "east, south, west, north")
        XCTAssertEqual(level.neighbours(of: 0), [1, 4])
        XCTAssertEqual(level.neighbours(of: 15), [14, 11])
        XCTAssertTrue(level.isCarvable(1, heights: level.heights))
        XCTAssertFalse(level.isCarvable(0, heights: level.heights), "spring")
        XCTAssertFalse(level.isCarvable(5, heights: level.heights), "basin")
        XCTAssertFalse(level.isCarvable(15, heights: level.heights), "drain")
        var flat = level.heights
        flat[1] = 0
        XCTAssertFalse(level.isCarvable(1, heights: flat), "height 0")
        XCTAssertFalse(level.isCarvable(16, heights: level.heights), "outside")
    }

    func testColoursAndMixesHaveWords() throws {
        XCTAssertEqual(ColorfallCanyonsColor.allCases.map(\.name), ["cyan", "coral", "yellow"])
        let basin = ColorfallCanyonsBasin(cell: 5, capacity: 20, fill: 12, shares: [500, 500, 0], tolerance: 100,
                                          isProtected: true, toleratedWrong: 2)
        XCTAssertEqual(basin.description, "at least 12 units: cyan 500 ± 100 per mille, coral 500 ± 100 per mille, "
                       + "yellow none, protected (2 wrong units tolerated)")
        XCTAssertEqual(basin.wrongMass([3, 4, 5]), 5)
        XCTAssertTrue(basin.accepts([6, 6, 0]))
        XCTAssertTrue(basin.accepts([7, 5, 0]), "|7000 − 6000| = 1000 ≤ 100 · 12")
        XCTAssertFalse(basin.accepts([8, 5, 0]), "|8000 − 6500| = 1500 > 1300")
        XCTAssertFalse(basin.accepts([6, 5, 0]), "below the fill")
    }

    func testEveryFixtureIsValidAndItsKnownSolutionWins() throws {
        for index in 0..<500 {
            let fixture = ColorfallCanyonsFixtures.fixture(index)
            var play = ColorfallCanyonsPlay(level: fixture.level)
            try play.handle(.begin)
            for action in fixture.solution { try play.apply(action, expecting: play.fingerprint) }
            XCTAssertEqual(play.stage, .won, "fixture \(index)")
            XCTAssertTrue(play.fluid.isConserved())
        }
    }
}
