// MyceliumArchitectLevelTests — feature 511 (R02-G22-01) T-R02G2201-002 (FR-R02G2201-001 … 006, 010, 012, 014;
// SC-R02G2201-001, 004, 005). Ranges, every level refusal, the stored form, the field, hand cases of scoring, ties,
// corner cutting, branching and the judge, the fixtures and the words. Explicit types, plain loops.
import Foundation
import XCTest
@testable import MyceliumArchitectCore

final class MyceliumArchitectLevelTests: XCTestCase {
    typealias Cell = MyceliumArchitectCell
    typealias Direction = MyceliumArchitectDirection

    /// A small hand level: a 9 × 5 board, root (1, 2), one terminal; the rest as given (probe: may already win).
    static func hand(terminals: [Cell] = [Cell(column: 7, row: 2)], rocks: [Cell] = [], toxins: [Cell] = [],
                     fixed: [Cell] = [], strength: Int = 1, reach: Int = 4, curvature: Int = 1, obstacle: Int = 0,
                     startSeeds: [Direction] = [], pulses: Int = 16, nutrientBudget: Int = 4094,
                     weightLimit: Int = 4094, width: Int = 9, height: Int = 5) throws -> MyceliumArchitectLevel {
        try MyceliumArchitectLevel(id: "hand", seed: 1, difficulty: 1, width: width, height: height,
                                   root: Cell(column: 1, row: 2), terminals: terminals, rocks: rocks, toxins: toxins,
                                   fixedNutrients: fixed, strength: strength, reach: reach, curvature: curvature,
                                   obstacle: obstacle, maxNutrients: 3, maxBlockers: 3, maxSeeds: 4,
                                   startSeeds: startSeeds, pulses: pulses, nutrientBudget: nutrientBudget,
                                   weightLimit: weightLimit, budget: 8, tutorial: false, refusingAWin: false)
    }

    static func arrangement(nutrients: [Cell] = [], blockers: [Cell] = [],
                            seeds: [Direction]) -> MyceliumArchitectArrangement {
        MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
    }

    // MARK: Lattice and field

    func testDirectionsTurnsAndOffsets() {
        XCTAssertEqual(Direction.allCases.map { $0.offset.column }, [0, 1, 1, 1, 0, -1, -1, -1])
        XCTAssertEqual(Direction.allCases.map { $0.offset.row }, [-1, -1, 0, 1, 1, 1, 0, -1])
        XCTAssertEqual(Direction.north.turn(to: .south), 4)
        XCTAssertEqual(Direction.northWest.turn(to: .northEast), 2)
        XCTAssertEqual(Direction.west.turn(to: .north), 2)
        XCTAssertEqual(Direction.west.quarterClockwise, .north)
        XCTAssertEqual(Direction.northWest.quarterClockwise, .northEast)
        XCTAssertEqual(MyceliumArchitectGrowth.weight(.east), 2)
        XCTAssertEqual(MyceliumArchitectGrowth.weight(.southEast), 3)
        XCTAssertFalse(Cell(column: 0, row: 1) < Cell(column: 5, row: 0))
        XCTAssertTrue(Cell(column: 5, row: 0) < Cell(column: 0, row: 1))
    }

    func testTheFieldIsATentOfWholeNumbers() throws {
        let level = try Self.hand(strength: 3, reach: 4)
        let field = MyceliumArchitectGrowth.field(level, nutrients: [Cell(column: 4, row: 2)])
        XCTAssertEqual(field[2][4], 12)
        XCTAssertEqual(field[2][5], 9)
        XCTAssertEqual(field[0][6], 6)
        XCTAssertEqual(field[2][0], 0)
        let two = MyceliumArchitectGrowth.field(level, nutrients: [Cell(column: 4, row: 2), Cell(column: 6, row: 2)])
        XCTAssertEqual(two[2][5], 9 + 9)
    }

    // MARK: Growth hand cases

