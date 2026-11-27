// MushroomWeatherGeneratorTests — feature 492 (R02-G20-02) T-R02G2002-004 (FR-R02G2002-001, 007; SC-R02G2002-001,
// 003, 004; clarification Q1). Host checks of the level generator: the manifest (100 entries, 20 per band, budgets
// 8 … 19, five emphases × 20); the level ids; candidate and generation determinism; the band profiles exactly as
// clarification Q1 writes them; every candidate of the first indices of the first two entries of every band against
// its band profile and the kernel ranges (rows, columns, blocked count, vents, slots, colonies, sites, D, rates, pod
// rules, M, T, K); vents and sites on near cells (a floor cell without a colony within one step, diagonals included, of
// a colony), sites not on vents; the level starts with no pod and does not already win; each colony's band contains its
// humidity over the last K cycles of the certified run and a sensitive colony's floor is at most low·3/4; ids, tutorial
// (levels 1 … 3) and difficulty (= band); the filters of `generate` (`skipped` is the first candidate whose floor and
// colonies differ from the previous level's and whose minimal plan has the band's plan length and replays); the
// neighbour rule (FR-R02G2002-007) with the accepted level itself as the previous one; the refusal `.generation(number)`
// provoked with an entry whose budget the kernel refuses, so every candidate is nil; and the catalog digest. Only a
// handful of entries are generated (the cache is a `static let`), never the whole catalog; the catalog's chaining is
// checked on the pairs (the second's previous is the first, as `catalog()` does). Explicit types and plain loops keep
// the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherGeneratorTests {
    /// The first two manifest numbers of every band.
    static let bandPairs: [Int] = [1, 2, 21, 22, 41, 42, 61, 62, 81, 82]

    /// The candidate indices checked against their band per sampled entry.
    static let rangeIndices: Range<Int> = 0..<6

    /// The generated levels of `bandPairs`, each pair chained as in the catalog (the second's previous is the first).
    static let generated: [Int: MushroomWeatherGenerated] = {
        var result: [Int: MushroomWeatherGenerated] = [:]
        var index: Int = 0
        while index < bandPairs.count {
            let first: MushroomWeatherGenerated? = try? MushroomWeatherGenerator.generate(
                entry(bandPairs[index]), previous: nil)
            if let first {
                result[bandPairs[index]] = first
                let second: MushroomWeatherGenerated? = try? MushroomWeatherGenerator.generate(
                    entry(bandPairs[index + 1]), previous: first.level)
                if let second { result[bandPairs[index + 1]] = second }
            }
            index += 2
        }
        return result
    }()

    /// The candidates of `bandPairs` at `rangeIndices`, keyed "number/index" (nil candidates are left out).
    static let candidates: [String: MushroomWeatherLevel] = {
        var result: [String: MushroomWeatherLevel] = [:]
        for number in bandPairs {
            for index in rangeIndices {
                if let level = MushroomWeatherGenerator.candidate(entry(number), index: index) {
                    result["\(number)/\(index)"] = level
                }
            }
        }
        return result
    }()

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> MushroomWeatherManifestEntry {
        MushroomWeatherManifest.entries[number - 1]
    }

    /// Whether `cell` is a near cell of `level`: a floor cell without a colony within one step (diagonals included) of
    /// a colony.
    static func isNear(_ cell: MushroomWeatherCell, in level: MushroomWeatherLevel) -> Bool {
        guard level.floorMask[level.index(of: cell)] else { return false }
        var near: Bool = false
        for colony in level.colonies {
            if colony.cell == cell { return false }
            if abs(colony.cell.row - cell.row) <= 1 && abs(colony.cell.column - cell.column) <= 1 { near = true }
        }
        return near
    }

    @Test func manifestHasTheHundredPlannedEntries() {
        let entries: [MushroomWeatherManifestEntry] = MushroomWeatherManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        var perEmphasis: [String: Int] = [:]
        var seeds: Set<UInt64> = []
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1, "entry \(entry.number)")
            #expect((8...19).contains(entry.budget), "entry \(entry.number)")
            perBand[entry.band, default: 0] += 1
            perEmphasis[entry.emphasis, default: 0] += 1
            seeds.insert(entry.seed)
        }
        #expect(seeds.count == 100)
        #expect(perBand == [1: 20, 2: 20, 3: 20, 4: 20, 5: 20])
        #expect(perEmphasis == ["route humidity": 20, "commit season": 20, "place fungus": 20,
                                "adjust mist vent": 20, "open canopy": 20])
        #expect(entries.map(\.budget).min() == 8)
        #expect(entries.map(\.budget).max() == 19)
    }

    @Test func levelIDsAreZeroPadded() {
        #expect(MushroomWeatherGenerator.levelID(1) == "mushroom-weather-001")
        #expect(MushroomWeatherGenerator.levelID(42) == "mushroom-weather-042")
        #expect(MushroomWeatherGenerator.levelID(100) == "mushroom-weather-100")
    }

    @Test func bandProfilesMatchTheClarification() {
        let expected: [MushroomWeatherBandProfile] = [
            MushroomWeatherBandProfile(rows: 6...7, columns: 6...7, blocked: 2...5, vents: 1, slots: 2, colonies: 2,
                                       sites: 4, plan: 2, margin: 4...6),
            MushroomWeatherBandProfile(rows: 6...8, columns: 6...8, blocked: 3...6, vents: 2, slots: 2, colonies: 3,
                                       sites: 4, plan: 3, margin: 3...5),
            MushroomWeatherBandProfile(rows: 7...8, columns: 7...9, blocked: 3...7, vents: 2, slots: 3, colonies: 3,
                                       sites: 5, plan: 3, margin: 2...4),
            MushroomWeatherBandProfile(rows: 7...9, columns: 8...10, blocked: 4...8, vents: 3, slots: 3, colonies: 4,
                                       sites: 6, plan: 4, margin: 1...3),
            MushroomWeatherBandProfile(rows: 8...9, columns: 8...10, blocked: 4...8, vents: 3, slots: 4, colonies: 5,
                                       sites: 6, plan: 5, margin: 1...2),
        ]
        for band in 1...5 {
            #expect(MushroomWeatherBandProfile.of(band: band) == expected[band - 1], "band \(band)")
        }
        #expect(MushroomWeatherBandProfile.of(band: 6) == expected[4])
    }

    @Test func candidatesAndGenerationAreDeterministic() throws {
        for number in [1, 41, 81] {
            let entry: MushroomWeatherManifestEntry = Self.entry(number)
            for index in 0..<3 {
                #expect(MushroomWeatherGenerator.candidate(entry, index: index)
                            == MushroomWeatherGenerator.candidate(entry, index: index), "entry \(number) \(index)")
            }
            let cached: MushroomWeatherGenerated = try #require(Self.generated[number])
            let again: MushroomWeatherGenerated = try MushroomWeatherGenerator.generate(entry, previous: nil)
            #expect(again == cached, "entry \(number)")
            #expect(again.level.fingerprint == cached.level.fingerprint)
        }
    }

    @Test func candidatesRespectTheirBandAndTheKernelRanges() {
        var checked: Int = 0
        for number in Self.bandPairs {
            let entry: MushroomWeatherManifestEntry = Self.entry(number)
            let profile: MushroomWeatherBandProfile = .of(band: entry.band)
            for index in Self.rangeIndices {
                guard let level = Self.candidates["\(number)/\(index)"] else { continue }
                let label: String = "entry \(number) candidate \(index)"
                checked += 1
                #expect(profile.rows.contains(level.rows), "\(label)")
                #expect(profile.columns.contains(level.columns), "\(label)")
                #expect(MushroomWeatherLevel.rowCounts.contains(level.rows), "\(label)")
                #expect(MushroomWeatherLevel.columnCounts.contains(level.columns), "\(label)")
                #expect(profile.blocked.contains(level.blocked.count), "\(label)")
                #expect(level.blocked == level.blocked.sorted(), "\(label)")
                #expect(level.vents.count == profile.vents, "\(label)")
                #expect(level.podRules.slots == profile.slots, "\(label)")
                #expect(level.colonies.count == profile.colonies, "\(label)")
                #expect(level.sites?.count == profile.sites, "\(label)")
                #expect(MushroomWeatherGenerator.diffusions.contains(level.diffusion), "\(label)")
                #expect(MushroomWeatherGenerator.releases.contains(level.podRules.release), "\(label)")
                #expect(level.podRules.grownRelease >= level.podRules.release, "\(label)")
                #expect(level.podRules.grownRelease <= min(80, level.podRules.release + 30), "\(label)")
                #expect(MushroomWeatherGenerator.thresholds.contains(level.podRules.growthThreshold), "\(label)")
                #expect(MushroomWeatherGenerator.moldBounds.contains(level.moldBound), "\(label)")
                #expect(MushroomWeatherGenerator.lengths.contains(level.length), "\(label)")
                #expect(MushroomWeatherGenerator.required.contains(level.required), "\(label)")
                #expect(MushroomWeatherLevel.moonlightLevels.contains(level.start.moonlight), "\(label)")
                for i in 0..<(level.rows * level.columns) {
                    if level.floorMask[i] {
                        #expect(MushroomWeatherGenerator.startHumidity.contains(level.humidity[i]), "\(label)")
                        #expect(MushroomWeatherGenerator.rates.contains(level.rates[i]), "\(label)")
                    } else {
                        #expect(level.humidity[i] == 0 && level.rates[i] == 0, "\(label)")
                    }
                }
                for vent in level.vents {
                    #expect(MushroomWeatherGenerator.openRates.contains(vent.openRate), "\(label)")
                    #expect(MushroomWeatherGenerator.closedRates.contains(vent.closedRate), "\(label)")
                }
            }
        }
        #expect(checked >= 20)
    }

    @Test func ventsAndSitesStandOnNearCells() {
        var checked: Int = 0
        for (key, level) in Self.candidates {
            checked += 1
            let ventCells: Set<MushroomWeatherCell> = Set(level.vents.map(\.cell))
            #expect(ventCells.count == level.vents.count, "\(key)")
            for vent in level.vents { #expect(Self.isNear(vent.cell, in: level), "\(key) vent \(vent.cell)") }
            let sites: [MushroomWeatherCell] = level.sites ?? []
            #expect(sites == sites.sorted(), "\(key)")
            #expect(Set(sites).count == sites.count, "\(key)")
            for site in sites {
                #expect(Self.isNear(site, in: level), "\(key) site \(site)")
                #expect(!ventCells.contains(site), "\(key) site \(site) on a vent")
            }
            #expect(Set(level.colonies.map(\.cell)).count == level.colonies.count, "\(key)")
        }
        #expect(checked >= 20)
    }

    @Test func levelsStartWithNoPodAndCarryIdTutorialAndBand() throws {
        for (key, level) in Self.candidates {
            #expect(level.start.pods.allSatisfy { $0 == nil }, "\(key)")
            #expect(level.start.pods.count == level.podRules.slots, "\(key)")
            #expect(!MushroomWeatherForest.report(level, arrangement: level.start).wins, "\(key)")
        }
        for number in Self.bandPairs {
            let generated: MushroomWeatherGenerated = try #require(Self.generated[number], "entry \(number)")
            let entry: MushroomWeatherManifestEntry = Self.entry(number)
            #expect(generated.entry == entry)
            #expect(generated.level.id == MushroomWeatherGenerator.levelID(number))
            #expect(generated.level.seed == entry.seed)
            #expect(generated.level.difficulty == entry.band)
            #expect(generated.level.budget == entry.budget)
            #expect(generated.level.tutorial == (number <= 3), "entry \(number)")
            #expect(generated.difficulty == MushroomWeatherDifficulty(level: generated.level, plan: generated.plan))
        }
        let three: MushroomWeatherLevel? = MushroomWeatherGenerator.candidate(Self.entry(3), index: 0)
            ?? MushroomWeatherGenerator.candidate(Self.entry(3), index: 1)
        let four: MushroomWeatherLevel? = MushroomWeatherGenerator.candidate(Self.entry(4), index: 0)
            ?? MushroomWeatherGenerator.candidate(Self.entry(4), index: 1)
        #expect(try #require(three).tutorial)
        #expect(try #require(four).tutorial == false)
    }

    @Test func bandsHoldTheCertifiedRunAndFloorsSitBelowThem() throws {
        for number in Self.bandPairs {
            let generated: MushroomWeatherGenerated = try #require(Self.generated[number], "entry \(number)")
            let level: MushroomWeatherLevel = generated.level
            let profile: MushroomWeatherBandProfile = .of(band: level.difficulty)
            let (report, fields) = MushroomWeatherForest.run(level, arrangement: generated.plan.arrangement,
                                                             keepFields: true)
            #expect(report.wins, "entry \(number)")
            for colony in level.colonies {
                let label: String = "entry \(number) colony \(colony.cell)"
                #expect(colony.low >= 0 && colony.low <= colony.high && colony.high <= level.moldBound, "\(label)")
                #expect(colony.high - colony.low >= 2 * profile.margin.lowerBound
                            || colony.low == 0 || colony.high == level.moldBound, "\(label)")
                let cellIndex: Int = level.index(of: colony.cell)
                for field in fields.suffix(level.required) {
                    #expect(colony.isInBand(field[cellIndex]), "\(label)")
                }
                if let floor = colony.survivalFloor {
                    #expect(floor <= colony.low * 3 / 4, "\(label)")
                    #expect(floor >= 0, "\(label)")
                }
            }
        }
        var floors: Int = 0
        for (key, level) in Self.candidates {
            for colony in level.colonies {
                guard let floor = colony.survivalFloor else { continue }
                floors += 1
                #expect(floor <= colony.low * 3 / 4, "\(key)")
            }
        }
        #expect(floors > 0)
    }

    @Test func generateTakesTheFirstQualifyingCandidate() throws {
        #expect(Self.generated.count == Self.bandPairs.count)
        for number in Self.bandPairs {
            let generated: MushroomWeatherGenerated = try #require(Self.generated[number], "entry \(number)")
            let entry: MushroomWeatherManifestEntry = Self.entry(number)
            let profile: MushroomWeatherBandProfile = .of(band: entry.band)
            let previous: MushroomWeatherLevel? = number % 20 == 2 ? Self.generated[number - 1]?.level : nil
            #expect(generated.skipped < MushroomWeatherGenerator.maxCandidates)
            #expect(generated.plan.size == profile.plan, "entry \(number)")
            #expect(MushroomWeatherSolver.replayWins(generated.level, actions: generated.plan.actions))
            #expect(generated.level == MushroomWeatherGenerator.candidate(entry, index: generated.skipped))
            if let previous {
                #expect(previous.blocked != generated.level.blocked || previous.colonies != generated.level.colonies
                            || previous.rows != generated.level.rows || previous.columns != generated.level.columns,
                        "entry \(number)")
            }
            for index in 0..<generated.skipped {
                guard let level = MushroomWeatherGenerator.candidate(entry, index: index) else { continue }
                if let previous, previous.rows == level.rows, previous.columns == level.columns,
                   previous.blocked == level.blocked, previous.colonies == level.colonies { continue }
                if let plan = MushroomWeatherSolver.plan(level), plan.size == profile.plan {
                    #expect(!MushroomWeatherSolver.replayWins(level, actions: plan.actions),
                            "entry \(number) candidate \(index) qualifies before \(generated.skipped)")
                }
            }
        }
    }

    @Test func neighbourRuleSkipsTheSameFloorAndColonies() throws {
        for number in [1, 41, 81] {
            let generated: MushroomWeatherGenerated = try #require(Self.generated[number])
            let previous: MushroomWeatherLevel = try #require(
                MushroomWeatherGenerator.candidate(Self.entry(number), index: generated.skipped))
            let again: MushroomWeatherGenerated = try MushroomWeatherGenerator.generate(
                Self.entry(number), previous: previous)
            #expect(again.skipped > generated.skipped, "entry \(number)")
            let same: Bool = again.level.rows == previous.rows && again.level.columns == previous.columns
                && again.level.blocked == previous.blocked && again.level.colonies == previous.colonies
            #expect(!same, "entry \(number)")
        }
    }

    @Test func generationRefusesAfterTheCandidateBound() {
        #expect(MushroomWeatherGenerator.maxCandidates == 64)
        let base: MushroomWeatherManifestEntry = Self.entry(7)
        let refused: MushroomWeatherManifestEntry = MushroomWeatherManifestEntry(
            number: 7, seed: base.seed, band: base.band, budget: 0, emphasis: base.emphasis)
        #expect(MushroomWeatherGenerator.candidate(refused, index: 0) == nil)
        #expect(throws: MushroomWeatherError.generation(7)) {
            try MushroomWeatherGenerator.generate(refused, previous: nil)
        }
        #expect(MushroomWeatherError.generation(7).reasonCode == "r02-g20.generation")
    }

    @Test func catalogDigestFollowsTheFingerprints() throws {
        let one: MushroomWeatherLevel = try #require(Self.generated[1]?.level)
        let two: MushroomWeatherLevel = try #require(Self.generated[2]?.level)
        let other: MushroomWeatherLevel = try #require(Self.generated[21]?.level)
        let digest: String = MushroomWeatherGenerator.catalogDigest([one, two])
        #expect(digest == MushroomWeatherGenerator.catalogDigest([one, two]))
        #expect(!digest.isEmpty)
        #expect(digest != MushroomWeatherGenerator.catalogDigest([one, other]))
        #expect(digest != MushroomWeatherGenerator.catalogDigest([two, one]))
    }
}
