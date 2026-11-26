// MicroscopicAuroraGenerator — feature 482 (R02-G19-02) T-R02G1902-004 (FR-R02G1902-001, 005, 007; SC-R02G1902-003,
// 004; clarification Q1; research R4, R6). Builds each catalog level from its manifest entry: candidate c draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` in a fixed order — the swim length, the swarm rules,
// the swarm size, its centre and drift, each swimmer, the sites (usable within radius 8, redrawn until distinct, then
// sorted), the winning wells (a partial shuffle picks the plan's sites; each a strength and a sense) and the threshold;
// the winning wells are swum, the stencil is the largest lit group trimmed breadth-first to the band's maximum from its
// densest cell, then the coverage and coherence requirements are drawn. The level starts with no well; the solver must
// certify exactly the band's plan length. A candidate is skipped when the winning swim exits or loses coherence, the lit
// group is too small, the kernel refuses the level, its stencil equals the previous level's, or the solver disagrees;
// at most 64 candidates, then `generation(n)`. Ranges measured on a prototype over the real manifest (2026-11-26):
// every entry within candidate index 11.
import VisualCoreSimulation

/// The band profile of the generator (clarification Q1).
public struct MicroscopicAuroraBandProfile: Sendable, Equatable {
    /// The swarm sizes.
    public let swarm: ClosedRange<Int>
    /// The swim lengths in ticks.
    public let lengths: ClosedRange<Int>
    /// The number of sites.
    public let sites: Int
    /// The plan length (wells placed).
    public let plan: Int
    /// The stencil sizes.
    public let stencil: ClosedRange<Int>
    /// The required coverages in tenths of a percent.
    public let coverage: ClosedRange<Int>

    /// The profile of `band` 1 … 5.
    public static func of(band: Int) -> Self {
        switch band {
        case 1: Self(swarm: 4...5, lengths: 120...120, sites: 3, plan: 1, stencil: 6...24, coverage: 600...800)
        case 2: Self(swarm: 5...6, lengths: 120...140, sites: 4, plan: 1, stencil: 10...32, coverage: 700...850)
        case 3: Self(swarm: 6...7, lengths: 140...140, sites: 4, plan: 2, stencil: 14...40, coverage: 750...900)
        case 4: Self(swarm: 7...8, lengths: 140...160, sites: 5, plan: 2, stencil: 18...50, coverage: 800...950)
        default: Self(swarm: 8...8, lengths: 160...160, sites: 6, plan: 2, stencil: 20...60, coverage: 850...1000)
        }
    }
}

/// A generated catalog level with its certificate.
public struct MicroscopicAuroraGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: MicroscopicAuroraManifestEntry
    /// The level.
    public let level: MicroscopicAuroraLevel
    /// The certified plan.
    public let plan: MicroscopicAuroraPlan
    /// The difficulty metrics.
    public let difficulty: MicroscopicAuroraDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: MicroscopicAuroraManifestEntry, level: MicroscopicAuroraLevel, plan: MicroscopicAuroraPlan,
                difficulty: MicroscopicAuroraDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The catalog generator.
public enum MicroscopicAuroraGenerator {
    /// The catalog's id.
    public static let catalogID: String = "microscopic-aurora"
    /// The candidates tried per manifest entry.
    public static let maxCandidates: Int = 64
    /// The enclosure radius of catalog levels.
    static let radius: Int = 11
    /// The radius within which sites are drawn.
    static let siteRadius: Int = 8

    /// "microscopic-aurora-007".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return catalogID + "-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// A random cell usable within `radius` cells.
    static func cell(_ random: inout SeededRandom, radius: Int) -> MicroscopicAuroraCell {
        while true {
            let cell = MicroscopicAuroraCell(row: random.int(0...23), column: random.int(0...23))
            if MicroscopicAuroraLevel.isUsable(cell, radius: radius) { return cell }
        }
    }

