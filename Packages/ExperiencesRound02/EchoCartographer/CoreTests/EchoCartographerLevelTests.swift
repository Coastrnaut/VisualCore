// EchoCartographerLevelTests — feature 401 (R02-G11-01) T-R02G1101-002 (FR-R02G1101-001, 002, 003, 004, 009, 011, 013;
// SC-R02G1101-001, 005; clarifications Q1, Q2, Q3, Q5). Levels and the exact chamber: the reason codes, every range
// refusal, the stored form's round trip with its fingerprint, damaged, edited and newer forms refused, names in words,
// hand-computed rays, path lengths and echoes on the hand chamber, the claim rule (nearest unlocated beacon within the
// tolerance; already located; miss), the knowledge's growth, and the 500 seeded fixtures valid with known actions.
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import EchoCartographerCore

struct EchoCartographerLevelTests {
    static func cell(_ x: Int, _ y: Int) -> EchoCartographerCell { EchoCartographerCell(x: x, y: y) }

    /// A valid level on the hand chamber with the given overrides.
    static func level(id: String = "echo-one", difficulty: Int = 1, entry: EchoCartographerCell = cell(0, 0),
                      beacons: [EchoCartographerCell] = [cell(2, 2), cell(6, 0)], tolerance: Int = 1,
                      energy: Int = 6, missCost: Int = 2) throws -> EchoCartographerLevel {
        let hand: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        return try EchoCartographerLevel(id: id, seed: 9, difficulty: difficulty, chamber: hand.chamber, entry: entry,
                                         beacons: beacons, tolerance: tolerance, energy: energy, missCost: missCost)
    }

