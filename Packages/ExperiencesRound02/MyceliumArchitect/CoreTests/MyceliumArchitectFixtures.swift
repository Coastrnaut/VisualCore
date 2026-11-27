// MyceliumArchitectFixtures — feature 511 (R02-G22-01) T-R02G2201-002 (SC-R02G2201-001 … 004). Seeded Mycelium
// Architect levels with known winning arrangements. A fixture draws a board of 6 … 14 by 6 … 14 cells, a root, rocks
// on about one cell in eight and toxins on about one in sixteen (never on the root or its eight neighbours), 0 … 2 fixed
// nutrients, strength 1 … 8, reach 2 … 10, penalties 0 … 4, 32 … 96 pulses and a winning arrangement: 1 … 3 seeds,
// 0 … 3 placed nutrients and 0 … 2 blockers on empty cells. It runs that arrangement on a probe level with the widest
// budget and a placeholder terminal (terminals do not change growth) and skips the draw when growth is starved, toxic or
// grows fewer than three cells. Its 1 … 3 terminals are grown cells other than the root and the placed items; the
// nutrient budget is the grown weight plus 0 … 10 and the weight limit the grown weight plus 0 … (budget − weight). The
// player starts with no seed (all seeds are added) and nothing placed, so the start never wins; the placement limits
// are the winning counts plus 0 … 1 and the seed limit at least the winning seeds. The known actions are the seeds,
// then the nutrients, then the blockers, then `run`; the action budget is their number plus 0 … 2. Draws that fail are
// skipped, so the generator stays deterministic. Explicit types, plain loops.
import Foundation
import VisualCoreSimulation
@testable import MyceliumArchitectCore

/// A seeded level with its known winning arrangement and actions.
struct MyceliumArchitectFixture: Sendable {
    /// The level.
    let level: MyceliumArchitectLevel
    /// The winning arrangement.
    let winning: MyceliumArchitectArrangement
    /// The known actions: the arrangement actions that reach the winning arrangement, then `run`.
    let actions: [MyceliumArchitectAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_511

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [MyceliumArchitectFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [MyceliumArchitectFixture] = []
        while fixtures.count < count {
            if let fixture = make(&random, index: fixtures.count) { fixtures.append(fixture) }
        }
        return fixtures
    }

    /// One fixture, or nil when the draw does not qualify.
    static func make(_ random: inout SeededRandom, index: Int) -> MyceliumArchitectFixture? {
        let width: Int = random.int(6...14)
        let height: Int = random.int(6...14)
        let root = MyceliumArchitectCell(column: random.int(1...(width - 2)), row: random.int(1...(height - 2)))
        var rocks: [MyceliumArchitectCell] = []
        var toxins: [MyceliumArchitectCell] = []
        for row in 0..<height {
            for column in 0..<width {
                let cell = MyceliumArchitectCell(column: column, row: row)
                if cell.distance(to: root) <= 1 { continue }
                let roll: Int = random.int(0...15)
                if roll < 2 { rocks.append(cell) } else if roll == 2 { toxins.append(cell) }
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
        for _ in 0..<random.int(0...2) {
            guard let cell = freeCell(&random) else { return nil }
            fixed.append(cell)
        }
        guard let placeholder = freeCell(&random) else { return nil }
        var nutrients: [MyceliumArchitectCell] = []
        for _ in 0..<random.int(0...3) {
            guard let cell = freeCell(&random) else { return nil }
            nutrients.append(cell)
        }
        var blockers: [MyceliumArchitectCell] = []
        for _ in 0..<random.int(0...2) {
            guard let cell = freeCell(&random) else { return nil }
            blockers.append(cell)
        }
        var seedSet: Set<MyceliumArchitectDirection> = []
        let seedCount: Int = random.int(1...3)
        while seedSet.count < seedCount {
            seedSet.insert(MyceliumArchitectDirection(rawValue: random.int(0...7))!)
        }
        let seeds = seedSet.sorted()
        let strength: Int = random.int(1...8)
        let reach: Int = random.int(2...10)
        let curvature: Int = random.int(0...4)
        let obstacle: Int = random.int(0...4)
        let pulses: Int = random.int(32...96)
        let maxNutrients = min(6, nutrients.count + random.int(0...1))
        let maxBlockers = min(6, blockers.count + random.int(0...1))
        let maxSeeds = max(seeds.count, min(4, seeds.count + random.int(0...1)))
        guard let probe = try? MyceliumArchitectLevel(
            id: "probe", seed: 0, difficulty: 1, width: width, height: height, root: root, terminals: [placeholder],
            rocks: rocks, toxins: toxins, fixedNutrients: fixed, strength: strength, reach: reach,
            curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients, maxBlockers: maxBlockers,
            maxSeeds: maxSeeds, startSeeds: [], pulses: pulses, nutrientBudget: 4094, weightLimit: 4094, budget: 24,
            tutorial: false, refusingAWin: false) else { return nil }
        let winning = MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
        let report = MyceliumArchitectGrowth.report(probe, arrangement: winning)
        if let failure = report.failure {
            if case .unreached = failure {} else { return nil }
        }
        let placed = Set(nutrients + blockers + fixed + [placeholder])
        let candidates = report.grown.dropFirst().filter { !placed.contains($0) && !toxins.contains($0) }
        guard candidates.count >= 2 else { return nil }
        var terminals: [MyceliumArchitectCell] = []
        let terminalCount = min(candidates.count, random.int(1...3))
        while terminals.count < terminalCount {
            let cell = candidates[random.int(0...(candidates.count - 1))]
            if !terminals.contains(cell) { terminals.append(cell) }
        }
        let weight = report.totalWeight
        let nutrientBudget = min(4094, weight + random.int(0...10))
        let weightLimit = weight + random.int(0...(nutrientBudget - weight))
        var actions: [MyceliumArchitectAction] = seeds.map { .seed($0) }
        actions += nutrients.sorted().map { .nutrient($0) }
        actions += blockers.sorted().map { .blocker($0) }
        let budget = min(24, actions.count + random.int(0...2))
        actions.append(.run)
        guard let level = try? MyceliumArchitectLevel(
            id: "fixture-\(index)", seed: UInt64(index), difficulty: 1 + index % 5, width: width, height: height,
            root: root, terminals: terminals, rocks: rocks, toxins: toxins, fixedNutrients: fixed,
            strength: strength, reach: reach, curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients,
            maxBlockers: maxBlockers, maxSeeds: maxSeeds, startSeeds: [], pulses: pulses,
            nutrientBudget: max(2, nutrientBudget), weightLimit: max(2, weightLimit), budget: max(1, budget),
            tutorial: index % 4 == 0) else { return nil }
        guard MyceliumArchitectGrowth.report(level, arrangement: winning).wins else { return nil }
        return MyceliumArchitectFixture(level: level, winning: winning, actions: actions)
    }
}
