// EchoCartographerGenerator — feature 402 (R02-G11-02) T-R02G1102-004 (FR-R02G1102-001, 005; SC-R02G1102-001, 003, 004;
// clarifications Q1, Q5). The seeded level generator of Echo Cartographer. Candidate c of manifest entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the width and the height (each in
// the band's size range); every cell, in index order, a wall with chance 1 in the band's `wallOneIn`; the entry among
// the open cells; the entry's region, which must hold at least 12 cells (the entry included) or the candidate is
// skipped; the beacon count in the band's range; the beacons drawn one by one from the region without the entry. The
// band sets the tolerance and the miss cost; the energy is the manifest's; ids `echo-cartographer-NNN`; tutorial on
// levels 1 … 3; difficulty = band. A candidate is kept when the solver's plan has a pulse count in the band's range and
// at most energy − 1 pulses (a pulse that spends the last energy fails) within the work bound, and its witness wins
// through the kernel; at most 256 candidates, then `generation(n)`. The ranges were measured by a prototype before they
// were written down (research R4).
import Foundation
import VisualCoreSimulation

/// What a band asks of its levels (clarification Q1).
public struct EchoCartographerBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The widths and heights (each drawn).
    public let sizes: ClosedRange<Int>
    /// Each cell is a wall with chance 1 in this.
    public let wallOneIn: Int
    /// The beacon counts.
    public let beacons: ClosedRange<Int>
    /// The claim tolerance.
    public let tolerance: Int
    /// The cost of a missed claim.
    public let missCost: Int
    /// The witness pulse counts accepted.
    public let pulses: ClosedRange<Int>

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> EchoCartographerBandProfile {
        switch min(5, max(1, band)) {
        case 1: EchoCartographerBandProfile(band: 1, sizes: 6...7, wallOneIn: 5, beacons: 1...1, tolerance: 1,
                                            missCost: 1, pulses: 1...2)
        case 2: EchoCartographerBandProfile(band: 2, sizes: 7...9, wallOneIn: 5, beacons: 1...2, tolerance: 1,
                                            missCost: 1, pulses: 2...3)
        case 3: EchoCartographerBandProfile(band: 3, sizes: 8...10, wallOneIn: 4, beacons: 2...2, tolerance: 1,
                                            missCost: 2, pulses: 3...4)
        case 4: EchoCartographerBandProfile(band: 4, sizes: 9...12, wallOneIn: 4, beacons: 2...3, tolerance: 0,
                                            missCost: 2, pulses: 4...5)
        default: EchoCartographerBandProfile(band: 5, sizes: 10...14, wallOneIn: 4, beacons: 3...4, tolerance: 0,
                                             missCost: 3, pulses: 5...6)
        }
    }
}

/// A certified catalog level with its plan and metrics.
public struct EchoCartographerGenerated: Sendable, Equatable {
    /// The manifest entry it came from.
    public let entry: EchoCartographerManifestEntry
    /// The level.
    public let level: EchoCartographerLevel
    /// The certified plan.
    public let plan: EchoCartographerPlan
    /// The difficulty metrics.
    public let difficulty: EchoCartographerDifficulty
    /// The candidates skipped before this one.
    public let skipped: Int

    /// A generated level of the given values (not checked).
    public init(entry: EchoCartographerManifestEntry, level: EchoCartographerLevel, plan: EchoCartographerPlan,
                difficulty: EchoCartographerDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness actions: the plan's pulses, then the claims on the beacons.
    public var actions: [EchoCartographerAction] { EchoCartographerSolver.actions(level, plan: plan) }
}

/// The seeded level generator (clarification Q1).
public enum EchoCartographerGenerator {
    /// The catalog id of R02-F24's digest.
    public static let catalogID: String = "echo-cartographer"
    /// The most candidates tried per manifest entry.
    public static let maxCandidates: Int = 256
    /// The fewest cells the entry's region may hold (the entry included).
    public static let minimumRegion: Int = 12

    /// The level id of number `number`: "echo-cartographer-001" … "echo-cartographer-100".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "echo-cartographer-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry`, or nil when its region is too small or its values make no valid level.
    public static func candidate(_ entry: EchoCartographerManifestEntry, index: Int) -> EchoCartographerLevel? {
        let profile: EchoCartographerBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let width: Int = random.int(profile.sizes)
        let height: Int = random.int(profile.sizes)
        var walls: Set<Int> = []
        for cell in 0..<(width * height) where random.int(0...(profile.wallOneIn - 1)) == 0 { walls.insert(cell) }
        guard let chamber = try? EchoCartographerChamber(width: width, height: height, walls: walls) else { return nil }
        var open: [Int] = []
        for cell in 0..<chamber.cellCount where !walls.contains(cell) { open.append(cell) }
        guard !open.isEmpty else { return nil }
        let entryCell: EchoCartographerCell = chamber.cell(open[random.int(0...(open.count - 1))])
        let reach: [Int?] = chamber.pathLengths(from: entryCell)
        var pool: [Int] = []
        var regionSize: Int = 0
        for cell in open where reach[cell] != nil {
            regionSize += 1
            if cell != chamber.index(entryCell) { pool.append(cell) }
        }
        guard regionSize >= minimumRegion else { return nil }
        let count: Int = random.int(profile.beacons)
        guard pool.count >= count else { return nil }
        var beacons: [EchoCartographerCell] = []
        for _ in 0..<count {
            beacons.append(chamber.cell(pool.remove(at: random.int(0...(pool.count - 1)))))
        }
        return try? EchoCartographerLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                          chamber: chamber, entry: entryCell, beacons: beacons,
                                          tolerance: profile.tolerance, energy: entry.energy,
                                          missCost: profile.missCost, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose plan's pulse count is in the band's range and at most
    /// energy − 1, within the work bound, and whose witness wins through the kernel.
    ///
    /// - Throws: `.generation(number)` when no candidate of the first ``maxCandidates`` qualifies.
    public static func generate(_ entry: EchoCartographerManifestEntry) throws(EchoCartographerError)
        -> EchoCartographerGenerated {
        let profile: EchoCartographerBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index), let plan = EchoCartographerSolver.plan(level) else {
                continue
            }
            let pulses: Int = plan.pulses.count
            guard profile.pulses.contains(pulses), pulses <= level.energy - 1 else { continue }
            guard EchoCartographerSolver.wins(level, actions: EchoCartographerSolver.actions(level, plan: plan)) else {
                continue
            }
            return EchoCartographerGenerated(entry: entry, level: level, plan: plan,
                                             difficulty: EchoCartographerDifficulty(level: level, plan: plan),
                                             skipped: index)
        }
        throw .generation(entry.number)
    }

    /// R02-F24's catalog digest over the level fingerprints in order.
    public static func catalogDigest(_ levels: [EchoCartographerLevel]) -> String {
        PuzzleCatalog<EchoCartographerRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
