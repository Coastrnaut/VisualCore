// MicroscopicAuroraGeneratorTests — feature 482 (R02-G19-02) T-R02G1902-004 (FR-R02G1902-001, 007; SC-R02G1902-001,
// 003, 004; clarification Q1). Host checks of the level generator: the manifest (100 entries, 20 per band, the budgets
// by band, five emphases × 20); the level ids; candidate and generation determinism; the drawing order of
// clarification Q1 re-drawn independently here from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))` (swim
// length, swarm rules, swarm size, centre, drift, swimmers, sites, winning wells, threshold, then coverage and
// coherence) on sampled candidates of every band; every candidate of the first indices of the first two entries of
// every band against its band profile and the kernel ranges; the winning wells winning with full stencil coverage;
// the filters of `generate` (`skipped` is the first candidate the kernel accepts whose stencil differs from the
// previous level's and whose minimal plan has the band's plan length); the neighbour rule (FR-R02G1902-007); the
// refusal `.generation(number)` provoked with an entry whose budget the kernel refuses, so every candidate is nil; and
// the catalog digest. Only a handful of entries are generated (the cache is a `static let`), never the whole catalog.
// Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw: two per band.
    static let redrawNumbers: [Int] = [1, 3, 21, 30, 41, 50, 61, 70, 81, 90]

    /// The candidate indices re-drawn per sampled entry.
    static let redrawIndices: [Int] = [0, 1, 2, 5, 9]

    /// The first two manifest numbers of every band.
    static let bandPairs: [Int] = [1, 2, 21, 22, 41, 42, 61, 62, 81, 82]

    /// The candidate indices checked against their band per sampled entry.
    static let rangeIndices: Range<Int> = 0..<12

    /// The band profiles exactly as clarification Q1 writes them.
    static let documented: [MicroscopicAuroraBandProfile] = [
        MicroscopicAuroraBandProfile.of(band: 1), MicroscopicAuroraBandProfile.of(band: 2),
        MicroscopicAuroraBandProfile.of(band: 3), MicroscopicAuroraBandProfile.of(band: 4),
        MicroscopicAuroraBandProfile.of(band: 5),
    ]

    /// The generated levels of `bandPairs`, each pair chained as in the catalog (the second's previous is the first).
    static let generated: [Int: MicroscopicAuroraGenerated] = {
        var result: [Int: MicroscopicAuroraGenerated] = [:]
        var index: Int = 0
        while index < bandPairs.count {
            let first: MicroscopicAuroraGenerated? = try? MicroscopicAuroraGenerator.generate(
                entry(bandPairs[index]), previous: nil)
            if let first {
                result[bandPairs[index]] = first
                let second: MicroscopicAuroraGenerated? = try? MicroscopicAuroraGenerator.generate(
                    entry(bandPairs[index + 1]), previous: first.level)
                if let second { result[bandPairs[index + 1]] = second }
            }
            index += 2
        }
        return result
    }()

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> MicroscopicAuroraManifestEntry {
        MicroscopicAuroraManifest.entries[number - 1]
    }

    /// The stencil rule of clarification Q1, written independently: the largest four-neighbour group of usable cells
    /// lit at `threshold` (the first among equals), trimmed breadth-first from its densest cell (first in row-major
    /// order among equals), neighbours up, down, left, right.
    static func expectedStencil(density: [Int], threshold: Int, maximum: Int) -> [MicroscopicAuroraCell] {
        var lit: [MicroscopicAuroraCell] = []
        for row in 0..<24 {
            for column in 0..<24 {
                let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: row, column: column)
                if density[row * 24 + column] >= threshold && MicroscopicAuroraLevel.isUsable(cell, radius: 11) {
                    lit.append(cell)
                }
            }
        }
        let groups: [[MicroscopicAuroraCell]] = MicroscopicAuroraDish.groupsOf(lit)
        var largest: [MicroscopicAuroraCell] = []
        for group in groups where group.count > largest.count { largest = group }
        if largest.count <= maximum { return largest }
        var start: MicroscopicAuroraCell = largest[0]
        for cell in largest.sorted() where density[cell.index] > density[start.index] { start = cell }
        let members: Set<MicroscopicAuroraCell> = Set(largest)
        var order: [MicroscopicAuroraCell] = [start]
        var seen: Set<MicroscopicAuroraCell> = [start]
        var head: Int = 0
        while head < order.count && order.count < maximum {
            let c: MicroscopicAuroraCell = order[head]
            head += 1
            let next: [MicroscopicAuroraCell] = [
                MicroscopicAuroraCell(row: c.row - 1, column: c.column),
                MicroscopicAuroraCell(row: c.row + 1, column: c.column),
                MicroscopicAuroraCell(row: c.row, column: c.column - 1),
                MicroscopicAuroraCell(row: c.row, column: c.column + 1),
            ]
            for n in next where members.contains(n) && !seen.contains(n) && order.count < maximum {
                seen.insert(n)
                order.append(n)
            }
        }
        return order
    }

    /// Candidate `index` of `entry` re-drawn independently in the order of clarification Q1, or nil when the winning
    /// swim exits or loses coherence or the lit group is below the band's minimum (the level rules are then applied by
    /// the kernel, so the caller compares field by field).
    struct Redraw {
        let length: Int
        let rules: MicroscopicAuroraSwarmRules
        let swimmers: [MicroscopicAuroraSwimmer]
        let sites: [MicroscopicAuroraCell]
        let winning: [MicroscopicAuroraWell]
        let threshold: Int
        let stencil: [MicroscopicAuroraCell]?
        let coverage: Int?
        let coherence: Int?
    }

    /// The re-draw of candidate `index` of `entry`.
    static func redraw(_ entry: MicroscopicAuroraManifestEntry, index: Int) -> Redraw {
        let profile: MicroscopicAuroraBandProfile = documented[entry.band - 1]
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let length: Int = random.int(profile.lengths)
        let rho: Int = random.int(2...4)
        let sigma: Int = random.int(1...rho)
        let kappa: Int = random.int(6...8)
        let ws: Int = random.int(0...3)
        let wa: Int = random.int(1...6)
        let wc: Int = random.int(1...6)
        let aMax: Int = random.int(4...12)
        let vMax: Int = random.int(12...24)
        let rules: MicroscopicAuroraSwarmRules = MicroscopicAuroraSwarmRules(
            neighbourRadius: rho, separationRadius: sigma, coherenceRadius: kappa, separationWeight: ws,
            alignmentWeight: wa, cohesionWeight: wc, maxAcceleration: aMax, maxSpeed: vMax)
        let size: Int = random.int(profile.swarm)
        let centre: Int = MicroscopicAuroraDish.centre
        let cx: Int = centre + random.int(-384...384)
        let cy: Int = centre + random.int(-384...384)
        let dx: Int = random.int(-2...2)
        let dy: Int = random.int(-2...2)
        var swimmers: [MicroscopicAuroraSwimmer] = []
        for _ in 0..<size {
            let x: Int = cx + random.int(-384...384)
            let y: Int = cy + random.int(-384...384)
            let vx: Int = dx + random.int(-2...2)
            let vy: Int = dy + random.int(-2...2)
            swimmers.append(MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: x, y: y),
                                                     velocity: MicroscopicAuroraPoint(x: vx, y: vy)))
        }
        var sites: [MicroscopicAuroraCell] = []
        while sites.count < profile.sites {
            var drawn: MicroscopicAuroraCell? = nil
            while drawn == nil {
                let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: random.int(0...23),
                                                                        column: random.int(0...23))
                if MicroscopicAuroraLevel.isUsable(cell, radius: 8) { drawn = cell }
            }
            if let drawn, !sites.contains(drawn) { sites.append(drawn) }
        }
        sites.sort()
        var pick: [Int] = Array(0..<sites.count)
        var winning: [MicroscopicAuroraWell] = []
        for i in 0..<profile.plan {
            let j: Int = random.int(i...(sites.count - 1))
            pick.swapAt(i, j)
            let strength: Int = random.int(1...4)
            let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
            winning.append(MicroscopicAuroraWell(cell: sites[pick[i]], strength: strength, sense: sense))
        }
        let threshold: Int = random.int(1...3)
        let placeholder: [MicroscopicAuroraCell] = [
            MicroscopicAuroraCell(row: 11, column: 11), MicroscopicAuroraCell(row: 11, column: 12),
            MicroscopicAuroraCell(row: 12, column: 11), MicroscopicAuroraCell(row: 12, column: 12),
        ]
        let probe: MicroscopicAuroraLevel? = try? MicroscopicAuroraLevel.probe(
            radius: 11, length: length, rules: rules, swimmers: swimmers, stencil: placeholder, threshold: 1,
            coverage: 500, coherence: 2, wells: [nil, nil, nil])
        var stencil: [MicroscopicAuroraCell]? = nil
        var coverage: Int? = nil
        var coherence: Int? = nil
        if let probe {
            let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(probe, wells: winning)
            var swimFails: Bool = false
            if case .exit = report.failure { swimFails = true }
            if case .coherence = report.failure { swimFails = true }
            if !swimFails {
                let cells: [MicroscopicAuroraCell] = expectedStencil(density: report.density, threshold: threshold,
                                                                     maximum: profile.stencil.upperBound)
                if cells.count >= profile.stencil.lowerBound {
                    stencil = cells
                    coverage = random.int(profile.coverage)
                    coherence = max(2, min(report.smallestCoherence, random.int(2...size)))
                }
            }
        }
        return Redraw(length: length, rules: rules, swimmers: swimmers, sites: sites, winning: winning,
                      threshold: threshold, stencil: stencil, coverage: coverage, coherence: coherence)
    }

    /// Whether `cells` form one four-neighbour group.
    static func isOneGroup(_ cells: [MicroscopicAuroraCell]) -> Bool {
        MicroscopicAuroraDish.groupsOf(cells).count == 1
    }

    @Test func manifestHasTheHundredPlannedEntries() {
        let entries: [MicroscopicAuroraManifestEntry] = MicroscopicAuroraManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        var perEmphasis: [String: Int] = [:]
        var budgetsByBand: [Int: Set<Int>] = [:]
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1)
            let low: Int = 8 + 2 * (entry.band - 1)
            #expect((low...(low + 3)).contains(entry.budget), "entry \(entry.number) budget \(entry.budget)")
            perBand[entry.band, default: 0] += 1
            perEmphasis[entry.emphasis, default: 0] += 1
            budgetsByBand[entry.band, default: []].insert(entry.budget)
        }
        for band in 1...5 {
            #expect(perBand[band] == 20)
            let low: Int = 8 + 2 * (band - 1)
            #expect(budgetsByBand[band] == Set(low...(low + 3)))
        }
        #expect(perEmphasis.count == 5)
        for (emphasis, count) in perEmphasis { #expect(count == 20, "\(emphasis)") }
        #expect(Set(entries.map(\.seed)).count == 100)
        #expect(!MicroscopicAuroraManifest.provenance.isEmpty)
    }

    @Test func levelIDsAreZeroPadded() {
        #expect(MicroscopicAuroraGenerator.catalogID == "microscopic-aurora")
        #expect(MicroscopicAuroraGenerator.levelID(7) == "microscopic-aurora-007")
        #expect(MicroscopicAuroraGenerator.levelID(42) == "microscopic-aurora-042")
        #expect(MicroscopicAuroraGenerator.levelID(100) == "microscopic-aurora-100")
    }

    @Test func candidatesAndGenerationAreDeterministic() throws {
        for number in Self.bandPairs {
            for index in 0..<4 {
                let a: MicroscopicAuroraLevel? = MicroscopicAuroraGenerator.candidate(Self.entry(number), index: index)
                let b: MicroscopicAuroraLevel? = MicroscopicAuroraGenerator.candidate(Self.entry(number), index: index)
                #expect(a == b, "entry \(number) candidate \(index)")
            }
        }
        let cached: MicroscopicAuroraGenerated = try #require(Self.generated[1])
        let again: MicroscopicAuroraGenerated = try MicroscopicAuroraGenerator.generate(Self.entry(1), previous: nil)
        #expect(again == cached)
        #expect(again.level.fingerprint == cached.level.fingerprint)
    }

    @Test func candidatesFollowTheClarifiedDrawingOrder() {
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: MicroscopicAuroraManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let expected: Redraw = Self.redraw(entry, index: index)
                let pair = MicroscopicAuroraGenerator.candidateWithSites(entry, index: index)
                guard let stencil = expected.stencil else { // the kernel stores the stencil row-major
                    #expect(pair == nil, "entry \(number) candidate \(index) should be skipped")
                    continue
                }
                guard let pair else {
                    Issue.record("entry \(number) candidate \(index) skipped but the re-draw qualifies")
                    continue
                }
                let level: MicroscopicAuroraLevel = pair.level
                #expect(level.length == expected.length, "entry \(number) candidate \(index)")
                #expect(level.rules == expected.rules, "entry \(number) candidate \(index)")
                #expect(level.swimmers == expected.swimmers, "entry \(number) candidate \(index)")
                #expect(level.sites == expected.sites, "entry \(number) candidate \(index)")
                #expect(pair.winning == expected.winning, "entry \(number) candidate \(index)")
                #expect(level.threshold == expected.threshold, "entry \(number) candidate \(index)")
                #expect(level.stencil == stencil.sorted(), "entry \(number) candidate \(index)")
                #expect(level.coverage == expected.coverage, "entry \(number) candidate \(index)")
                #expect(level.coherence == expected.coherence, "entry \(number) candidate \(index)")
                compared += 1
            }
        }
        #expect(compared >= 10, "only \(compared) sampled candidates qualified")
    }

    @Test func candidatesRespectTheirBandAndTheKernelRanges() {
        var checked: Int = 0
        for number in Self.bandPairs {
            let entry: MicroscopicAuroraManifestEntry = Self.entry(number)
            let profile: MicroscopicAuroraBandProfile = Self.documented[entry.band - 1]
            for index in Self.rangeIndices {
                guard let level = MicroscopicAuroraGenerator.candidate(entry, index: index) else { continue }
                checked += 1
                let label: String = "entry \(number) candidate \(index)"
                #expect(level.radius == 11, "\(label)")
                #expect(level.id == MicroscopicAuroraGenerator.levelID(number), "\(label)")
                #expect(level.seed == entry.seed, "\(label)")
                #expect(level.difficulty == entry.band, "\(label)")
                #expect(level.budget == entry.budget, "\(label)")
                #expect(level.tutorial == (number <= 3), "\(label)")
                #expect(level.placedWells.isEmpty, "\(label)")
                #expect(level.wells.count == 3, "\(label)")
                #expect(profile.lengths.contains(level.length), "\(label)")
                #expect(profile.swarm.contains(level.swimmers.count), "\(label)")
                #expect(profile.stencil.contains(level.stencil.count), "\(label)")
                #expect(Self.isOneGroup(level.stencil), "\(label)")
                #expect(profile.coverage.contains(level.coverage), "\(label)")
                #expect((1...3).contains(level.threshold), "\(label)")
                #expect((2...level.swimmers.count).contains(level.coherence), "\(label)")
                let sites: [MicroscopicAuroraCell] = level.sites ?? []
                #expect(sites.count == profile.sites, "\(label)")
                #expect(Set(sites).count == sites.count, "\(label)")
                #expect(sites == sites.sorted(), "\(label)")
                for site in sites {
                    #expect(MicroscopicAuroraLevel.isUsable(site, radius: 8), "\(label) site \(site)")
                    #expect(level.allows(site), "\(label) site \(site)")
                }
                for cell in level.stencil {
                    #expect(MicroscopicAuroraLevel.isUsable(cell, radius: 11), "\(label) stencil \(cell)")
                }
            }
        }
        for (number, generated) in Self.generated {
            #expect(generated.entry == Self.entry(number))
            #expect(generated.level.id == MicroscopicAuroraGenerator.levelID(number))
            #expect(generated.level.placedWells.isEmpty)
        }
        #expect(checked >= 20, "only \(checked) candidates qualified")
    }

    @Test func winningWellsWinWithFullCoverage() {
        var checked: Int = 0
        for number in Self.bandPairs {
            let entry: MicroscopicAuroraManifestEntry = Self.entry(number)
            let profile: MicroscopicAuroraBandProfile = Self.documented[entry.band - 1]
            for index in Self.rangeIndices {
                guard let pair = MicroscopicAuroraGenerator.candidateWithSites(entry, index: index) else { continue }
                checked += 1
                let label: String = "entry \(number) candidate \(index)"
                #expect(pair.winning.count == profile.plan, "\(label)")
                #expect(Set(pair.winning.map(\.cell)).count == pair.winning.count, "\(label)")
                for well in pair.winning { #expect(pair.level.allows(well.cell), "\(label)") }
                let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(pair.level, wells: pair.winning)
                #expect(report.wins, "\(label)")
                #expect(report.litStencil.count == pair.level.stencil.count, "\(label)")
                #expect(report.coverage == 1000, "\(label)")
                #expect(!pair.level.startReport.wins, "\(label)")
            }
        }
        #expect(checked >= 20)
    }

    @Test func generateTakesTheFirstQualifyingCandidate() throws {
        #expect(Self.generated.count == Self.bandPairs.count)
        for number in Self.bandPairs {
            let generated: MicroscopicAuroraGenerated = try #require(Self.generated[number], "entry \(number)")
            let entry: MicroscopicAuroraManifestEntry = Self.entry(number)
            let profile: MicroscopicAuroraBandProfile = Self.documented[entry.band - 1]
            let previous: MicroscopicAuroraLevel? = number % 20 == 2 ? Self.generated[number - 1]?.level : nil
            #expect(generated.skipped < MicroscopicAuroraGenerator.maxCandidates)
            #expect(generated.plan.size == profile.plan, "entry \(number)")
            #expect(MicroscopicAuroraSolver.replayWins(generated.level, actions: generated.plan.actions))
            #expect(generated.level == MicroscopicAuroraGenerator.candidate(entry, index: generated.skipped))
            if let previous { #expect(generated.level.stencil != previous.stencil, "entry \(number)") }
            for index in 0..<generated.skipped {
                guard let level = MicroscopicAuroraGenerator.candidate(entry, index: index) else { continue }
                if let previous, previous.stencil == level.stencil { continue }
                let plan: MicroscopicAuroraPlan? = MicroscopicAuroraSolver.plan(level)
                if let plan, plan.size == profile.plan {
                    #expect(!MicroscopicAuroraSolver.replayWins(level, actions: plan.actions),
                            "entry \(number) candidate \(index) qualifies before \(generated.skipped)")
                }
            }
        }
    }

    @Test func neighbourRuleSkipsTheSameStencil() throws {
        for number in [1, 41, 81] {
            let generated: MicroscopicAuroraGenerated = try #require(Self.generated[number])
            let again: MicroscopicAuroraGenerated = try MicroscopicAuroraGenerator.generate(
                Self.entry(number), previous: generated.level)
            #expect(again.level.stencil != generated.level.stencil, "entry \(number)")
            #expect(again.skipped > generated.skipped, "entry \(number)")
        }
    }

    @Test func generationRefusesAfterTheCandidateBound() {
        #expect(MicroscopicAuroraGenerator.maxCandidates == 64)
        let base: MicroscopicAuroraManifestEntry = Self.entry(7)
        let refused: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifestEntry(
            number: 7, seed: base.seed, band: base.band, budget: 0, emphasis: base.emphasis)
        #expect(MicroscopicAuroraGenerator.candidate(refused, index: 0) == nil)
        #expect(throws: MicroscopicAuroraError.generation(7)) {
            try MicroscopicAuroraGenerator.generate(refused, previous: nil)
        }
        #expect(MicroscopicAuroraError.generation(7).reasonCode == "r02-g19.generation")
    }

    @Test func catalogDigestFollowsTheFingerprints() throws {
        let one: MicroscopicAuroraLevel = try #require(Self.generated[1]?.level)
        let two: MicroscopicAuroraLevel = try #require(Self.generated[2]?.level)
        let other: MicroscopicAuroraLevel = try #require(Self.generated[21]?.level)
        let digest: String = MicroscopicAuroraGenerator.catalogDigest([one, two])
        #expect(digest == MicroscopicAuroraGenerator.catalogDigest([one, two]))
        #expect(!digest.isEmpty)
        #expect(digest != MicroscopicAuroraGenerator.catalogDigest([one, other]))
        #expect(digest != MicroscopicAuroraGenerator.catalogDigest([two, one]))
    }
}