    func testATipGrowsStraightOnAFlatFieldUntilTheBoardEnds() throws {
        let level = try Self.hand(pulses: 20)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertEqual(report.grown.map { $0.column }, [1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(report.totalWeight, 14)
        XCTAssertEqual(report.terminalPulses, [6])
        XCTAssertEqual(report.terminalPathWeights, [12])
        XCTAssertNil(report.failure)
        XCTAssertEqual(report.pulsesRun, 8, "the tip goes dormant at the edge in pulse 8")
    }

    func testTiesGoToTheSmallerTurnThenTheLowerDirection() throws {
        // Heading north on a flat field with curvature 0: every admissible score is 0; the smaller turn (north) wins.
        let level = try Self.hand(curvature: 0, pulses: 1)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: [.north]))
        XCTAssertEqual(report.steps.first?.direction, .north)
        // A rock straight ahead: north-east and north-west tie at turn 1; the lower number (north-east) wins.
        let blocked = try Self.hand(rocks: [Cell(column: 1, row: 1)], curvature: 0, pulses: 1)
        let second = MyceliumArchitectGrowth.report(blocked, arrangement: Self.arrangement(seeds: [.north]))
        XCTAssertEqual(second.steps.first?.direction, .northEast)
    }

    func testACornerBetweenTwoObstaclesCannotBeCut() throws {
        let level = try Self.hand(rocks: [Cell(column: 2, row: 2), Cell(column: 1, row: 1), Cell(column: 0, row: 2),
                                          Cell(column: 1, row: 3)], curvature: 0, pulses: 1)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertTrue(report.steps.isEmpty, "every diagonal passes between two rocks; the tip goes dormant")
        XCTAssertEqual(report.nodeCount, 1)
    }

    func testANegativeBestScoreMakesATipDormant() throws {
        // A nutrient behind the root, heading east, curvature 8: west scores 8 − 32, east −8, the diagonals −16,
        // north and south −16; the best is −8, so the tip goes dormant without a step.
        let level = try Self.hand(fixed: [Cell(column: 0, row: 2)], strength: 8, reach: 8, curvature: 8, pulses: 4)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertTrue(report.steps.isEmpty)
        XCTAssertEqual(report.pulsesRun, 1)
    }

