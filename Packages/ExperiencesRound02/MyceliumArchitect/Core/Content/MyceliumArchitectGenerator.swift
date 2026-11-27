// MyceliumArchitectGenerator — feature 512 (R02-G22-02) T-R02G2202-003 (FR-R02G2202-001, 005, 007; clarification Q2;
// research R2, R4, R7). Builds each catalog level from its manifest entry: candidate c of entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order — the board, the root, the rocks and
// toxins, the fixed nutrients, strength, reach, κ, ο, the sites, the plan (the band's length p, the emphasised kind
// first), the starting seeds and, after the winning growth, the terminal count and the two slacks. The winning
// arrangement (starting seeds plus plan) is grown on a probe level with a placeholder terminal; the terminals are the
// latest-grown cells that are neither sites nor fixed nutrients; budget and limit follow from the grown weight. A
// candidate is skipped when the growth is toxic, starved or too small, the level rules refuse it, its board equals the
// previous level's, the solver's minimal plan is not p, or the plan does not win through the play; at most 1 024
// candidates, then `generation(n)`. Integers only; no clock.
import Foundation
import VisualCoreSimulation

/// A generated catalog level with its certificate.
public struct MyceliumArchitectGeneratedLevel: Sendable, Equatable {
    /// The manifest entry.
    public let entry: MyceliumArchitectManifestEntry
    /// The level.
    public let level: MyceliumArchitectLevel
    /// The solver's minimal plan and proof.
    public let solution: MyceliumArchitectSolution
    /// The difficulty metrics.
    public let difficulty: MyceliumArchitectDifficulty
    /// The candidates skipped before this one.
    public let skipped: Int

