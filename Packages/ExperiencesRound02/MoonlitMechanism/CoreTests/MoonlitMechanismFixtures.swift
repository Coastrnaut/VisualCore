// MoonlitMechanismFixtures — feature 431 (R02-G14-01) T-R02G1401-002 (SC-R02G1401-001 … 004). Seeded Moonlit Mechanism
// levels with known winning actions. A fixture draws a train (2 … 5 gears, each child meshing with a random lower-index
// parent, tooth counts 6 … 20 chosen so every mesh divisor is at least 2), blade patterns, depths, centres and slot
// tables (slot k of a T-tooth gear points one of eight compass directions, (8k) / T, with a ray of 2 … 3 cells starting
// one cell from the centre), a solution set-up (phases and lamp height) and 2 … 4 key frames whose targets are exactly
// the solution's casts (so the solution matches with no stray cell); the alignment values are those of the solution;
// forbidden cells are drawn from cells no solution key frame covers. The solution is scrambled by 1 … 5 random actions
// (turns, re-seats, lamp steps); the start is the scrambled set-up and the known actions are the inverse actions in
// reverse order followed by the run. A start that already wins is redrawn, so every fixture needs at least one action.
// `apply` is the fixtures' own step of an action on a set-up, independent of the play.
import Foundation
import VisualCoreSimulation
@testable import MoonlitMechanismCore

