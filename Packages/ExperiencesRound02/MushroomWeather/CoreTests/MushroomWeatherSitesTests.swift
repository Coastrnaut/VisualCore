// MushroomWeatherSitesTests — feature 492 (R02-G20-02) T-R02G2002-002 (FR-R02G2002-001; clarification Q1). The kernel
// extension: optional pod sites (2 … 8 distinct floor cells without a colony, stored row-major, refused by name in
// order after "pods share a cell": "sites", "sites duplicate", "site off floor", "site on colony", "pod not on a site";
// `allowsPod(_:)`); the play's "not a site" refusal (after off floor and colony cell); the puzzle contract's placements
// on sites only; a level without sites encoding and fingerprinting byte for byte as in feature 491 (values pinned from
// the feature 491 kernel); budgets 13 … 24 accepted, 25 refused. Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreMath
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherSitesTests {
    /// The cell at `row`, `column`.
    static func cell(_ row: Int, _ column: Int) -> MushroomWeatherCell { MushroomWeatherCell(row: row, column: column) }

    /// A hand-made 6 × 6 level: cell (0, 5) blocked, no vent, two pod slots, one colony at (2, 2) with band 50 … 60
    /// that a dry floor never reaches, so no arrangement of a start without pods already wins.
    static func level(sites: [MushroomWeatherCell]?, pods: [MushroomWeatherCell?] = [nil, nil],
                      budget: Int = 12) throws(MushroomWeatherError) -> MushroomWeatherLevel {
        let blocked: [MushroomWeatherCell] = [cell(0, 5)]
        var rates: [Int] = Array(repeating: 40, count: 36)
        rates[5] = 0
        return try MushroomWeatherLevel(
            id: "sites-test", seed: 0, difficulty: 1, rows: 6, columns: 6, blocked: blocked,
            humidity: Array(repeating: 0, count: 36), diffusion: 8, rates: rates, vents: [],
            podRules: MushroomWeatherPodRules(slots: 2, release: 20, grownRelease: 30, growthThreshold: 1000),
            colonies: [MushroomWeatherColony(cell: cell(2, 2), low: 50, high: 60)], moldBound: 1000, length: 20,
            required: 5, start: MushroomWeatherArrangement(pods: pods, ventsOpen: [], moonlight: 0), budget: budget,
            sites: sites)
    }

    /// The reason payload of a level refusal, "none" when accepted, or "other".
    static func refusal(_ build: () throws(MushroomWeatherError) -> MushroomWeatherLevel) -> String {
        do {
            _ = try build()
            return "none"
        } catch {
            if case .level(let name) = error { return name }
            return "other"
        }
    }

    /// The placement moves of the puzzle's initial position.
    static func placements(_ level: MushroomWeatherLevel) -> [MushroomWeatherAction] {
        let rules: MushroomWeatherPuzzle = MushroomWeatherPuzzle(level: level)
        var result: [MushroomWeatherAction] = []
        for move in rules.moves(in: rules.initialState) {
            if case .place = move { result.append(move) }
        }
        return result
    }

    @Test func sitesAreStoredRowMajorAndRoundTrip() throws {
        let sited: MushroomWeatherLevel = try Self.level(sites: [Self.cell(4, 1), Self.cell(1, 3), Self.cell(1, 1)])
        #expect(sited.sites == [Self.cell(1, 1), Self.cell(1, 3), Self.cell(4, 1)])
        let decoded: MushroomWeatherLevel = try MushroomWeatherLevel.decode(sited.encoded())
        #expect(decoded == sited)
        #expect(decoded.sites == sited.sites)
        #expect(String(decoding: sited.encoded(), as: UTF8.self).contains("\"sites\""))
        let plain: MushroomWeatherLevel = try Self.level(sites: nil)
        #expect(plain.sites == nil)
        #expect(plain.fingerprint != sited.fingerprint)
        #expect(MushroomWeatherLevel.siteCounts == 2...8)
    }

    @Test func sitesAreRefusedByNameInOrder() {
        let a: MushroomWeatherCell = Self.cell(0, 0)
        let b: MushroomWeatherCell = Self.cell(1, 1)
        var nine: [MushroomWeatherCell] = []
        for column in 0..<5 { nine.append(Self.cell(4, column)) }
        for column in 0..<4 { nine.append(Self.cell(5, column)) }
        let cases: [(String, () throws(MushroomWeatherError) -> MushroomWeatherLevel)] = [
            ("sites", { () throws(MushroomWeatherError) in try Self.level(sites: [a]) }),
            ("sites", { () throws(MushroomWeatherError) in try Self.level(sites: []) }),
            ("sites", { () throws(MushroomWeatherError) in try Self.level(sites: nine) }),
            ("sites duplicate", { () throws(MushroomWeatherError) in try Self.level(sites: [a, a]) }),
            ("site off floor", { () throws(MushroomWeatherError) in try Self.level(sites: [a, Self.cell(0, 5)]) }),
            ("site off floor", { () throws(MushroomWeatherError) in try Self.level(sites: [a, Self.cell(6, 0)]) }),
            ("site on colony", { () throws(MushroomWeatherError) in try Self.level(sites: [a, Self.cell(2, 2)]) }),
            ("pod not on a site", { () throws(MushroomWeatherError) in
                try Self.level(sites: [a, b], pods: [Self.cell(3, 3), nil])
            }),
            // Order: "pods share a cell" comes first; "sites" before "sites duplicate"; the floor before the colony.
            ("pods share a cell", { () throws(MushroomWeatherError) in
                try Self.level(sites: [a], pods: [Self.cell(3, 3), Self.cell(3, 3)])
            }),
            ("sites", { () throws(MushroomWeatherError) in try Self.level(sites: [a, a, a, a, a, a, a, a, a]) }),
            ("sites duplicate", { () throws(MushroomWeatherError) in
                try Self.level(sites: [Self.cell(2, 2), Self.cell(2, 2)])
            }),
            ("site off floor", { () throws(MushroomWeatherError) in
                try Self.level(sites: [Self.cell(0, 5), Self.cell(2, 2)])
            }),
            ("site on colony", { () throws(MushroomWeatherError) in
                try Self.level(sites: [Self.cell(2, 2), a], pods: [Self.cell(3, 3), nil])
            }),
        ]
        for (name, build) in cases { #expect(Self.refusal(build) == name, "expected \(name)") }
        #expect(Self.refusal { () throws(MushroomWeatherError) in try Self.level(sites: [a, b]) } == "none")
        #expect(Self.refusal { () throws(MushroomWeatherError) in try Self.level(sites: [a, b], pods: [nil, b]) }
            == "none")
        #expect(Self.refusal { () throws(MushroomWeatherError) in try Self.level(sites: Array(nine.prefix(8))) }
            == "none")
    }

    @Test func allowsPodOnlyOnSites() throws {
        let sited: MushroomWeatherLevel = try Self.level(sites: [Self.cell(0, 0), Self.cell(1, 1)])
        let plain: MushroomWeatherLevel = try Self.level(sites: nil)
        for row in 0..<6 {
            for column in 0..<6 {
                let cell: MushroomWeatherCell = Self.cell(row, column)
                #expect(sited.allowsPod(cell) == (cell == Self.cell(0, 0) || cell == Self.cell(1, 1)))
                #expect(plain.allowsPod(cell))
            }
        }
    }

    @Test func playRefusesAPlacementOffTheSites() throws {
        let a: MushroomWeatherCell = Self.cell(0, 0)
        let b: MushroomWeatherCell = Self.cell(1, 1)
        let sited: MushroomWeatherLevel = try Self.level(sites: [a, b])
        var play: MushroomWeatherPlay = MushroomWeatherPlay(level: sited)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let cases: [(MushroomWeatherAction, MushroomWeatherError)] = [
            (.place(slot: 0, cell: Self.cell(3, 3)), .action("not a site")),
            (.place(slot: 0, cell: Self.cell(0, 5)), .action("off floor")),
            (.place(slot: 0, cell: Self.cell(2, 2)), .action("colony cell")),
        ]
        for (action, expected) in cases {
            let before: String = play.fingerprint
            do {
                try play.apply(action, expecting: play.fingerprint)
                Issue.record("accepted \(action)")
            } catch {
                #expect(error == expected)
            }
            #expect(play.fingerprint == before)
            #expect(play.actionsSpent == 0)
        }
        try play.apply(.place(slot: 0, cell: a), expecting: play.fingerprint)
        do {
            try play.apply(.place(slot: 1, cell: a), expecting: play.fingerprint)
            Issue.record("accepted an occupied site")
        } catch {
            #expect(error == .action("occupied cell"))
        }
        do {
            try play.apply(.place(slot: 0, cell: Self.cell(4, 4)), expecting: play.fingerprint)
            Issue.record("accepted a move off the sites")
        } catch {
            #expect(error == .action("not a site"))
        }
        try play.apply(.place(slot: 0, cell: b), expecting: play.fingerprint)
        #expect(play.arrangement.pods == [b, nil])
        #expect(play.actionsSpent == 2)
    }

    @Test func puzzlePlacesPodsOnSitesOnly() throws {
        let a: MushroomWeatherCell = Self.cell(0, 0)
        let b: MushroomWeatherCell = Self.cell(1, 1)
        let sited: MushroomWeatherLevel = try Self.level(sites: [a, b])
        let expected: [MushroomWeatherAction] = [.place(slot: 0, cell: a), .place(slot: 0, cell: b),
                                                 .place(slot: 1, cell: a), .place(slot: 1, cell: b)]
        #expect(Self.placements(sited) == expected)
        let rules: MushroomWeatherPuzzle = MushroomWeatherPuzzle(level: sited)
        #expect(rules.apply(.place(slot: 0, cell: Self.cell(3, 3)), to: rules.initialState) == nil)
        #expect(rules.apply(.place(slot: 0, cell: a), to: rules.initialState) != nil)
        // Without sites every floor cell no colony stands on is placeable: 36 − 1 blocked − 1 colony, per slot.
        let plain: MushroomWeatherLevel = try Self.level(sites: nil)
        #expect(Self.placements(plain).count == 2 * 34)
    }

    /// The fingerprints and the SHA-256 of the stored form of the first four feature 491 fixtures, computed by the
    /// feature 491 kernel (commit a1dda911c) before the extension.
    static let pinned: [(fingerprint: String, stored: String)] = [
        ("c08e7c9f175b842a5499f49b926f5c546d84a78434942b24ef80783d44fbdc73",
         "1075015899aff053d560cbb5e98152bde6aa21076dd8e2ee7cb4c3f855bf294f"),
        ("a99d6c444ea666eb9352dd92f5f5e9ef578a508a8caac28dbddeb6f4a9a44d35",
         "9ae3be3a0fdd9fea57393a375c1cf6936c98f252cd16dd28004083888a48750a"),
        ("178a56be1d1e0b748bbb57a8ddc040a15b3e8c319bc381b9e187723b76720906",
         "a66ef883e590806a3fca094d6935010d5f9f3197fee614e87bafab7ff252a4ab"),
        ("c25b640592e90ce727a78896d70ad8ba4c9d5890db4451f4c95af047b45ddf2d",
         "203e12604914603c54e817025af1646c532d6c759342e36b51e67bba271dca52"),
    ]

    @Test func aLevelWithoutSitesEncodesAsBefore() throws {
        let fixtures: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: Self.pinned.count)
        for (index, fixture) in fixtures.enumerated() {
            let level: MushroomWeatherLevel = fixture.level
            #expect(level.sites == nil)
            #expect(level.fingerprint == Self.pinned[index].fingerprint)
            #expect(StableHash.sha256Hex(Array(level.encoded())) == Self.pinned[index].stored)
            #expect(!String(decoding: level.encoded(), as: UTF8.self).contains("sites"))
            #expect(try MushroomWeatherLevel.decode(level.encoded()) == level)
        }
    }

    @Test func budgetsUpToTwentyFourAreAccepted() {
        #expect(MushroomWeatherLevel.budgets == 1...24)
        for budget in 13...24 {
            #expect(Self.refusal { () throws(MushroomWeatherError) in try Self.level(sites: nil, budget: budget) }
                == "none", "budget \(budget)")
        }
        for budget in [0, 25] {
            #expect(Self.refusal { () throws(MushroomWeatherError) in try Self.level(sites: nil, budget: budget) }
                == "budget", "budget \(budget)")
        }
    }

    @Test func newRefusalsHaveStableReasonCodes() {
        #expect(MushroomWeatherError.generation(7).reasonCode == "r02-g20.generation")
        #expect(MushroomWeatherError.witness("replay").reasonCode == "r02-g20.witness")
    }
}