    /// A generated level of these values.
    public init(entry: MyceliumArchitectManifestEntry, level: MyceliumArchitectLevel,
                solution: MyceliumArchitectSolution, difficulty: MyceliumArchitectDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The band profiles of clarification Q2.
public struct MyceliumArchitectBandProfile: Sendable, Hashable {
    /// The board width and height range.
    public let sides: ClosedRange<Int>
    /// The rock chance per cell, in thousandths.
    public let rockPermille: Int
    /// The toxin chance per cell, in thousandths.
    public let toxinPermille: Int
    /// The terminal count range.
    public let terminals: ClosedRange<Int>
    /// The site count.
    public let sites: Int
    /// The fixed nutrient count range.
    public let fixedNutrients: ClosedRange<Int>
    /// The seed limit.
    public let seedLimit: Int
    /// The strength range.
    public let strength: ClosedRange<Int>
    /// The reach range.
    public let reach: ClosedRange<Int>
    /// The curvature penalty range.
    public let curvature: ClosedRange<Int>
    /// The obstacle penalty range.
    public let obstacle: ClosedRange<Int>
    /// The growth pulses.
    public let pulses: Int
    /// The nutrient budget above the grown weight.
    public let budgetSlack: ClosedRange<Int>
    /// The weight limit above the grown weight.
    public let limitSlack: ClosedRange<Int>
    /// The plan length p.
    public let plan: Int

    /// The profile of `band` (1 … 5).
    public static func band(_ band: Int) -> MyceliumArchitectBandProfile {
        switch band {
        case 1:
            MyceliumArchitectBandProfile(sides: 8...8, rockPermille: 80, toxinPermille: 30, terminals: 1...1,
                                         sites: 4, fixedNutrients: 1...1, seedLimit: 1, strength: 4...8,
                                         reach: 4...8, curvature: 1...2, obstacle: 0...1, pulses: 48,
                                         budgetSlack: 4...8, limitSlack: 2...6, plan: 1)
        case 2:
            MyceliumArchitectBandProfile(sides: 9...10, rockPermille: 90, toxinPermille: 40, terminals: 1...2,
                                         sites: 5, fixedNutrients: 1...2, seedLimit: 2, strength: 3...8,
                                         reach: 4...8, curvature: 1...2, obstacle: 0...1, pulses: 64,
                                         budgetSlack: 3...6, limitSlack: 1...4, plan: 2)
        case 3:
            MyceliumArchitectBandProfile(sides: 10...12, rockPermille: 100, toxinPermille: 50, terminals: 2...2,
                                         sites: 6, fixedNutrients: 1...2, seedLimit: 2, strength: 3...7,
                                         reach: 4...10, curvature: 1...2, obstacle: 0...1, pulses: 80,
                                         budgetSlack: 2...5, limitSlack: 0...3, plan: 3)
        case 4:
            MyceliumArchitectBandProfile(sides: 12...14, rockPermille: 100, toxinPermille: 40, terminals: 2...3,
                                         sites: 6, fixedNutrients: 1...2, seedLimit: 2, strength: 2...7,
                                         reach: 5...10, curvature: 1...2, obstacle: 0...1, pulses: 96,
                                         budgetSlack: 1...4, limitSlack: 0...2, plan: 3)
        default:
            MyceliumArchitectBandProfile(sides: 14...16, rockPermille: 100, toxinPermille: 40, terminals: 3...3,
                                         sites: 6, fixedNutrients: 1...2, seedLimit: 2, strength: 2...6,
                                         reach: 5...12, curvature: 1...2, obstacle: 0...1, pulses: 112,
                                         budgetSlack: 0...3, limitSlack: 0...1, plan: 4)
        }
    }
}

/// The seeded generator and the catalog.
public enum MyceliumArchitectGenerator {
    /// The catalog id of the digest.
    public static let catalogID = "mycelium-architect"
    /// The candidates tried per entry before `generation(n)`.
    public static let candidateBound = 1024

    /// The kind of one plan action.
    enum Kind: CaseIterable { case seed, nutrient, blocker }

    /// The level of `entry`, certified, or `generation(number)`.
    public static func generate(_ entry: MyceliumArchitectManifestEntry, previous: MyceliumArchitectLevel?)
        throws(MyceliumArchitectError) -> MyceliumArchitectGeneratedLevel {
        for index in 0..<candidateBound {
            if let generated = candidate(entry, index: index, previous: previous) { return generated }
        }
        throw .generation(entry.number)
    }

    /// The whole catalog in manifest order.
    public static func catalog() throws(MyceliumArchitectError) -> [MyceliumArchitectGeneratedLevel] {
        var levels: [MyceliumArchitectGeneratedLevel] = []
        var previous: MyceliumArchitectLevel?
        for entry in MyceliumArchitectManifest.entries {
            let generated = try generate(entry, previous: previous)
            levels.append(generated)
            previous = generated.level
        }
        return levels
    }

    /// The catalog digest over the level fingerprints in manifest order (R02-F24).
    public static func digest(_ levels: [MyceliumArchitectLevel]) -> String {
        PuzzleCatalog<MyceliumArchitectPuzzle>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }

    /// Whether two levels share a board: size, root, rocks and toxins (FR-R02G2202-007).
    static func sameBoard(_ a: MyceliumArchitectLevel, _ b: MyceliumArchitectLevel) -> Bool {
        a.width == b.width && a.height == b.height && a.root == b.root && a.rocks == b.rocks && a.toxins == b.toxins
    }

    /// Candidate `index` of `entry`, or nil when it does not qualify.
    static func candidate(_ entry: MyceliumArchitectManifestEntry, index: Int,
                          previous: MyceliumArchitectLevel?) -> MyceliumArchitectGeneratedLevel? {
        let profile = MyceliumArchitectBandProfile.band(entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.plannedSeed, index: UInt64(index)))
        let width: Int = random.int(profile.sides)
        let height: Int = random.int(profile.sides)
        let root = MyceliumArchitectCell(column: random.int(1...2), row: random.int(1...(height - 2)))
        var rocks: [MyceliumArchitectCell] = []
        var toxins: [MyceliumArchitectCell] = []
        for row in 0..<height {
            for column in 0..<width {
                let cell = MyceliumArchitectCell(column: column, row: row)
                if cell.distance(to: root) <= 1 { continue }
                let roll: Int = random.int(0...999)
                if roll < profile.rockPermille {
                    rocks.append(cell)
                } else if roll < profile.rockPermille + profile.toxinPermille {
                    toxins.append(cell)
                }
            }
        }
        var taken: Set<MyceliumArchitectCell> = Set(rocks + toxins + [root])
        func freeCell(_ random: inout SeededRandom) -> MyceliumArchitectCell? {
            for _ in 0..<64 {
                let cell = MyceliumArchitectCell(column: random.int(0...(width - 1)), row: random.int(0...(height - 1)))
                if !taken.contains(cell) {
                    taken.insert(cell)
                    return cell
                }
            }
            return nil
        }
        var fixed: [MyceliumArchitectCell] = []
        let fixedCount: Int = random.int(profile.fixedNutrients)
        for _ in 0..<fixedCount {
            guard let cell = freeCell(&random) else { return nil }
            fixed.append(cell)
        }
        let strength: Int = random.int(profile.strength)
        let reach: Int = random.int(profile.reach)
        let curvature: Int = random.int(profile.curvature)
        let obstacle: Int = random.int(profile.obstacle)
        var sites: [MyceliumArchitectCell] = []
        for _ in 0..<profile.sites {
            guard let cell = freeCell(&random) else { return nil }
            sites.append(cell)
        }
        // The plan: the band's p actions, the emphasised kind first.
        var planSeeds: [MyceliumArchitectDirection] = []
        var planNutrients: [MyceliumArchitectCell] = []
        var planBlockers: [MyceliumArchitectCell] = []
        var freeSites: [MyceliumArchitectCell] = sites
        var plan: [MyceliumArchitectAction] = []
        for step in 0..<profile.plan {
            var kinds: [Kind] = []
            if planSeeds.count < profile.seedLimit { kinds.append(.seed) }
            if !freeSites.isEmpty { kinds.append(.nutrient); kinds.append(.blocker) }
            guard !kinds.isEmpty else { return nil }
            var kind: Kind = kinds[random.int(0...(kinds.count - 1))]
            if step == 0 {
                let emphasised: Kind? = switch entry.emphasis {
                case "place nutrient": .nutrient
                case "block toxin": .blocker
                case "seed filament": .seed
                default: nil
                }
                if let emphasised, kinds.contains(emphasised) { kind = emphasised }
            }
            switch kind {
            case .seed:
                let open = MyceliumArchitectDirection.allCases.filter { !planSeeds.contains($0) }
                let direction = open[random.int(0...(open.count - 1))]
                planSeeds.append(direction)
                plan.append(.seed(direction))
            case .nutrient, .blocker:
                let site = freeSites.remove(at: random.int(0...(freeSites.count - 1)))
                if kind == .nutrient {
                    planNutrients.append(site)
                    plan.append(.nutrient(site))
                } else {
                    planBlockers.append(site)
                    plan.append(.blocker(site))
                }
            }
        }
        // The starting seeds: 0 … seed limit − plan seeds, at least 1 when the plan has no seed.
        let room = profile.seedLimit - planSeeds.count
        var startCount: Int = random.int(0...room)
        if planSeeds.isEmpty { startCount = max(1, startCount) }
        var startSeeds: [MyceliumArchitectDirection] = []
        while startSeeds.count < startCount {
            let open = MyceliumArchitectDirection.allCases.filter { !planSeeds.contains($0) && !startSeeds.contains($0) }
            startSeeds.append(open[random.int(0...(open.count - 1))])
        }
        let winning = MyceliumArchitectArrangement(nutrients: planNutrients, blockers: planBlockers,
                                                   seeds: startSeeds + planSeeds)
        // The probe: a placeholder terminal on the first empty non-site cell (terminals do not change growth).
        var placeholder: MyceliumArchitectCell?
        search: for row in 0..<height {
            for column in 0..<width {
                let cell = MyceliumArchitectCell(column: column, row: row)
                if !taken.contains(cell) { placeholder = cell; break search }
            }
        }
        guard let placeholder else { return nil }
        let maxNutrients = min(6, planNutrients.count + 1)
        let maxBlockers = min(6, planBlockers.count + 1)
        guard let probe = try? MyceliumArchitectLevel(
            id: "probe", seed: 0, difficulty: entry.band, width: width, height: height, root: root,
            terminals: [placeholder], rocks: rocks, toxins: toxins, fixedNutrients: fixed, strength: strength,
            reach: reach, curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients,
            maxBlockers: maxBlockers, maxSeeds: profile.seedLimit, startSeeds: startSeeds, pulses: profile.pulses,
            nutrientBudget: 4094, weightLimit: 4094, budget: 24, tutorial: false, refusingAWin: false,
            sites: sites) else { return nil }
        let grown = MyceliumArchitectGrowth.report(probe, arrangement: winning)
        if let failure = grown.failure {
            switch failure {
            case .toxic, .starved, .overweight: return nil
            case .unreached: break
            }
        }
        guard grown.nodeCount >= 5 else { return nil }
        // The terminals: the latest-grown cells that are neither sites nor fixed nutrients.
        let terminalCount: Int = random.int(profile.terminals)
        var order: [(pulse: Int, cell: MyceliumArchitectCell)] = []
        for (i, cell) in grown.grown.enumerated() where i > 0 && !sites.contains(cell) && !fixed.contains(cell) {
            order.append((grown.grownPulses[i], cell))
        }
        order.sort { a, b in a.pulse != b.pulse ? a.pulse > b.pulse : a.cell < b.cell }
        guard order.count >= terminalCount else { return nil }
        let terminals = order.prefix(terminalCount).map(\.cell)
        let weight = grown.totalWeight
        let nutrientBudget = min(4094, weight + random.int(profile.budgetSlack))
        let weightLimit = min(nutrientBudget, weight + random.int(profile.limitSlack))
        guard let level = try? MyceliumArchitectLevel(
            id: String(format: "mycelium-architect-%03d", entry.number), seed: entry.plannedSeed,
            difficulty: entry.band, width: width, height: height, root: root, terminals: terminals, rocks: rocks,
            toxins: toxins, fixedNutrients: fixed, strength: strength, reach: reach, curvature: curvature,
            obstacle: obstacle, maxNutrients: maxNutrients, maxBlockers: maxBlockers, maxSeeds: profile.seedLimit,
            startSeeds: startSeeds, pulses: profile.pulses, nutrientBudget: max(2, nutrientBudget),
            weightLimit: max(2, weightLimit), budget: entry.budget, tutorial: entry.number <= 3,
            sites: sites) else { return nil }
        if let previous, sameBoard(previous, level) { return nil }
        guard let solution = MyceliumArchitectSolver.solve(level, maxDepth: profile.plan),
              solution.length == profile.plan else { return nil }
        guard replayWins(level, solution.actions) else { return nil }
        return MyceliumArchitectGeneratedLevel(entry: entry, level: level, solution: solution,
                                               difficulty: MyceliumArchitectDifficulty(level: level,
                                                                                       solution: solution),
                                               skipped: index)
    }

    /// Whether `actions` win `level` through the play.
    static func replayWins(_ level: MyceliumArchitectLevel, _ actions: [MyceliumArchitectAction]) -> Bool {
        var play = MyceliumArchitectPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
        } catch {
            return false
        }
        return play.stage == .won
    }
}
