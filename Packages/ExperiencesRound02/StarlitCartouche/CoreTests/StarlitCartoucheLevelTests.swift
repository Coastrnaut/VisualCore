// StarlitCartoucheLevelTests — feature 451 (R02-G16-01) T-R02G1601-002 (FR-R02G1601-001, 009, 013, 014;
// SC-R02G1601-001, 005). The level's checks, names and stored form: every fixture is a valid level whose known legs fly
// to a win through the chart; each bound of clarification Q5 is refused with its name; levels round-trip byte for byte,
// and damaged, edited and newer stored forms are refused; stars, corridors and progress are named in words.
import Foundation
import Testing
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheLevelTests {
    /// A small hand level: four stars in a row on still orbits, corridors 0–1, 1–2, 2–3, symbol 0–1 and 1–2, beacon 2.
    static func handLevel(hazards: [StarlitCartoucheHazard] = [], budget: Int = 4,
                          deadline: Int = 20) throws -> StarlitCartoucheLevel {
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<4 {
            stars.append(StarlitCartoucheStar(orbit: [StarlitCartoucheVector(i * 2, 0, 0)],
                                              glyph: StarlitCartoucheGlyphPoint(i, 0), open: 0, close: deadline))
        }
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 2),
                                                     StarlitCartoucheCorridor(2, 3, travel: 1)]
        return try StarlitCartoucheLevel(id: "hand", seed: 1, difficulty: 1, stars: stars, range: 2,
                                         corridors: corridors, hazards: hazards, start: 0, beacon: 2,
                                         deadline: deadline, symbol: [0, 1], budget: budget)
    }

    /// Every fixture's known legs fly through the chart without a failure and end matched on the last leg.
    @Test func fixturesWinThroughTheChart() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 200)
        for fixture in fixtures {
            let level: StarlitCartoucheLevel = fixture.level
            var star: Int = level.start
            var beat: Int = 0
            var drawn: Set<Int> = []
            var legs: [StarlitCartoucheLeg] = []
            for (index, action) in fixture.actions.enumerated() {
                guard case .leg(let destination, let wait) = action else { continue }
                let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: star, at: beat,
                                                                             to: destination, wait: wait)
                #expect(StarlitCartoucheChart.check(level, leg: leg) == nil, "\(level.id) leg \(index)")
                star = leg.to
                beat = leg.arrive
                drawn.insert(leg.corridor)
                legs.append(leg)
                let report = StarlitCartoucheChart.report(level, star: star, beat: beat, drawn: drawn, legs: legs)
                #expect(report.matched == (index == fixture.actions.count - 1) || report.matched,
                        "\(level.id) leg \(index)")
            }
            let final = StarlitCartoucheChart.report(level, star: star, beat: beat, drawn: drawn, legs: legs)
            #expect(final.matched, "\(level.id)")
            #expect(final.mismatch == 0)
            #expect(!level.startReport.matched, "\(level.id) is not solved at load")
        }
    }

    /// Each bound is refused with its name.
    @Test func boundsAreRefusedByName() throws {
        let good: StarlitCartoucheLevel = try Self.handLevel()
        func refusal(_ make: () throws -> StarlitCartoucheLevel) -> String? {
            do {
                _ = try make()
                return nil
            } catch {
                if case .level(let name)? = error as? StarlitCartoucheError { return name }
                return "other"
            }
        }
        let s = good.stars
        let c = good.corridors
        #expect(refusal { try StarlitCartoucheLevel(id: "Bad", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "id")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 6, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "difficulty")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: Array(s.prefix(3)),
                                                   range: 2, corridors: [], hazards: [], start: 0, beacon: 2,
                                                   deadline: 20, symbol: [0], budget: 4) } == "stars")
        var repeated = s
        repeated[1] = StarlitCartoucheStar(orbit: s[1].orbit, glyph: s[0].glyph, open: 0, close: 20)
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: repeated, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "glyph repeated")
        var far = s
        far[0] = StarlitCartoucheStar(orbit: [StarlitCartoucheVector(9, 0, 0)], glyph: s[0].glyph, open: 0, close: 20)
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: far, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "position")
        var late = s
        late[0] = StarlitCartoucheStar(orbit: s[0].orbit, glyph: s[0].glyph, open: 1, close: 20)
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: late, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "start")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 13,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "range")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c + [StarlitCartoucheCorridor(1, 0, travel: 2)],
                                                   hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 4) } == "corridor repeated")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: [StarlitCartoucheCorridor(0, 1, travel: 4)],
                                                   hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0], budget: 4) } == "travel")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c,
                                                   hazards: [StarlitCartoucheHazard(corridor: 0, from: 3, to: 2)],
                                                   start: 0, beacon: 2, deadline: 20, symbol: [0, 1],
                                                   budget: 4) } == "hazard interval")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [], budget: 4) } == "symbol")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [1, 0], budget: 4) } == "symbol")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 20,
                                                   symbol: [0, 1], budget: 17) } == "budget")
        #expect(refusal { try StarlitCartoucheLevel(id: "a", seed: 1, difficulty: 1, stars: s, range: 2,
                                                   corridors: c, hazards: [], start: 0, beacon: 2, deadline: 65,
                                                   symbol: [0, 1], budget: 4) } == "deadline")
    }

    /// Levels round-trip byte for byte; damaged, edited and newer forms are refused.
    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 100)
        for fixture in fixtures {
            let data: Data = fixture.level.encoded()
            let decoded: StarlitCartoucheLevel = try StarlitCartoucheLevel.decode(data)
            #expect(decoded == fixture.level)
            #expect(decoded.encoded() == data)
        }
        let level: StarlitCartoucheLevel = try Self.handLevel()
        let text: String = try #require(String(data: level.encoded(), encoding: .utf8))
        #expect(throws: StarlitCartoucheError.malformed("unreadable")) {
            try StarlitCartoucheLevel.decode(Data("{".utf8))
        }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: StarlitCartoucheError.newerSchema(2)) { try StarlitCartoucheLevel.decode(Data(newer.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"budget\":4", with: "\"budget\":5")
        #expect(throws: StarlitCartoucheError.malformed("fingerprint")) {
            try StarlitCartoucheLevel.decode(Data(edited.utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"budget\":4", with: "\"budget\":40")
        #expect(throws: StarlitCartoucheError.malformed("r02-g16.level")) {
            try StarlitCartoucheLevel.decode(Data(broken.utf8))
        }
    }

    /// Stars, corridors and progress are named in words; the start report is exact.
    @Test func namesAndStartReport() throws {
        let level: StarlitCartoucheLevel = try Self.handLevel()
        #expect(level.starName(3) == "star 3")
        #expect(level.corridorName(1) == "the corridor between star 1 and star 2")
        let report: StarlitCartoucheRouteReport = level.startReport
        #expect(report.star == 0 && report.beat == 0 && report.drawn.isEmpty)
        #expect(report.missing == [0, 1] && report.stray.isEmpty && report.mismatch == 2)
        #expect(report.clearance == nil && !report.matched)
        #expect(level.progressDescription(report: report, actionsLeft: 4)
            == "at star 0, beat 0; 0 of 2 strokes drawn; 20 beats to the deadline; 4 actions left")
    }
}
