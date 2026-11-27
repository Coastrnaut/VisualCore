// MyceliumArchitectSitesTests — feature 512 (R02-G22-02) T-R02G2202-002 (FR-R02G2202-009; SC-R02G2202-007;
// clarification Q1). The kernel extension of feature 511 (R02-G22-01): optional placement sites. A hand level without
// sites keeps its literal pinned fingerprint and a byte-identical stored form (the `sites` key is absent, so the level
// is exactly feature 511's); a level with sites round-trips through `encoded()` and `decode(_:)` with its fingerprint
// and stores them in ascending (row, column); the level refusals "site count" (1 site, 13 sites, a duplicate), "site"
// (off the board) and "site not empty" (on the root, a terminal, a rock, a toxin or a fixed nutrient) come after the
// range and shared-cell checks and before "nothing placeable"; the play refuses a nutrient or blocker off a site with
// `r02-g22.action` ("not a site"); the puzzle contract offers placements only on sites. Explicit types, plain loops.
import Foundation
import Testing
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectSitesTests {
    typealias Cell = MyceliumArchitectCell
    typealias Level = MyceliumArchitectLevel

    /// The fingerprint of ``hand(sites:)`` without sites, measured on 2026-11-27 with the kernel. It equals feature
    /// 511's fingerprint of the same level: without sites the `sites` key is absent from the canonical JSON, whose 24
    /// fields are feature 511's (checked: `shasum -a 256` of the stored form without its fingerprint gives this value).
    static let pinnedFingerprint: String = "d9b837f5d58cc6d1ce0cbe34cff0bbdabb2d016c2e9aa754fccf8b7a6b14432f"

    /// The stored form of ``hand(sites:)`` without sites, byte for byte (feature 511's form: no `sites` key).
    static let pinnedStoredForm: String = #"""
        {"budget":6,"curvature":1,"difficulty":1,\#
        "fingerprint":"d9b837f5d58cc6d1ce0cbe34cff0bbdabb2d016c2e9aa754fccf8b7a6b14432f",\#
        "fixedNutrients":[{"column":5,"row":1}],"height":5,"id":"sites-hand","maxBlockers":1,\#
        "maxNutrients":2,"maxSeeds":2,"nutrientBudget":4094,"obstacle":0,"pulses":16,"reach":4,\#
        "rocks":[{"column":4,"row":0}],"root":{"column":1,"row":2},"schema":1,"seed":512,"startSeeds":[],\#
        "strength":2,"terminals":[{"column":7,"row":2}],"toxins":[{"column":4,"row":4}],"tutorial":false,\#
        "weightLimit":4094,"width":9}
        """#

    /// The root of the hand level.
    static let root: Cell = Cell(column: 1, row: 2)
    /// The terminal of the hand level.
    static let terminal: Cell = Cell(column: 7, row: 2)
    /// The rock of the hand level.
    static let rock: Cell = Cell(column: 4, row: 0)
    /// The toxin of the hand level.
    static let toxin: Cell = Cell(column: 4, row: 4)
    /// The fixed nutrient of the hand level.
    static let fixed: Cell = Cell(column: 5, row: 1)
    /// Three empty cells of the hand level, given out of order.
    static let threeSites: [Cell] = [Cell(column: 6, row: 3), Cell(column: 3, row: 1), Cell(column: 3, row: 3)]

    /// A 9 × 5 hand level: root (1, 2), terminal (7, 2), a rock, a toxin and a fixed nutrient, no starting seed (so the
    /// start never wins); the values given override the defaults.
    static func hand(sites: [Cell]? = nil, terminals: [Cell] = [terminal], rocks: [Cell] = [rock],
                     maxNutrients: Int = 2, maxBlockers: Int = 1, maxSeeds: Int = 2,
                     startSeeds: [MyceliumArchitectDirection] = [], budget: Int = 6)
        throws(MyceliumArchitectError) -> Level {
        try Level(id: "sites-hand", seed: 512, difficulty: 1, width: 9, height: 5, root: root, terminals: terminals,
                  rocks: rocks, toxins: [toxin], fixedNutrients: [fixed], strength: 2, reach: 4, curvature: 1,
                  obstacle: 0, maxNutrients: maxNutrients, maxBlockers: maxBlockers, maxSeeds: maxSeeds,
                  startSeeds: startSeeds, pulses: 16, nutrientBudget: 4094, weightLimit: 4094, budget: budget,
                  tutorial: false, sites: sites)
    }

    /// The level refusal of `make`, or nil when it is accepted.
    static func refusal(_ make: () throws(MyceliumArchitectError) -> Level) -> String? {
        do {
            _ = try make()
            return nil
        } catch {
            if case .level(let name) = error { return name }
            return "\(error)"
        }
    }

    /// A fresh play of `level` after `begin`.
    static func playing(_ level: Level) throws -> MyceliumArchitectPlay {
        var play: MyceliumArchitectPlay = MyceliumArchitectPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    @Test func aLevelWithoutSitesKeepsFeature511sFingerprintAndStoredForm() throws {
        let level: Level = try Self.hand()
        #expect(level.sites == nil)
        #expect(level.fingerprint == Self.pinnedFingerprint, "fingerprint \(level.fingerprint)")
        let text: String = try #require(String(data: level.encoded(), encoding: .utf8))
        #expect(text == Self.pinnedStoredForm, "stored form \(text)")
        #expect(!text.contains("\"sites\""))
        let decoded: Level = try Level.decode(level.encoded())
        #expect(decoded == level)
        #expect(decoded.sites == nil)
        #expect(decoded.encoded() == level.encoded())
    }

    @Test func aLevelWithSitesRoundTripsWithItsFingerprint() throws {
        let level: Level = try Self.hand(sites: Self.threeSites)
        let sorted: [Cell] = Self.threeSites.sorted()
        #expect(level.sites == sorted)
        #expect(level.fingerprint != Self.pinnedFingerprint)
        let data: Data = level.encoded()
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"sites\""))
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level)
        #expect(decoded.fingerprint == level.fingerprint)
        #expect(decoded.sites == sorted)
        #expect(decoded.encoded() == data)
        let plain: Level = try JSONDecoder().decode(Level.self, from: data)
        #expect(plain == level)
        // The same sites in another order give the same level.
        let reordered: Level = try Self.hand(sites: sorted.reversed())
        #expect(reordered.fingerprint == level.fingerprint)
        // An edited site breaks the stored fingerprint.
        let edited: String = text.replacingOccurrences(of: "\"sites\":[{\"column\":3,\"row\":1}",
                                                       with: "\"sites\":[{\"column\":2,\"row\":1}")
        #expect(edited != text)
        do {
            _ = try Level.decode(Data(edited.utf8))
            Issue.record("an edited site decodes")
        } catch {
            #expect(error == .malformed("fingerprint"))
        }
    }

    @Test func siteRefusalsComeInOrder() {
        // Accepted: 2 and 12 sites.
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1), Cell(column: 3, row: 3)])
        } == nil)
        var twelve: [Cell] = []
        for column in 2...7 {
            twelve.append(Cell(column: column, row: 3))
            if column != 4 && column != 5 { twelve.append(Cell(column: column, row: 0)) }
        }
        twelve.append(Cell(column: 8, row: 0))
        twelve.append(Cell(column: 8, row: 3))
        #expect(twelve.count == 12)
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in try Self.hand(sites: twelve) } == nil)
        // "site count": 1 site, 13 sites, a duplicate.
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1)])
        } == "site count")
        let thirteen: [Cell] = twelve + [Cell(column: 8, row: 1)]
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: thirteen)
        } == "site count")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1), Cell(column: 3, row: 1)])
        } == "site count")
        // "site": off the board.
        let offBoard: [Cell] = [Cell(column: 9, row: 2), Cell(column: 3, row: 5), Cell(column: -1, row: 0)]
        for cell in offBoard {
            #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
                try Self.hand(sites: [Cell(column: 3, row: 1), cell])
            } == "site", "\(cell)")
        }
        // "site not empty": the root, the terminal, a rock, a toxin, a fixed nutrient.
        let occupied: [Cell] = [Self.root, Self.terminal, Self.rock, Self.toxin, Self.fixed]
        for cell in occupied {
            #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
                try Self.hand(sites: [Cell(column: 3, row: 1), cell])
            } == "site not empty", "\(cell)")
        }
        // The order among the site rules: count before board, board before emptiness.
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 9, row: 2)])
        } == "site count")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Self.root, Cell(column: 9, row: 2)])
        } == "site")
        // After the range and shared-cell checks.
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1)], rocks: [Self.terminal])
        } == "shared cell")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1)], budget: 0)
        } == "budget")
        // Before "nothing placeable": no placement limit and every seed already started.
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(maxNutrients: 0, maxBlockers: 0, maxSeeds: 1, startSeeds: [.north])
        } == "nothing placeable")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1)], maxNutrients: 0, maxBlockers: 0, maxSeeds: 1,
                          startSeeds: [.north])
        } == "site count")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1), Cell(column: 9, row: 2)], maxNutrients: 0,
                          maxBlockers: 0, maxSeeds: 1, startSeeds: [.north])
        } == "site")
        #expect(Self.refusal { () throws(MyceliumArchitectError) -> Level in
            try Self.hand(sites: [Cell(column: 3, row: 1), Self.fixed], maxNutrients: 0, maxBlockers: 0,
                          maxSeeds: 1, startSeeds: [.north])
        } == "site not empty")
    }

    @Test func thePlayRefusesAPlacementOffASite() throws {
        let level: Level = try Self.hand(sites: Self.threeSites)
        let offSite: Cell = Cell(column: 2, row: 0)
        #expect(level.isEmpty(offSite, in: level.start))
        #expect(!level.isSite(offSite))
        let placements: [MyceliumArchitectAction] = [.nutrient(offSite), .blocker(offSite)]
        for action in placements {
            var play: MyceliumArchitectPlay = try Self.playing(level)
            let before: String = play.fingerprint
            do {
                try play.apply(action, expecting: play.fingerprint)
                Issue.record("\(action) off a site is accepted")
            } catch {
                #expect(error == .action("not a site"), "\(action)")
                #expect(error.reasonCode == "r02-g22.action")
            }
            #expect(play.fingerprint == before)
            #expect(play.actionsSpent == 0)
        }
        // On a site both are accepted.
        var play: MyceliumArchitectPlay = try Self.playing(level)
        try play.apply(.nutrient(Cell(column: 3, row: 1)), expecting: play.fingerprint)
        try play.apply(.blocker(Cell(column: 3, row: 3)), expecting: play.fingerprint)
        #expect(play.actionsSpent == 2)
        // Without sites the same off-site cell is accepted (feature 511's behaviour).
        let open: Level = try Self.hand()
        var free: MyceliumArchitectPlay = try Self.playing(open)
        try free.apply(.nutrient(offSite), expecting: free.fingerprint)
        try free.apply(.blocker(Cell(column: 2, row: 4)), expecting: free.fingerprint)
        #expect(free.actionsSpent == 2)
    }

    @Test func thePuzzleOffersPlacementsOnlyOnSites() throws {
        let level: Level = try Self.hand(sites: Self.threeSites)
        let puzzle: MyceliumArchitectPuzzle = MyceliumArchitectPuzzle(level: level)
        let moves: [MyceliumArchitectAction] = puzzle.moves(in: puzzle.initialState)
        var expected: [MyceliumArchitectAction] = []
        for cell in Self.threeSites.sorted() { expected.append(.nutrient(cell)) }
        for cell in Self.threeSites.sorted() { expected.append(.blocker(cell)) }
        for direction in MyceliumArchitectDirection.allCases.sorted() { expected.append(.seed(direction)) }
        #expect(moves == expected)
        for move in moves {
            switch move {
            case .nutrient(let cell), .blocker(let cell): #expect(level.isSite(cell), "\(move)")
            case .seed: break
            case .clear, .unseed, .run: Issue.record("unexpected move \(move)")
            }
        }
        #expect(puzzle.apply(.nutrient(Cell(column: 2, row: 0)), to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.blocker(Cell(column: 2, row: 0)), to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.nutrient(Cell(column: 3, row: 1)), to: puzzle.initialState) != nil)
        // Without sites every empty cell is offered.
        let open: Level = try Self.hand()
        let openPuzzle: MyceliumArchitectPuzzle = MyceliumArchitectPuzzle(level: open)
        var empty: Int = 0
        for row in 0..<open.height {
            for column in 0..<open.width where open.isEmpty(Cell(column: column, row: row), in: open.start) {
                empty += 1
            }
        }
        #expect(openPuzzle.moves(in: openPuzzle.initialState).count == 2 * empty + 8)
    }
}