    /// The reason codes are the stable `r02-g11.*` set.
    @Test func reasonCodesAreStable() {
        let errors: [EchoCartographerError] = [.level("x"), .action("x"), .noop, .stage, .stale, .newerSchema(2),
                                               .malformed("x")]
        let codes: [String] = errors.map(\.reasonCode)
        #expect(codes == ["r02-g11.level", "r02-g11.action", "r02-g11.noop", "r02-g11.stage", "r02-g11.stale",
                          "r02-g11.newer-schema", "r02-g11.malformed"])
    }

    /// Every range and rule is refused with its name.
    @Test func everyRangeIsRefusedByName() throws {
        #expect(throws: EchoCartographerError.level("size")) { try EchoCartographerChamber(width: 4, height: 8, walls: []) }
        #expect(throws: EchoCartographerError.level("size")) { try EchoCartographerChamber(width: 8, height: 17, walls: []) }
        #expect(throws: EchoCartographerError.level("walls")) { try EchoCartographerChamber(width: 5, height: 5, walls: [25]) }
        #expect(throws: EchoCartographerError.level("walls")) { try EchoCartographerChamber(width: 5, height: 5, walls: [-1]) }
        #expect(throws: EchoCartographerError.level("id")) { try Self.level(id: "Echo") }
        #expect(throws: EchoCartographerError.level("id")) { try Self.level(id: "echo--one") }
        #expect(throws: EchoCartographerError.level("difficulty")) { try Self.level(difficulty: 0) }
        #expect(throws: EchoCartographerError.level("difficulty")) { try Self.level(difficulty: 6) }
        #expect(throws: EchoCartographerError.level("entry")) { try Self.level(entry: Self.cell(3, 0)) }
        #expect(throws: EchoCartographerError.level("entry")) { try Self.level(entry: Self.cell(7, 0)) }
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: []) }
        let five: [EchoCartographerCell] = [Self.cell(2, 2), Self.cell(6, 0), Self.cell(6, 4), Self.cell(0, 4),
                                            Self.cell(4, 4)]
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: five) }
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: [Self.cell(2, 2), Self.cell(2, 2)]) }
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: [Self.cell(1, 1)]) }
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: [Self.cell(0, 0)]) }
        #expect(throws: EchoCartographerError.level("beacons")) { try Self.level(beacons: [Self.cell(9, 9)]) }
        #expect(throws: EchoCartographerError.level("tolerance")) { try Self.level(tolerance: -1) }
        #expect(throws: EchoCartographerError.level("tolerance")) { try Self.level(tolerance: 3) }
        #expect(throws: EchoCartographerError.level("energy")) { try Self.level(energy: 0) }
        #expect(throws: EchoCartographerError.level("energy")) { try Self.level(energy: 61) }
        #expect(throws: EchoCartographerError.level("miss")) { try Self.level(missCost: 0) }
        #expect(throws: EchoCartographerError.level("miss")) { try Self.level(missCost: 4) }
        // A beacon on an open cell that is cut off from the entry is unreachable.
        let sealed = try EchoCartographerChamber(width: 5, height: 5, walls: [1, 5, 6, 7, 2])
        #expect(throws: EchoCartographerError.level("beacons")) {
            try EchoCartographerLevel(id: "sealed", seed: 1, difficulty: 1, chamber: sealed, entry: Self.cell(0, 0),
                                      beacons: [Self.cell(4, 4)], tolerance: 0, energy: 3, missCost: 1)
        }
    }

    /// The hand chamber's rays from the entry: north and west reach the border at 1, east strikes the wall at
    /// (3, 0) after crossing (1, 0) and (2, 0), south crosses rows 1 … 4 and reaches the border at 5.
    @Test func handRaysAreExact() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let echo: EchoCartographerEcho = level.echo(from: Self.cell(0, 0))
        var directions: [EchoCartographerDirection] = []
        var distances: [Int] = []
        for ray in echo.rays {
            directions.append(ray.direction)
            distances.append(ray.distance)
        }
        #expect(directions == [.north, .east, .south, .west])
        #expect(distances == [1, 3, 5, 1])
        #expect(echo.rays[0].wall == nil && echo.rays[0].open.isEmpty)
        #expect(echo.rays[1].wall == Self.cell(3, 0))
        #expect(echo.rays[1].open == [Self.cell(1, 0), Self.cell(2, 0)])
        #expect(echo.rays[2].wall == nil)
        #expect(echo.rays[2].open == [Self.cell(0, 1), Self.cell(0, 2), Self.cell(0, 3), Self.cell(0, 4)])
        #expect(echo.rays[1].delay == 72)
        // The beacons' path lengths: (2, 2) at 4 steps, (6, 0) at 10 (through the middle, not round the bottom).
        #expect(echo.beaconDistances == [4, 10])
        #expect(echo.beaconDelays == [96, 240])
        // From (6, 4): (6, 0) at 4 steps; (2, 2) at 6 (along row 4, up column 4, then left along row 2).
        #expect(level.echo(from: Self.cell(6, 4)).beaconDistances == [4, 6])
        // A beacon on the emitter answers at 0.
        #expect(level.echo(from: Self.cell(2, 2)).beaconDistances == [0, 6])
    }

    /// Path lengths: walls and unreachable cells have none; a wall emitter reaches nothing.
    @Test func pathLengthsAreExact() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let chamber: EchoCartographerChamber = level.chamber
        let lengths: [Int?] = chamber.pathLengths(from: Self.cell(0, 0))
        #expect(lengths[chamber.index(Self.cell(0, 0))] == 0)
        #expect(lengths[chamber.index(Self.cell(3, 0))] == nil)
        #expect(lengths[chamber.index(Self.cell(6, 4))] == 10)
        #expect(lengths[chamber.index(Self.cell(4, 0))] == 8)
        let none: [Int?] = chamber.pathLengths(from: Self.cell(1, 1))
        #expect(none.allSatisfy { $0 == nil })
        let sealed = try EchoCartographerChamber(width: 5, height: 5, walls: [1, 5, 6])
        #expect(sealed.pathLengths(from: Self.cell(0, 0))[24] == nil)
    }

    /// The claim rule: nearest unlocated beacon within the tolerance, ties by row then column; a claim near only
    /// located beacons is a no-op; otherwise a miss; the tolerance boundary is inclusive. The hand level's beacons in
    /// cell-index order are (6, 0) (index 0) and (2, 2) (index 1).
    @Test func claimRuleIsExact() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel(tolerance: 1)
        #expect(level.beacons == [Self.cell(6, 0), Self.cell(2, 2)])
        #expect(level.claim(Self.cell(2, 2), located: []) == .hit(1))
        #expect(level.claim(Self.cell(3, 3), located: []) == .hit(1))
        #expect(level.claim(Self.cell(4, 4), located: []) == .miss)
        #expect(level.claim(Self.cell(5, 1), located: []) == .hit(0))
        #expect(level.claim(Self.cell(2, 2), located: [1]) == .alreadyLocated)
        #expect(level.claim(Self.cell(5, 1), located: [0]) == .alreadyLocated)
        let wide: EchoCartographerLevel = try Self.level(beacons: [Self.cell(2, 2), Self.cell(4, 2)], tolerance: 2)
        // (3, 2) is at 1 from both: the lower row wins, then the lower column: (2, 2).
        #expect(wide.claim(Self.cell(3, 2), located: []) == .hit(0))
        #expect(wide.claim(Self.cell(3, 2), located: [0]) == .hit(1))
        // (4, 4) is at 2 from both: the tie goes to the lower column, (2, 2); (6, 4) reaches only (4, 2); (6, 0) none.
        #expect(wide.claim(Self.cell(4, 4), located: []) == .hit(0))
        #expect(wide.claim(Self.cell(6, 4), located: []) == .hit(1))
        #expect(wide.claim(Self.cell(6, 0), located: []) == .hit(1))
        #expect(wide.claim(Self.cell(0, 4), located: []) == .hit(0))
        #expect(wide.claim(Self.cell(0, 0), located: []) == .hit(0))
        #expect(wide.claim(Self.cell(6, 1), located: [1]) == .alreadyLocated)
        #expect(wide.claim(Self.cell(6, 4), located: [1]) == .alreadyLocated)
        #expect(wide.claim(Self.cell(6, 0), located: [0]) == .hit(1))
        let exact: EchoCartographerLevel = EchoCartographerFixtures.handLevel(tolerance: 0)
        #expect(exact.claim(Self.cell(2, 2), located: []) == .hit(1))
        #expect(exact.claim(Self.cell(2, 1), located: []) == .miss)
    }

    /// The knowledge starts with only the entry open and grows by the echoes and located beacons.
    @Test func knowledgeGrows() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var knowledge: EchoCartographerKnowledge = level.openingKnowledge
        #expect(knowledge.revealed.open == 1 && knowledge.revealed.wall == 0)
        #expect(knowledge[Self.cell(0, 0)] == .open)
        #expect(knowledge[Self.cell(-1, 0)] == .wall)
        knowledge.reveal(level.echo(from: Self.cell(0, 0)))
        #expect(knowledge.revealed.open == 7 && knowledge.revealed.wall == 1)
        #expect(knowledge[Self.cell(3, 0)] == .wall)
        #expect(knowledge[Self.cell(2, 2)] == .unknown)
        knowledge.markOpen(Self.cell(2, 2))
        #expect(knowledge[Self.cell(2, 2)] == .open)
    }

    /// Names in words (FR-R02G1101-013).
    @Test func namesAreWords() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var knowledge: EchoCartographerKnowledge = level.openingKnowledge
        let echo: EchoCartographerEcho = level.echo(from: Self.cell(0, 0))
        knowledge.reveal(echo)
        #expect(level.cellName(Self.cell(0, 0), knowledge: knowledge) == "column 0, row 0: open")
        #expect(level.cellName(Self.cell(3, 0), knowledge: knowledge) == "column 3, row 0: wall")
        #expect(level.cellName(Self.cell(2, 2), knowledge: knowledge) == "column 2, row 2: unknown")
        #expect(level.echoDescription(echo) == "pulse from column 0, row 0; north: edge at 1 cell; "
                + "east: wall at 3 cells; south: edge at 5 cells; west: edge at 1 cell; echoes at 4, 10 cells")
        #expect(level.progressDescription(located: 1, energy: 7) == "1 of 2 beacons located, 7 energy left")
        #expect(level.levelDescription() == "chamber 7 by 5; entry at column 0, row 0; 2 beacons; tolerance 1 cell; "
                + "6 energy; a miss costs 2")
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let data: Data = level.encoded()
        #expect(try EchoCartographerLevel.decode(data) == level)
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"beacons\":[16,6],") == false, "beacons sorted by index")
        #expect(text.contains("\"beacons\":[6,16]"))
        let decoded: EchoCartographerLevel = try JSONDecoder().decode(EchoCartographerLevel.self, from: data)
        #expect(decoded == level)
        #expect(throws: EchoCartographerError.malformed("unreadable")) { try EchoCartographerLevel.decode(Data("{".utf8)) }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: EchoCartographerError.newerSchema(2)) { try EchoCartographerLevel.decode(Data(newer.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"energy\":6", with: "\"energy\":7")
        #expect(throws: EchoCartographerError.malformed("fingerprint")) {
            try EchoCartographerLevel.decode(Data(edited.utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"tolerance\":1", with: "\"tolerance\":5")
        #expect(throws: EchoCartographerError.malformed("r02-g11.level")) {
            try EchoCartographerLevel.decode(Data(broken.utf8))
        }
        let missing: String = text.replacingOccurrences(of: "\"missCost\":2,", with: "")
        #expect(throws: EchoCartographerError.malformed("unreadable")) {
            try EchoCartographerLevel.decode(Data(missing.utf8))
        }
    }

    /// The 500 seeded fixtures are valid levels whose known actions are one pulse from the entry and one claim on each
    /// beacon's own cell (a hit at distance 0), within the energy; each round-trips.
    @Test func fixturesAreValid() throws {
        let fixtures: [EchoCartographerFixture] = EchoCartographerFixtures.fixtures(500)
        for fixture in fixtures {
            let level: EchoCartographerLevel = fixture.level
            #expect(fixture.pulses == [level.entry])
            #expect(fixture.claims == level.beacons)
            #expect(level.energy >= fixture.pulses.count)
            var located: Set<Int> = []
            for claim in fixture.claims {
                let result: EchoCartographerClaimResult = level.claim(claim, located: located)
                guard case let .hit(index) = result else {
                    Issue.record("fixture \(level.seed): claim \(claim) is \(result)")
                    break
                }
                #expect(level.beacons[index] == claim)
                located.insert(index)
            }
            #expect(located.count == level.beacons.count)
            #expect(try EchoCartographerLevel.decode(level.encoded()) == level)
        }
    }
}