    /// The stencil of a winning swim: the largest four-neighbour group of usable cells lit at `threshold` (the first
    /// such group in row-major order among equals), trimmed when larger than `maximum` to the breadth-first prefix from
    /// its densest cell (first in row-major order among equals), neighbours visited up, down, left, right.
    static func stencil(density: [Int], threshold: Int, maximum: Int) -> [MicroscopicAuroraCell] {
        var lit: [MicroscopicAuroraCell] = []
        for row in 0..<MicroscopicAuroraDish.cells {
            for column in 0..<MicroscopicAuroraDish.cells {
                let cell = MicroscopicAuroraCell(row: row, column: column)
                if density[cell.index] >= threshold && MicroscopicAuroraLevel.isUsable(cell, radius: radius) {
                    lit.append(cell)
                }
            }
        }
        var group: [MicroscopicAuroraCell] = []
        for candidate in MicroscopicAuroraDish.groupsOf(lit) where candidate.count > group.count { group = candidate }
        guard group.count > maximum else { return group }
        let members: Set<MicroscopicAuroraCell> = Set(group)
        var start: MicroscopicAuroraCell = group[0]
        for cell in group where density[cell.index] > density[start.index] { start = cell }
        var seen: Set<MicroscopicAuroraCell> = [start]
        var queue: [MicroscopicAuroraCell] = [start]
        var head: Int = 0
        while head < queue.count && queue.count < maximum {
            let c: MicroscopicAuroraCell = queue[head]
            head += 1
            let neighbours: [MicroscopicAuroraCell] = [
                MicroscopicAuroraCell(row: c.row - 1, column: c.column),
                MicroscopicAuroraCell(row: c.row + 1, column: c.column),
                MicroscopicAuroraCell(row: c.row, column: c.column - 1),
                MicroscopicAuroraCell(row: c.row, column: c.column + 1),
            ]
            for n in neighbours where members.contains(n) && !seen.contains(n) && queue.count < maximum {
                seen.insert(n)
                queue.append(n)
            }
        }
        return queue
    }

    /// Candidate `index` of `entry`, or nil when its winning swim exits or loses coherence, its lit group is too small
    /// or the kernel refuses it (the solver and the neighbour rule are applied by ``generate(_:previous:)``).
    public static func candidate(_ entry: MicroscopicAuroraManifestEntry, index: Int) -> MicroscopicAuroraLevel? {
        candidateWithSites(entry, index: index)?.level
    }

