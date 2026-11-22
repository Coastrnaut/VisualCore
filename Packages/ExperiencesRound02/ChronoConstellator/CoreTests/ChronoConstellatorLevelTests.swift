// ChronoConstellatorLevelTests — feature 351 (R02-G06-01) T-R02G0601-002 (FR-R02G0601-001, 009, 011, 013; SC-R02G0601-005;
// clarifications Q1, Q5). Levels: every range and rule refused by name; loops closed, distinct and 4-connected;
// targets on their loops and pairwise distinct; the stored form round-trips with sorted keys and a stable fingerprint;
// damaged, edited, older-than-1 and newer forms are refused; reason codes `r02-g06.*`; stars described in words, number
// and shape; the fixtures' known timelines win at their win tick. Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorLevelTests {
    /// A valid two-star level on a 6 × 5 grid.
    static func sample(stars: [ChronoConstellatorStar]? = nil, columns: Int = 6, rows: Int = 5, budget: Int = 3,
                       tickLimit: Int = 100, id: String = "sample") throws(ChronoConstellatorError) -> ChronoConstellatorLevel {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: columns)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 3, row: 1, width: 3, height: 3, columns: columns)
        let defaults: [ChronoConstellatorStar] = [ChronoConstellatorStar(loop: a, phase: 0, target: a[2]),
                                                  ChronoConstellatorStar(loop: b, phase: 1, target: b[5])]
        return try ChronoConstellatorLevel(id: id, seed: 7, difficulty: 2, columns: columns, rows: rows,
                                           stars: stars ?? defaults, budget: budget, tickLimit: tickLimit)
    }

    /// The reason a level built by `make` is refused with, or nil when it is accepted.
    static func refusal(_ make: () throws(ChronoConstellatorError) -> ChronoConstellatorLevel) -> ChronoConstellatorError? {
        do {
            _ = try make()
            return nil
        } catch {
            return error
        }
    }

    @Test func aValidLevelIsAcceptedWithItsFields() throws {
        let level: ChronoConstellatorLevel = try Self.sample()
        #expect(level.cellCount == 30)
        #expect(level.stars.count == 2)
        #expect(level.stars[0].length == 4)
        #expect(level.stars[1].length == 8)
        #expect(level.fingerprint.count == 64)
        #expect(ChronoConstellatorLevel.tickSeconds == 1.0 / 120.0)
    }

    @Test func everyRangeIsRefusedByName() throws {
        let good: ChronoConstellatorLevel = try Self.sample()
        let stars: [ChronoConstellatorStar] = good.stars
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(id: "Bad Id") } == .level("id"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try ChronoConstellatorLevel(id: "x", seed: 0, difficulty: 6, columns: 6, rows: 5, stars: stars, budget: 3,
                                        tickLimit: 10) } == .level("difficulty"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(columns: 4) } == .level("columns"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(columns: 13) } == .level("columns"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(rows: 4) } == .level("rows"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(rows: 11) } == .level("rows"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: [stars[0]]) } == .level("stars"))
        let six: [ChronoConstellatorStar] = [stars[0], stars[1], stars[0], stars[1], stars[0], stars[1]]
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: six) } == .level("stars"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(budget: 0) } == .level("budget"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(budget: 21) } == .level("budget"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(tickLimit: 0) } == .level("tick-limit"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(tickLimit: 1_201) }
                == .level("tick-limit"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(budget: 20, tickLimit: 1_200) } == nil)
    }

    @Test func brokenLoopsPhasesAndTargetsAreRefused() throws {
        let good: ChronoConstellatorLevel = try Self.sample()
        let b: ChronoConstellatorStar = good.stars[1]
        let loops: [[Int]] = [[0, 1, 7], // too short
                              [0, 1, 7, 6, 0], // a repeated cell
                              [0, 1, 2, 8, 7, 6], // the last cell is not a neighbour of the first? (6 is below 0: it is)
                              [0, 1, 8, 6], // 1 → 8 is diagonal
                              [5, 6, 12, 11], // 5 → 6 wraps a row edge
                              [0, 1, 31, 30]] // 31 is outside the grid
        var refused: [ChronoConstellatorError?] = []
        for loop in loops {
            let star = ChronoConstellatorStar(loop: loop, phase: 0, target: loop[0])
            refused.append(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: [star, b]) })
        }
        #expect(refused[0] == .level("loop"))
        #expect(refused[1] == .level("loop"))
        #expect(refused[2] == nil, "a 2 × 3 rectangle is a valid loop")
        #expect(refused[3] == .level("loop"))
        #expect(refused[4] == .level("loop"))
        #expect(refused[5] == .level("loop"))
        let long: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 12, height: 6, columns: 12)
        #expect(long.count == 32)
        let longStar = ChronoConstellatorStar(loop: long, phase: 0, target: long[3])
        let far: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 7, width: 2, height: 2, columns: 12)
        let farStar = ChronoConstellatorStar(loop: far, phase: 0, target: far[0])
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try Self.sample(stars: [longStar, farStar], columns: 12, rows: 10) } == nil, "a loop of 32 cells is accepted")
        let a: ChronoConstellatorStar = good.stars[0]
        let badPhase = ChronoConstellatorStar(loop: a.loop, phase: 4, target: a.target)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: [badPhase, b]) }
                == .level("phase"))
        let offLoop = ChronoConstellatorStar(loop: a.loop, phase: 0, target: 29)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: [offLoop, b]) }
                == .level("target"))
        let sameTarget = ChronoConstellatorStar(loop: a.loop, phase: 1, target: a.target)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try Self.sample(stars: [a, sameTarget]) }
                == .level("targets"))
    }

    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        for index in 0..<40 {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.fixture(index).level
            let data: Data = level.encoded()
            #expect(try ChronoConstellatorLevel.decode(data) == level)
            #expect(level.encoded() == data, "encoding is stable")
            let viaCodable: ChronoConstellatorLevel = try JSONDecoder().decode(ChronoConstellatorLevel.self,
                                                                               from: try JSONEncoder().encode(level))
            #expect(viaCodable == level)
            let text: String = String(decoding: data, as: UTF8.self)
            let edited: String = text.replacingOccurrences(of: "\"budget\":\(level.budget)",
                                                           with: "\"budget\":\(level.budget == 20 ? 19 : level.budget + 1)")
            #expect(throws: ChronoConstellatorError.malformed("fingerprint")) {
                _ = try ChronoConstellatorLevel.decode(Data(edited.utf8))
            }
        }
        let level: ChronoConstellatorLevel = try Self.sample()
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        #expect(throws: ChronoConstellatorError.newerSchema(2)) {
            _ = try ChronoConstellatorLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
        #expect(throws: ChronoConstellatorError.malformed("schema 0")) {
            _ = try ChronoConstellatorLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8))
        }
        #expect(throws: ChronoConstellatorError.malformed("unreadable")) {
            _ = try ChronoConstellatorLevel.decode(Data("{".utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"tickLimit\":100", with: "\"tickLimit\":0")
        #expect(throws: ChronoConstellatorError.malformed("r02-g06.level")) {
            _ = try ChronoConstellatorLevel.decode(Data(broken.utf8))
        }
    }

    @Test func reasonCodesAreStable() {
        let cases: [(ChronoConstellatorError, String)] = [(.level("x"), "r02-g06.level"), (.action("x"), "r02-g06.action"),
                                                          (.stage, "r02-g06.stage"), (.stale, "r02-g06.stale"),
                                                          (.budget, "r02-g06.budget"),
                                                          (.newerSchema(2), "r02-g06.newer-schema"),
                                                          (.malformed("x"), "r02-g06.malformed")]
        for (error, code) in cases { #expect(error.reasonCode == code) }
    }

    @Test func starsAreDescribedInWordsNumbersAndShapes() throws {
        let level: ChronoConstellatorLevel = try Self.sample()
        #expect(level.description(ofStar: 0) == "star 1 (ring): loop of 4 cells, target row 2, column 2")
        #expect(level.description(ofStar: 1).hasPrefix("star 2 (cross): loop of 8 cells, target row "))
        let names: [String] = ChronoConstellatorShape.allCases.map(\.name)
        #expect(names == ["ring", "cross", "diamond", "triangle", "square"])
        #expect(Set(names).count == 5)
    }

    @Test func fixturesWinExactlyAtTheirWinTick() {
        for index in 0..<200 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(index)
            let level: ChronoConstellatorLevel = fixture.level
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.winningTimeline(fixture)
            #expect(timeline.editsInUse(level: level) <= level.budget)
            var first: Int? = nil
            for tick in 1...level.tickLimit {
                let verdict = ChronoConstellatorEvaluation.verdict(positions: timeline.positions(at: tick, level: level),
                                                                   tick: tick, level: level)
                if verdict != .running {
                    #expect(verdict == .won, "\(level.id) tick \(tick)")
                    first = tick
                    break
                }
            }
            #expect(first == fixture.winTick, "\(level.id)")
            let defaults = ChronoConstellatorTimeline(level: level)
            #expect(defaults.positions(at: fixture.winTick, level: level) != level.stars.map(\.target),
                    "\(level.id): the default timeline does not align at the win tick")
        }
    }
}