    func testANutrientIsConsumedAndBranchesAQuarterTurnClockwise() throws {
        let level = try Self.hand(strength: 2, reach: 6, curvature: 0, pulses: 3)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(
            nutrients: [Cell(column: 2, row: 2)], seeds: [.east]))
        let first = try XCTUnwrap(report.steps.first)
        XCTAssertTrue(first.consumed)
        XCTAssertEqual(first.newTip, 1)
        XCTAssertEqual(first.to, Cell(column: 2, row: 2))
        let born = report.steps.filter { $0.tip == 1 }
        XCTAssertEqual(born.first?.pulse, 2, "a tip born in pulse 1 first moves in pulse 2")
        XCTAssertEqual(born.first?.direction, .south, "heading south (east + 2); a flat field keeps the heading")
    }

    func testTheJudgeOrder() throws {
        // Toxic: the tip grows east into a toxin at (4, 2).
        let toxic = try Self.hand(toxins: [Cell(column: 4, row: 2)], pulses: 10)
        let t = MyceliumArchitectGrowth.report(toxic, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertEqual(t.failure, .toxic(pulse: 3, tip: 0, cell: Cell(column: 4, row: 2)))
        // Starved before toxic: a budget of 5 stops the third step (weight 6) before it reaches the toxin.
        let starved = try Self.hand(toxins: [Cell(column: 4, row: 2)], pulses: 10, nutrientBudget: 5, weightLimit: 5)
        let s = MyceliumArchitectGrowth.report(starved, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertEqual(s.failure, .starved(pulse: 3, tip: 0, cell: Cell(column: 4, row: 2), weight: 6, budget: 5))
        XCTAssertEqual(s.totalWeight, 4, "nothing is grown on a starved step")
        // Budget exactly at the weight: allowed.
        let exact = try Self.hand(terminals: [Cell(column: 4, row: 2)], pulses: 3, nutrientBudget: 6,
                                  weightLimit: 6)
        XCTAssertNil(MyceliumArchitectGrowth.report(exact, arrangement: Self.arrangement(seeds: [.east])).failure)
        // Unreached: a terminal one cell beyond the network.
        let beyond = try Self.hand(terminals: [Cell(column: 5, row: 2)], pulses: 3)
        XCTAssertEqual(MyceliumArchitectGrowth.report(beyond, arrangement: Self.arrangement(seeds: [.east])).failure,
                       .unreached(terminal: 0))
        // Overweight: limit one below the grown weight.
        let heavy = try Self.hand(terminals: [Cell(column: 4, row: 2)], pulses: 3, weightLimit: 5)
        XCTAssertEqual(MyceliumArchitectGrowth.report(heavy, arrangement: Self.arrangement(seeds: [.east])).failure,
                       .overweight(weight: 6, limit: 5))
    }

    // MARK: Level refusals

    func testEveryLevelRefusal() throws {
        func refusal(_ make: () throws -> MyceliumArchitectLevel) -> String? {
            do { _ = try make(); return nil } catch let error as MyceliumArchitectError {
                if case let .level(name) = error { return name }
                return error.reasonCode
            } catch { return "\(error)" }
        }
        func level(id: String = "a", width: Int = 9, height: Int = 5, root: Cell = Cell(column: 1, row: 2),
                   terminals: [Cell] = [Cell(column: 7, row: 2)], rocks: [Cell] = [], toxins: [Cell] = [],
                   fixed: [Cell] = [], strength: Int = 1, reach: Int = 4, curvature: Int = 1, obstacle: Int = 0,
                   maxNutrients: Int = 1, maxBlockers: Int = 1, maxSeeds: Int = 2, startSeeds: [Direction] = [],
                   pulses: Int = 8, nutrientBudget: Int = 40, weightLimit: Int = 40,
                   budget: Int = 4, difficulty: Int = 1) -> () throws -> MyceliumArchitectLevel {
            {
                try MyceliumArchitectLevel(id: id, seed: 0, difficulty: difficulty, width: width, height: height,
                                           root: root, terminals: terminals, rocks: rocks, toxins: toxins,
                                           fixedNutrients: fixed, strength: strength, reach: reach,
                                           curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients,
                                           maxBlockers: maxBlockers, maxSeeds: maxSeeds, startSeeds: startSeeds,
                                           pulses: pulses, nutrientBudget: nutrientBudget, weightLimit: weightLimit,
                                           budget: budget, tutorial: false)
            }
        }
        XCTAssertNil(refusal(level()))
        XCTAssertEqual(refusal(level(id: "Bad")), "id")
        XCTAssertEqual(refusal(level(difficulty: 6)), "difficulty")
        XCTAssertEqual(refusal(level(width: 3)), "width")
        XCTAssertEqual(refusal(level(height: 33)), "height")
        XCTAssertEqual(refusal(level(root: Cell(column: 9, row: 0))), "root")
        XCTAssertEqual(refusal(level(terminals: [])), "terminal count")
        XCTAssertEqual(refusal(level(terminals: [Cell(column: -1, row: 0)])), "terminal")
        XCTAssertEqual(refusal(level(rocks: [Cell(column: 0, row: 5)])), "rock")
        XCTAssertEqual(refusal(level(toxins: [Cell(column: 9, row: 4)])), "toxin")
        let nine = (0..<9).map { Cell(column: $0, row: 0) }
        XCTAssertEqual(refusal(level(fixed: nine)), "fixed nutrient count")
        XCTAssertEqual(refusal(level(rocks: [Cell(column: 7, row: 2)])), "shared cell")
        XCTAssertEqual(refusal(level(strength: 9)), "strength")
        XCTAssertEqual(refusal(level(reach: 0)), "reach")
        XCTAssertEqual(refusal(level(curvature: 9)), "curvature")
        XCTAssertEqual(refusal(level(obstacle: -1)), "obstacle")
        XCTAssertEqual(refusal(level(maxNutrients: 7)), "max nutrients")
        XCTAssertEqual(refusal(level(maxBlockers: 7)), "max blockers")
        XCTAssertEqual(refusal(level(maxSeeds: 0)), "max seeds")
        XCTAssertEqual(refusal(level(maxSeeds: 1, startSeeds: [.east, .west])), "start seeds")
        XCTAssertEqual(refusal(level(startSeeds: [.east, .east])), "start seeds")
        XCTAssertEqual(refusal(level(pulses: 129)), "pulses")
        XCTAssertEqual(refusal(level(nutrientBudget: 4095)), "nutrient budget")
        XCTAssertEqual(refusal(level(weightLimit: 41)), "weight limit")
        XCTAssertEqual(refusal(level(budget: 25)), "budget")
        XCTAssertEqual(refusal(level(maxNutrients: 0, maxBlockers: 0, maxSeeds: 1, startSeeds: [.east])),
                       "nothing placeable")
        XCTAssertEqual(refusal(level(maxSeeds: 2, startSeeds: [.east])), "already won")
    }

    // MARK: Stored form

    func testTheStoredFormRoundTripsAndRefusesDamage() throws {
        let fixtures = MyceliumArchitectFixture.all(count: 20)
        for fixture in fixtures {
            let data = fixture.level.encoded()
            XCTAssertEqual(try MyceliumArchitectLevel.decode(data), fixture.level)
            XCTAssertEqual(try JSONDecoder().decode(MyceliumArchitectLevel.self, from: data), fixture.level)
        }
        let level = fixtures[0].level
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: level.encoded()) as? [String: Any])
        json["pulses"] = (json["pulses"] as? Int ?? 1) % 128 + 1
        let edited = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertEqual(Self.code { try MyceliumArchitectLevel.decode(edited) }, "r02-g22.malformed")
        json["schema"] = 2
        let newer = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertEqual(Self.code { try MyceliumArchitectLevel.decode(newer) }, "r02-g22.newer-schema")
        json["schema"] = 1
        json["strength"] = 99
        let invalid = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertEqual(Self.code { try MyceliumArchitectLevel.decode(invalid) }, "r02-g22.level")
        XCTAssertEqual(Self.code { try MyceliumArchitectLevel.decode(Data("{".utf8)) }, "r02-g22.malformed")
        json["schema"] = 0
        let older = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertEqual(Self.code { try MyceliumArchitectLevel.decode(older) }, "r02-g22.malformed")
        let text = String(decoding: level.encoded(), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("{\"budget\":"), "sorted keys")
    }

    static func code(_ body: () throws -> MyceliumArchitectLevel) -> String? {
        do { _ = try body(); return nil } catch let error as MyceliumArchitectError { return error.reasonCode } catch {
            return "\(error)"
        }
    }

    // MARK: Fixtures and words

    func testFixturesWinWithTheirKnownArrangementAndNotAtTheStart() {
        for fixture in MyceliumArchitectFixture.all(count: 100) {
            XCTAssertTrue(MyceliumArchitectGrowth.report(fixture.level, arrangement: fixture.winning).wins)
            XCTAssertFalse(fixture.level.startReport.wins)
            XCTAssertLessThanOrEqual(fixture.actions.count - 1, fixture.level.budget)
        }
    }

    func testWords() throws {
        let level = try Self.hand(pulses: 20)
        let arrangement = Self.arrangement(seeds: [.east])
        let report = MyceliumArchitectGrowth.report(level, arrangement: arrangement)
        XCTAssertEqual(level.stepDescription(report.steps[0]), "tip 1 at pulse 1: east to (2, 2), score 0")
        XCTAssertEqual(level.terminalDescription(0, report: report), "terminal 1 reached at pulse 6, path weight 12")
        XCTAssertEqual(level.cellDescription(Cell(column: 7, row: 2), arrangement: arrangement, report: report),
                       "(7, 2): nutrient value 0, terminal 1, grown at pulse 6")
        XCTAssertEqual(level.failureDescription(.toxic(pulse: 9, tip: 2, cell: Cell(column: 5, row: 6))),
                       "tip 3 grew into toxin at (5, 6) on pulse 9")
        XCTAssertEqual(level.failureDescription(.overweight(weight: 1_234, limit: 1_000)),
                       "the network's branch weight 1 234 is above the limit of 1 000")
        XCTAssertEqual(level.progressDescription(report: report, actionsLeft: 1),
                       "branch weight 14 of 4 094, budget 4 094; 1 of 1 terminals reached; running now would win; "
                           + "1 action left")
        XCTAssertEqual(Direction.northWest.words, "north-west")
        XCTAssertEqual(MyceliumArchitectError.newerSchema(2).reasonCode, "r02-g22.newer-schema")
    }
}