/// A seeded level with its known winning actions.
struct MoonlitMechanismFixture: Sendable {
    /// The level.
    let level: MoonlitMechanismLevel
    /// The known actions, ending with the run.
    let actions: [MoonlitMechanismAction]
    /// The solution set-up (phases).
    let solution: [Int]
    /// The solution lamp height.
    let solutionHeight: Int

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_431

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [MoonlitMechanismFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [MoonlitMechanismFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// The eight compass directions (column, row), rows downward.
    static let compass: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

    /// The set-up after `action` (`run` leaves it unchanged); nil when the action is refused.
    static func apply(_ action: MoonlitMechanismAction, gears: [MoonlitMechanismGear], phases: [Int], height: Int,
                      lampHeights: Int) -> (phases: [Int], height: Int)? {
        switch action {
        case .turn(let step):
            guard step == 1 || step == -1 else { return nil }
            return (MoonlitMechanismTrain.turned(gears, phases: phases, by: step), height)
        case .reseat(let gear, let step):
            guard gear >= 1, gear < gears.count, step == 1 || step == -1 else { return nil }
            var next: [Int] = phases
            next[gear] = MoonlitMechanismTrain.mod(phases[gear] + step, gears[gear].teeth)
            return (next, height)
        case .lamp(let step):
            guard step == 1 || step == -1, height + step >= 0, height + step < lampHeights else { return nil }
            return (phases, height + step)
        case .run:
            return (phases, height)
        }
    }

    /// The inverse of a set-up action.
    static func inverse(_ action: MoonlitMechanismAction) -> MoonlitMechanismAction {
        switch action {
        case .turn(let step): .turn(-step)
        case .reseat(let gear, let step): .reseat(gear, -step)
        case .lamp(let step): .lamp(-step)
        case .run: .run
        }
    }

    /// One fixture from `random`, or nil when the draw does not give a fair level.
    static func make(_ random: inout SeededRandom, index: Int) -> MoonlitMechanismFixture? {
        let width: Int = Int.random(in: 10...16, using: &random)
        let rows: Int = Int.random(in: 8...12, using: &random)
        let count: Int = Int.random(in: 2...5, using: &random)
        let lampHeights: Int = Int.random(in: 2...4, using: &random)
        let evenTeeth: [Int] = [6, 8, 10, 12, 14, 16, 18, 20]
        var teeth: [Int] = []
        var parents: [Int?] = []
        for i in 0..<count {
            teeth.append(evenTeeth[Int.random(in: 0..<evenTeeth.count, using: &random)])
            parents.append(i == 0 ? nil : Int.random(in: 0..<i, using: &random))
        }
        var solution: [Int] = []
        for t in teeth { solution.append(Int.random(in: 0..<t, using: &random)) }
        let solutionHeight: Int = Int.random(in: 0..<lampHeights, using: &random)
        var shape: [(blades: [Bool], depth: Int, centre: MoonlitMechanismCell, slots: [[MoonlitMechanismCell]])] = []
        for t in teeth {
            var blades: [Bool] = []
            for _ in 0..<t { blades.append(Int.random(in: 0..<3, using: &random) == 0) }
            blades[0] = true
            blades[t - 1] = false
            let depth: Int = Int.random(in: 1...3, using: &random)
            let centre = MoonlitMechanismCell(column: Int.random(in: 3..<(width - 3), using: &random),
                                              row: Int.random(in: 2..<(rows - 4), using: &random))
            var slots: [[MoonlitMechanismCell]] = []
            for k in 0..<t {
                let (dc, dr) = compass[(8 * k) / t]
                let length: Int = Int.random(in: 2...3, using: &random)
                var ray: [MoonlitMechanismCell] = []
                for step in 1...length { ray.append(MoonlitMechanismCell(column: dc * step, row: dr * step)) }
                slots.append(ray)
            }
            shape.append((blades, depth, centre, slots))
        }
        var gears: [MoonlitMechanismGear] = []
        for i in 0..<count {
            var alignment: Int = 0
            if let p = parents[i] {
                let g: Int = MoonlitMechanismTrain.gcd(teeth[p], teeth[i])
                alignment = MoonlitMechanismTrain.mod(solution[p] + solution[i], g)
            }
            gears.append(MoonlitMechanismGear(teeth: teeth[i], phase: solution[i], blades: shape[i].blades,
                                              depth: shape[i].depth, centre: shape[i].centre, parent: parents[i],
                                              alignment: alignment, slots: shape[i].slots))
        }
        let frameCount: Int = Int.random(in: 2...4, using: &random)
        var frames: [MoonlitMechanismKeyFrame] = []
        var turns: Int = Int.random(in: 0...2, using: &random)
        var covered: Set<Int> = []
        for f in 0..<frameCount {
            let at: [Int] = MoonlitMechanismTrain.turned(gears, phases: solution, by: turns)
            let cells: [Int] = MoonlitMechanismTrain.cast(gears, phases: at, height: solutionHeight, width: width,
                                                          rows: rows)
            guard !cells.isEmpty else { return nil }
            covered.formUnion(cells)
            frames.append(MoonlitMechanismKeyFrame(turns: turns, target: cells,
                                                   required: f == 0 || Int.random(in: 0..<4, using: &random) != 0))
            turns += Int.random(in: 1...5, using: &random)
        }
        var free: [Int] = []
        for cell in 0..<(width * rows) where !covered.contains(cell) { free.append(cell) }
        var forbidden: [Int] = []
        let forbiddenCount: Int = min(free.count, Int.random(in: 0...6, using: &random))
        for _ in 0..<forbiddenCount {
            let pick: Int = free.remove(at: Int.random(in: 0..<free.count, using: &random))
            forbidden.append(pick)
        }
        forbidden.sort()
        let allowance: Int = Int.random(in: 0...2, using: &random)
        var scramble: [MoonlitMechanismAction] = []
        var phases: [Int] = solution
        var height: Int = solutionHeight
        let scrambleCount: Int = Int.random(in: 1...5, using: &random)
        var tries: Int = 0
        while scramble.count < scrambleCount, tries < 50 {
            tries += 1
            let kind: Int = Int.random(in: 0..<3, using: &random)
            let step: Int = Bool.random(using: &random) ? 1 : -1
            let action: MoonlitMechanismAction
            switch kind {
            case 0: action = .turn(step)
            case 1: action = .reseat(Int.random(in: 1..<count, using: &random), step)
            default: action = .lamp(step)
            }
            guard let next = apply(action, gears: gears, phases: phases, height: height, lampHeights: lampHeights)
            else { continue }
            scramble.append(action)
            (phases, height) = next
        }
        guard !scramble.isEmpty else { return nil }
        var startGears: [MoonlitMechanismGear] = []
        for (i, gear) in gears.enumerated() {
            startGears.append(MoonlitMechanismGear(teeth: gear.teeth, phase: phases[i], blades: gear.blades,
                                                   depth: gear.depth, centre: gear.centre, parent: gear.parent,
                                                   alignment: gear.alignment, slots: gear.slots))
        }
        var actions: [MoonlitMechanismAction] = scramble.reversed().map(inverse)
        actions.append(.run)
        let budget: Int = min(40, actions.count + Int.random(in: 0...3, using: &random))
        guard let level = try? MoonlitMechanismLevel(
            id: "fixture-\(index)", seed: UInt64(index), difficulty: Int.random(in: 1...5, using: &random),
            gears: startGears, width: width, rows: rows, lampHeights: lampHeights, startingHeight: height,
            keyFrames: frames, forbidden: forbidden, allowance: allowance, budget: budget,
            tutorial: index % 7 == 0) else { return nil }
        guard level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won else { return nil }
        guard level.run(phases: solution, height: solutionHeight).outcome == .won else { return nil }
        return MoonlitMechanismFixture(level: level, actions: actions, solution: solution,
                                       solutionHeight: solutionHeight)
    }
}
