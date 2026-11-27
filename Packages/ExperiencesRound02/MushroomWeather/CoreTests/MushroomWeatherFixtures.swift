// MushroomWeatherFixtures — feature 491 (R02-G20-01) T-R02G2001-002 (SC-R02G2001-001 … 004). Seeded Mushroom Weather
// levels with known winning arrangements. A fixture draws a floor of 6 … 8 rows by 6 … 9 columns with about one cell in
// eight blocked, a starting humidity 50 … 600 per floor cell, a diffusion 2 … 12, cell rates 5 … 60, 1 … 3 vents (open
// 60 … 200, closed 0 … 30), pod rules (2 … 4 slots, release 10 … 40, grown release r … 80, threshold 300 … 3000), 1 … 3
// colonies on free floor cells, a run of 20 … 40 cycles and 5 … min(T, 15) required cycles; then a winning arrangement
// (1 … slots pods on free floor cells, random vent states and moonlight). It runs that arrangement on a probe level and
// sets each colony's band around its humidity over the last K cycles (widened by 0 … 20 units), a sensitive colony's
// floor 1 … 20 units below the colony's lowest humidity of the run (start included), and M 1 … 200 units above the
// run's highest humidity (at least 1000), so the arrangement wins. The start is no pods, or one pod on another free
// cell, with the vents and moonlight flipped or kept, kept only when it does not win; the known actions reach the
// winning arrangement and then run; the budget is their number plus 0 … 2. Draws that fail are skipped, so the
// generator stays deterministic. Explicit types, plain loops.
import Foundation
import VisualCoreSimulation
@testable import MushroomWeatherCore