    /// Candidate `index` of `entry` with its winning wells.
    static func candidateWithSites(_ entry: MicroscopicAuroraManifestEntry,
                                   index: Int) -> (level: MicroscopicAuroraLevel, winning: [MicroscopicAuroraWell])? {
        let profile: MicroscopicAuroraBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let length: Int = random.int(profile.lengths)
        let rho: Int = random.int(2...4)
        let sigma: Int = random.int(1...rho)
        let kappa: Int = random.int(6...8)
        let separation: Int = random.int(0...3)
        let alignment: Int = random.int(1...6)
        let cohesion: Int = random.int(1...6)
        let acceleration: Int = random.int(4...12)
        let speed: Int = random.int(12...24)
        let rules = MicroscopicAuroraSwarmRules(neighbourRadius: rho, separationRadius: sigma, coherenceRadius: kappa,
                                                separationWeight: separation, alignmentWeight: alignment,
                                                cohesionWeight: cohesion, maxAcceleration: acceleration,
                                                maxSpeed: speed)
        let count: Int = random.int(profile.swarm)
        let cx: Int = MicroscopicAuroraDish.centre + random.int(-384...384)
        let cy: Int = MicroscopicAuroraDish.centre + random.int(-384...384)
        let driftX: Int = random.int(-2...2)
        let driftY: Int = random.int(-2...2)
        var swimmers: [MicroscopicAuroraSwimmer] = []
        for _ in 0..<count {
            let x: Int = cx + random.int(-384...384)
            let y: Int = cy + random.int(-384...384)
            let vx: Int = driftX + random.int(-2...2)
            let vy: Int = driftY + random.int(-2...2)
            swimmers.append(MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: x, y: y),
                                                     velocity: MicroscopicAuroraPoint(x: vx, y: vy)))
        }
        var sites: [MicroscopicAuroraCell] = []
        while sites.count < profile.sites {
            let site: MicroscopicAuroraCell = cell(&random, radius: siteRadius)
            if !sites.contains(site) { sites.append(site) }
        }
        sites.sort()
        var pick: [Int] = Array(0..<sites.count)
        var winning: [MicroscopicAuroraWell] = []
        for i in 0..<profile.plan {
            let j: Int = random.int(i...(pick.count - 1))
            pick.swapAt(i, j)
            let strength: Int = random.int(MicroscopicAuroraWell.strengths)
            let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
            winning.append(MicroscopicAuroraWell(cell: sites[pick[i]], strength: strength, sense: sense))
        }
        let threshold: Int = random.int(1...3)
        let placeholder: [MicroscopicAuroraCell] = [MicroscopicAuroraCell(row: 11, column: 11),
                                                    MicroscopicAuroraCell(row: 11, column: 12),
                                                    MicroscopicAuroraCell(row: 12, column: 11),
                                                    MicroscopicAuroraCell(row: 12, column: 12)]
        guard let probe = try? MicroscopicAuroraLevel.probe(radius: radius, length: length, rules: rules,
                                                            swimmers: swimmers, stencil: placeholder, threshold: 1,
                                                            coverage: 500, coherence: 2,
                                                            wells: [nil, nil, nil]) else { return nil }
        let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(probe, wells: winning)
        switch report.failure {
        case .exit, .coherence: return nil
        default: break
        }
        let cells: [MicroscopicAuroraCell] = stencil(density: report.density, threshold: threshold,
                                                     maximum: profile.stencil.upperBound)
        guard cells.count >= profile.stencil.lowerBound else { return nil }
        let coverage: Int = random.int(profile.coverage)
        let coherence: Int = max(2, min(report.smallestCoherence, random.int(2...count)))
        guard let level = try? MicroscopicAuroraLevel(
            id: levelID(entry.number), seed: entry.seed, difficulty: entry.band, radius: radius, length: length,
            rules: rules, swimmers: swimmers, stencil: cells, threshold: threshold, coverage: coverage,
            coherence: coherence, wells: [nil, nil, nil], budget: entry.budget, tutorial: entry.number <= 3,
            sites: sites) else { return nil }
        return (level, winning)
    }

    /// The certified level of `entry`: the first candidate the kernel accepts whose stencil differs from `previous`'s
    /// and whose minimal plan has the band's plan length.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: MicroscopicAuroraManifestEntry,
                                previous: MicroscopicAuroraLevel?) throws(MicroscopicAuroraError)
        -> MicroscopicAuroraGenerated {
        let profile: MicroscopicAuroraBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let (level, _) = candidateWithSites(entry, index: index) else { continue }
            if let previous, previous.stencil == level.stencil { continue }
            guard let plan = MicroscopicAuroraSolver.plan(level), plan.size == profile.plan else { continue }
            guard MicroscopicAuroraSolver.replayWins(level, actions: plan.actions) else { continue }
            return MicroscopicAuroraGenerated(entry: entry, level: level, plan: plan,
                                              difficulty: MicroscopicAuroraDifficulty(level: level, plan: plan),
                                              skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The 100 certified levels in manifest order.
    public static func catalog() throws(MicroscopicAuroraError) -> [MicroscopicAuroraGenerated] {
        var result: [MicroscopicAuroraGenerated] = []
        var previous: MicroscopicAuroraLevel?
        for entry in MicroscopicAuroraManifest.entries {
            let generated: MicroscopicAuroraGenerated = try generate(entry, previous: previous)
            result.append(generated)
            previous = generated.level
        }
        return result
    }

    /// The catalog digest over the level fingerprints in manifest order (R02-F24).
    public static func catalogDigest(_ levels: [MicroscopicAuroraLevel]) -> String {
        PuzzleCatalog<MicroscopicAuroraPuzzle>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
