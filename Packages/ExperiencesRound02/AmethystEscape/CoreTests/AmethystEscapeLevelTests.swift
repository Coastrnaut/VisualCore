// AmethystEscapeLevelTests — feature 361 (R02-G07-01) T-R02G0701-002 (FR-R02G0701-001, 009, 011, 013; SC-R02G0701-005;
// clarifications Q1, Q5). Level ranges and rules, names in words, the stored form's round trip and its refusals of damaged,
// edited and newer forms, the reason codes, and the fixtures' known solutions.
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeLevelTests {
    /// A valid two-shell level of 8 sectors used by the refusal checks.
    static func base(sectors: Int = 8, shells: [AmethystEscapeShell]? = nil, start: Int = 0,
                     budget: Int = 10) throws -> AmethystEscapeLevel {
        let defaultShells = [AmethystEscapeShell(apertures: [2, 5], walls: [6], blocked: [4]),
                             AmethystEscapeShell(apertures: [3], walls: [], blocked: [7])]
        return try AmethystEscapeLevel(id: "base", seed: 1, difficulty: 1, sectors: sectors,
                                       shells: shells ?? defaultShells, start: start, budget: budget)
    }

    /// The reason payload of a level refusal, or nil.
    static func refusal(_ make: () throws -> AmethystEscapeLevel) -> String? {
        do {
            _ = try make()
            return nil
        } catch let error as AmethystEscapeError {
            if case let .level(name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    @Test func aValidLevelHasItsExitGapAndNames() throws {
        let level = try Self.base()
        #expect(level.outermost == 1)
        #expect(level.exitGap == 3)
        #expect(level.shellName(0) == "shell 1 (inner)")
        #expect(level.shellName(1) == "shell 2 (outer)")
        #expect(level.sectorName(0) == "sector 1 of 8")
        #expect(level.description(ofShell: 0) == "shell 1 (inner): openings at sectors 3, 6; walls after sectors 7; blocked sectors 5")
        #expect(level.description(ofShell: 1) == "shell 2 (outer): exit gap at sector 4; walls after sectors none; blocked sectors 8")
        #expect(level.fingerprint.count == 64)
    }

    @Test func everyRangeAndRuleIsRefusedByName() throws {
        let open = AmethystEscapeShell(apertures: [0])
        #expect(Self.refusal { try AmethystEscapeLevel(id: "Bad", seed: 1, difficulty: 1, sectors: 8, shells: [open, open], start: 1, budget: 5) } == "id")
        #expect(Self.refusal { try AmethystEscapeLevel(id: "a", seed: 1, difficulty: 0, sectors: 8, shells: [open, open], start: 1, budget: 5) } == "difficulty")
        #expect(Self.refusal { try Self.base(sectors: 5, shells: [open, open]) } == "sectors")
        #expect(Self.refusal { try Self.base(sectors: 13, shells: [open, open]) } == "sectors")
        #expect(Self.refusal { try Self.base(shells: [open]) } == "shells")
        #expect(Self.refusal { try Self.base(shells: Array(repeating: open, count: 6)) } == "shells")
        let noAperture = AmethystEscapeShell(apertures: [])
        #expect(Self.refusal { try Self.base(shells: [noAperture, open]) } == "apertures")
        #expect(Self.refusal { try Self.base(shells: [AmethystEscapeShell(apertures: [8]), open]) } == "apertures")
        let twoExits = AmethystEscapeShell(apertures: [0, 1])
        #expect(Self.refusal { try Self.base(shells: [open, twoExits]) } == "exit")
        let fullWalls = AmethystEscapeShell(apertures: [0], walls: Array(0..<8))
        #expect(Self.refusal { try Self.base(shells: [fullWalls, open]) } == "walls")
        let allBlocked = AmethystEscapeShell(apertures: [0], blocked: Array(0..<8))
        #expect(Self.refusal { try Self.base(shells: [allBlocked, open]) } == "blocked")
        let blockedStart = AmethystEscapeShell(apertures: [0], blocked: [1])
        #expect(Self.refusal { try Self.base(shells: [blockedStart, open], start: 1) } == "start")
        #expect(Self.refusal { try Self.base(start: 8) } == "start")
        #expect(Self.refusal { try Self.base(budget: 0) } == "budget")
        #expect(Self.refusal { try Self.base(budget: 61) } == "budget")
    }

    @Test func unsortedListsInAStoredFormAreRefused() throws {
        let level = try Self.base()
        var object = try #require(JSONSerialization.jsonObject(with: level.encoded()) as? [String: Any])
        var shells = try #require(object["shells"] as? [[String: Any]])
        shells[0]["apertures"] = [5, 2]
        object["shells"] = shells
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AmethystEscapeError.malformed("r02-g07.level")) { try AmethystEscapeLevel.decode(data) }
    }

    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        let level = try Self.base()
        let data = level.encoded()
        #expect(try AmethystEscapeLevel.decode(data) == level)
        #expect(try JSONDecoder().decode(AmethystEscapeLevel.self, from: data) == level)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["budget"] = 11
        let edited = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AmethystEscapeError.malformed("fingerprint")) { try AmethystEscapeLevel.decode(edited) }
        object["budget"] = 10
        object["schema"] = 2
        let newer = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AmethystEscapeError.newerSchema(2)) { try AmethystEscapeLevel.decode(newer) }
        object["schema"] = 0
        let older = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AmethystEscapeError.malformed("schema 0")) { try AmethystEscapeLevel.decode(older) }
        #expect(throws: AmethystEscapeError.malformed("unreadable")) { try AmethystEscapeLevel.decode(Data("{".utf8)) }
        object["schema"] = 1
        object.removeValue(forKey: "start")
        let missing = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AmethystEscapeError.malformed("unreadable")) { try AmethystEscapeLevel.decode(missing) }
    }

    @Test func reasonCodesAreStable() {
        let codes: [String] = [AmethystEscapeError.level("x"), .action("range"), .stage, .stale, .stuck, .newerSchema(2),
                               .malformed("x")].map(\.reasonCode)
        #expect(codes == ["r02-g07.level", "r02-g07.action", "r02-g07.stage", "r02-g07.stale", "r02-g07.stuck",
                          "r02-g07.newer-schema", "r02-g07.malformed"])
    }

    @Test func fixturesWinOnTheirLastActionAndRoundTrip() throws {
        for index in 0..<500 {
            let fixture = AmethystEscapeFixtures.fixture(index)
            #expect(AmethystEscapeFixtures.wins(level: fixture.level, actions: fixture.actions), "fixture \(index)")
            #expect(fixture.actions.count <= fixture.level.budget, "fixture \(index)")
            #expect(try AmethystEscapeLevel.decode(fixture.level.encoded()) == fixture.level, "fixture \(index)")
            let random = AmethystEscapeFixtures.randomLevel(index)
            #expect(try AmethystEscapeLevel.decode(random.encoded()) == random, "random \(index)")
        }
    }
}