/// A seeded level with its known winning arrangement and actions.
struct MushroomWeatherFixture: Sendable {
    /// The level.
    let level: MushroomWeatherLevel
    /// The winning arrangement.
    let winning: MushroomWeatherArrangement
    /// The known actions: the arrangement actions that reach the winning arrangement, then `run`.
    let actions: [MushroomWeatherAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_491

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [MushroomWeatherFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [MushroomWeatherFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// A random cell of `cells` not in `used`, or nil when none is left.
    static func pick(_ random: inout SeededRandom, from cells: [MushroomWeatherCell],
                     avoiding used: Set<MushroomWeatherCell>) -> MushroomWeatherCell? {
        let free: [MushroomWeatherCell] = cells.filter { !used.contains($0) }
        guard !free.isEmpty else { return nil }
        return free[random.int(0...(free.count - 1))]
    }

    /// The arrangement actions from `start` to `goal` (pods slot by slot, then vents, then moonlight).
    static func actions(from start: MushroomWeatherArrangement,
                        to goal: MushroomWeatherArrangement) -> [MushroomWeatherAction] {
        var actions: [MushroomWeatherAction] = []
        for slot in start.pods.indices where start.pods[slot] != goal.pods[slot] && goal.pods[slot] == nil {
            actions.append(.remove(slot: slot))
        }
        for slot in start.pods.indices where start.pods[slot] != goal.pods[slot] {
            if let cell = goal.pods[slot] { actions.append(.place(slot: slot, cell: cell)) }
        }
        for index in start.ventsOpen.indices where start.ventsOpen[index] != goal.ventsOpen[index] {
            actions.append(.vent(index: index, open: goal.ventsOpen[index]))
        }
        if start.moonlight != goal.moonlight { actions.append(.moonlight(level: goal.moonlight)) }
        return actions
    }

    /// One fixture from `random`, or nil when the draw does not make a level.
    static func make(_ random: inout SeededRandom, index: Int) -> MushroomWeatherFixture? {
        let rows: Int = random.int(6...8)
        let columns: Int = random.int(6...9)
        var blocked: [MushroomWeatherCell] = []
        var floor: [MushroomWeatherCell] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let cell = MushroomWeatherCell(row: row, column: column)
                if random.int(0...7) == 0 { blocked.append(cell) } else { floor.append(cell) }
            }
        }
        guard floor.count >= 12 else { return nil }
        let blockedSet: Set<MushroomWeatherCell> = Set(blocked)
        var humidity: [Int] = []
        var rates: [Int] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let isBlocked: Bool = blockedSet.contains(MushroomWeatherCell(row: row, column: column))
                humidity.append(isBlocked ? 0 : random.int(50...600))
                rates.append(isBlocked ? 0 : random.int(5...60))
            }
        }
        let diffusion: Int = random.int(2...12)
        var used: Set<MushroomWeatherCell> = []
        var vents: [MushroomWeatherVent] = []
        for _ in 0..<random.int(1...3) {
            guard let cell = pick(&random, from: floor, avoiding: used) else { return nil }
            used.insert(cell)
            vents.append(MushroomWeatherVent(cell: cell, openRate: random.int(60...200), closedRate: random.int(0...30)))
        }
        let release: Int = random.int(10...40)
        let podRules = MushroomWeatherPodRules(slots: random.int(2...4), release: release,
                                               grownRelease: random.int(release...80),
                                               growthThreshold: random.int(300...3000))
        var colonyCells: [MushroomWeatherCell] = []
        var occupied: Set<MushroomWeatherCell> = []
        for _ in 0..<random.int(1...3) {
            guard let cell = pick(&random, from: floor, avoiding: occupied) else { return nil }
            occupied.insert(cell)
            colonyCells.append(cell)
        }
        let length: Int = random.int(20...40)
        let required: Int = random.int(5...min(length, 15))
        var pods: [MushroomWeatherCell?] = Array(repeating: nil, count: podRules.slots)
        for slot in 0..<random.int(1...podRules.slots) {
            guard let cell = pick(&random, from: floor, avoiding: occupied) else { return nil }
            occupied.insert(cell)
            pods[slot] = cell
        }
        var ventsOpen: [Bool] = []
        for _ in vents { ventsOpen.append(random.int(0...1) == 1) }
        let winning = MushroomWeatherArrangement(pods: pods, ventsOpen: ventsOpen, moonlight: random.int(0...3))
        let wide: [MushroomWeatherColony] = colonyCells.map {
            MushroomWeatherColony(cell: $0, low: 0, high: MushroomWeatherForest.maximumMoldBound)
        }
        guard let probe = try? MushroomWeatherLevel.probe(
            rows: rows, columns: columns, blocked: blocked, humidity: humidity, diffusion: diffusion, rates: rates,
            vents: vents, podRules: podRules, colonies: wide, moldBound: MushroomWeatherForest.maximumMoldBound,
            length: length, required: required, start: winning) else { return nil }
        let run = MushroomWeatherForest.run(probe, arrangement: winning, keepFields: true)
        guard run.report.wins else { return nil }
        var highest: Int = 0
        for field in run.fields {
            for value in field { highest = max(highest, value) }
        }
        let moldBound: Int = max(1000, highest + random.int(1...200))
        guard moldBound <= MushroomWeatherForest.maximumMoldBound else { return nil }
        var colonies: [MushroomWeatherColony] = []
        for cell in colonyCells {
            let i: Int = probe.index(of: cell)
            var lastLow: Int = Int.max, lastHigh: Int = 0, lowest: Int = Int.max
            for (cycle, field) in run.fields.enumerated() {
                lowest = min(lowest, field[i])
                if cycle > length - required {
                    lastLow = min(lastLow, field[i])
                    lastHigh = max(lastHigh, field[i])
                }
            }
            let low: Int = max(0, lastLow - random.int(0...20))
            let high: Int = min(moldBound, lastHigh + random.int(0...20))
            var survivalFloor: Int?
            if random.int(0...1) == 1 { survivalFloor = min(low, max(0, lowest - random.int(1...20))) }
            colonies.append(MushroomWeatherColony(cell: cell, low: low, high: high, survivalFloor: survivalFloor))
        }
        let colonySet: Set<MushroomWeatherCell> = Set(colonyCells)
        let freeFloor: [MushroomWeatherCell] = floor.filter { !colonySet.contains($0) && !pods.contains($0) }
        for attempt in 0..<8 {
            var startPods: [MushroomWeatherCell?] = Array(repeating: nil, count: podRules.slots)
            if attempt % 2 == 1, let cell = pick(&random, from: freeFloor, avoiding: []) {
                startPods[podRules.slots - 1] = cell
            }
            let flipVents: Bool = attempt % 4 >= 2
            let startVents: [Bool] = flipVents ? ventsOpen.map { !$0 } : ventsOpen
            let startMoon: Int = attempt >= 4 ? (winning.moonlight + 1 + random.int(0...2)) % 4 : winning.moonlight
            let start = MushroomWeatherArrangement(pods: startPods, ventsOpen: startVents, moonlight: startMoon)
            var known: [MushroomWeatherAction] = actions(from: start, to: winning)
            let budget: Int = min(MushroomWeatherLevel.budgets.upperBound, known.count + random.int(0...2))
            known.append(.run)
            guard let level = try? MushroomWeatherLevel(
                id: "fixture-\(index)", seed: UInt64(index), difficulty: 1, rows: rows, columns: columns,
                blocked: blocked, humidity: humidity, diffusion: diffusion, rates: rates, vents: vents,
                podRules: podRules, colonies: colonies, moldBound: moldBound, length: length, required: required,
                start: start, budget: budget, tutorial: false) else { continue }
            return MushroomWeatherFixture(level: level, winning: winning, actions: known)
        }
        return nil
    }
}
