// MicroscopicAuroraSitesTests — feature 482 (R02-G19-02) T-R02G1902-002 (FR-R02G1902-006; SC-R02G1902-006;
// clarification Q1). The additive kernel extension: well sites refused by name (count, duplicates, outside cells, a
// starting well off the sites), `allows(_:)`, the play's "not a site" refusal, the puzzle contract's moves on sites
// only, budgets 13 … 24 now accepted, and a level without sites encoding byte for byte as before (the field omitted).
// Explicit types, plain loops.
import Foundation
import Testing
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraSitesTests {
    /// The first fixture of feature 481, the base of every case.
    static let base: MicroscopicAuroraFixture = MicroscopicAuroraFixture.all(count: 1)[0]

    /// Usable cells of the base level, row-major.
    static var usable: [MicroscopicAuroraCell] {
        var cells: [MicroscopicAuroraCell] = []
        for row in 0..<MicroscopicAuroraDish.cells {
            for column in 0..<MicroscopicAuroraDish.cells {
                let cell = MicroscopicAuroraCell(row: row, column: column)
                if MicroscopicAuroraLevel.isUsable(cell, radius: base.level.radius) { cells.append(cell) }
            }
        }
        return cells
    }

    /// The base level with `sites`, `wells` and `budget`.
    static func level(sites: [MicroscopicAuroraCell]?, wells: [MicroscopicAuroraWell?]? = nil,
                      budget: Int? = nil) throws -> MicroscopicAuroraLevel {
        let l: MicroscopicAuroraLevel = base.level
        return try MicroscopicAuroraLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, radius: l.radius,
                                          length: l.length, rules: l.rules, swimmers: l.swimmers, stencil: l.stencil,
                                          threshold: l.threshold, coverage: l.coverage, coherence: l.coherence,
                                          wells: wells ?? l.wells, budget: budget ?? l.budget, sites: sites)
    }

    /// The level refusal's name, or "none".
    static func refusal(_ build: () throws -> MicroscopicAuroraLevel) -> String {
        do {
            _ = try build()
            return "none"
        } catch let error as MicroscopicAuroraError {
            if case .level(let name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    @Test func aLevelWithoutSitesKeepsItsStoredFormAndFingerprint() throws {
        let rebuilt: MicroscopicAuroraLevel = try Self.level(sites: nil)
        #expect(rebuilt == Self.base.level && rebuilt.fingerprint == Self.base.level.fingerprint)
        let text: String = String(decoding: rebuilt.encoded(), as: UTF8.self)
        #expect(!text.contains("\"sites\""))
        #expect(rebuilt.sites == nil)
        #expect(rebuilt.allows(Self.usable[0]))
    }

    @Test func sitesAreStoredSortedAndRoundTrip() throws {
        let cells: [MicroscopicAuroraCell] = [Self.usable[40], Self.usable[3], Self.usable[17]]
        let level: MicroscopicAuroraLevel = try Self.level(sites: cells, wells: [nil, nil, nil])
        #expect(level.sites == cells.sorted())
        #expect(level.fingerprint != Self.base.level.fingerprint)
        let decoded: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.decode(level.encoded())
        #expect(decoded == level)
        #expect(level.allows(Self.usable[3]) && !level.allows(Self.usable[4]))
        #expect(!level.allows(MicroscopicAuroraCell(row: 0, column: 0)))
    }

    @Test func badSitesAreRefusedByName() {
        let u: [MicroscopicAuroraCell] = Self.usable
        let corner = MicroscopicAuroraCell(row: 0, column: 0)
        let offSite = MicroscopicAuroraWell(cell: u[9], strength: 2, sense: .clockwise)
        let cases: [(String, () throws -> MicroscopicAuroraLevel)] = [
            ("sites", { try Self.level(sites: [u[0]], wells: [nil, nil, nil]) }),
            ("sites", { try Self.level(sites: Array(u.prefix(9)), wells: [nil, nil, nil]) }),
            ("sites duplicate", { try Self.level(sites: [u[0], u[0], u[1]], wells: [nil, nil, nil]) }),
            ("site outside", { try Self.level(sites: [u[0], corner], wells: [nil, nil, nil]) }),
            ("well not on a site", { try Self.level(sites: [u[0], u[1]], wells: [offSite, nil, nil]) }),
        ]
        for (name, build) in cases {
            #expect(Self.refusal(build) == name, "expected \(name)")
        }
    }

    @Test func budgetsUpToTwentyFourAreAccepted() {
        for budget in [13, 19, 24] {
            #expect(Self.refusal { try Self.level(sites: nil, budget: budget) } == "none")
        }
        #expect(Self.refusal { try Self.level(sites: nil, budget: 25) } == "budget")
    }

    @Test func thePlayRefusesAPlacementOffTheSites() throws {
        let u: [MicroscopicAuroraCell] = Self.usable
        let level: MicroscopicAuroraLevel = try Self.level(sites: [u[10], u[20]], wells: [nil, nil, nil])
        var play = MicroscopicAuroraPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let off = MicroscopicAuroraWell(cell: u[11], strength: 1, sense: .clockwise)
        let before: String = play.fingerprint
        var code: String = "none"
        do {
            try play.apply(.place(slot: 0, well: off), expecting: before)
        } catch {
            code = error == .action("not a site") ? "not a site" : error.reasonCode
        }
        #expect(code == "not a site")
        #expect(play.fingerprint == before && play.actionsSpent == 0)
        let on = MicroscopicAuroraWell(cell: u[20], strength: 3, sense: .counterclockwise)
        try play.apply(.place(slot: 0, well: on), expecting: before)
        #expect(play.wells[0] == on && play.actionsSpent == 1)
    }

    @Test func thePuzzleListsPlacementsOnSitesOnly() throws {
        let u: [MicroscopicAuroraCell] = Self.usable
        let sites: [MicroscopicAuroraCell] = [u[5], u[15], u[25]]
        let level: MicroscopicAuroraLevel = try Self.level(sites: sites, wells: [nil, nil, nil])
        let rules = MicroscopicAuroraPuzzle(level: level)
        let moves: [MicroscopicAuroraAction] = rules.moves(in: rules.initialState)
        #expect(moves.count == 3 * 3 * 8)
        for move in moves {
            if case .place(_, let well) = move { #expect(sites.contains(well.cell)) }
        }
        let off = MicroscopicAuroraWell(cell: u[6], strength: 1, sense: .clockwise)
        #expect(rules.apply(.place(slot: 0, well: off), to: rules.initialState) == nil)
    }

    @Test func theNewRefusalsHaveStableCodes() {
        #expect(MicroscopicAuroraError.generation(7).reasonCode == "r02-g19.generation")
        #expect(MicroscopicAuroraError.witness("x").reasonCode == "r02-g19.witness")
    }
}
