// HarmonicBridgesFixtures — feature 411 (R02-G12-01) T-R02G1201-002 (SC-R02G1201-001 … 005). Seeded test levels shared
// by the Harmonic Bridges kernel tests. Deterministic: `SeededRandom`, no clock. Fixture seed 2_411.
//
// `fixture(_:)` draws 2 … 8 islands on distinct grid positions, a start and a distinct goal, and a path of 1 … 3 strings
// from the start to the goal through distinct islands, then extra strings on unused pairs up to 1 … 12 strings in all,
// shuffled into a random order. Each path string gets a target peg p and, in every step of the 1 … 4 step crossing
// window, a tone that resonates it in mode 1 or mode 5 at p (F = n · p / L), whose swing is never 0 at any sample; the
// steps are filled with further random tones of distinct frequencies (extra tones only add swing). The threshold is
// drawn between 1 and the smallest swing of any path string in any step, so at the target pegs every path string is a
// bridge in every step and the goal is reached in every step. The starting pegs scramble at least one path string to
// another peg (scrambled path strings are never locked; extra strings and unscrambled path strings may be), and an
// attempt is kept only when the starting pegs do not reach the goal in every step. The known winning actions are the
// tunings of every string whose starting peg differs from its target peg, in string order, followed by a test; the
// budget is that count + 1 + 0 … 5, so the known actions always win on the test.
import Foundation
import VisualCoreSimulation
@testable import HarmonicBridgesCore

/// A fixture level with its known winning actions.
struct HarmonicBridgesFixture {
    /// The level, with its starting pegs.
    let level: HarmonicBridgesLevel
    /// The known tunings, in string order; a test after them wins.
    let winningActions: [(string: Int, peg: Int)]
    /// The pegs after the known tunings, one per string.
    let winningPegs: [Int]
    /// The strings of the known path from the start to the goal (bridges in every step at the winning pegs).
    let path: [Int]
}

enum HarmonicBridgesFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_411

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> HarmonicBridgesFixture {
        var random = SeededRandom(seed: seed)
        for _ in 0..<512 {
            if let fixture = attempt(seed, &random) { return fixture }
        }
        preconditionFailure("fixture \(seed): no level after 512 attempts")
    }

    /// The fixtures of seeds `seed` … `seed + count − 1`.
    static func fixtures(_ count: Int, from seed: UInt64 = seed) -> [HarmonicBridgesFixture] {
        var result: [HarmonicBridgesFixture] = []
        for offset in 0..<UInt64(count) { result.append(fixture(seed &+ offset)) }
        return result
    }

    /// A random element of `values` (not empty).
    static func pick<T>(_ values: [T], _ random: inout SeededRandom) -> T {
        values[random.int(0...(values.count - 1))]
    }

    /// The (peg, mode) pairs with mode 1 or 5 that a string of `length` can be tuned to resonate, with their frequency.
    static func edgeModes(length: Int) -> [(peg: Int, mode: Int, frequency: Int)] {
        var result: [(peg: Int, mode: Int, frequency: Int)] = []
        for peg in 1...12 {
            for mode in [1, 5] where (mode * peg) % length == 0 {
                result.append((peg, mode, mode * peg / length))
            }
        }
        return result
    }

    /// One attempt at a fixture of seed `seed`; nil when the drawn values do not make a usable level.
    static func attempt(_ seed: UInt64, _ random: inout SeededRandom) -> HarmonicBridgesFixture? {
        let islandCount: Int = random.int(2...8)
        var islands: [HarmonicBridgesIsland] = []
        var used: Set<Int> = []
        while islands.count < islandCount {
            let x: Int = random.int(0...15)
            let y: Int = random.int(0...9)
            if used.insert(y * 16 + x).inserted { islands.append(HarmonicBridgesIsland(x: x, y: y)) }
        }
        let start: Int = random.int(0...(islandCount - 1))
        var goal: Int = random.int(0...(islandCount - 2))
        if goal >= start { goal += 1 }
        // The path: start, 0 … 2 distinct intermediate islands, goal.
        var others: [Int] = []
        for island in 0..<islandCount where island != start && island != goal { others.append(island) }
        let middle: Int = min(random.int(0...2), others.count)
        var route: [Int] = [start]
        for _ in 0..<middle { route.append(others.remove(at: random.int(0...(others.count - 1)))) }
        route.append(goal)
        // Strings: (a, b, isPath).
        var pairs: [(a: Int, b: Int, path: Bool)] = []
        var taken: Set<Int> = []
        for i in 0..<(route.count - 1) {
            let a: Int = min(route[i], route[i + 1])
            let b: Int = max(route[i], route[i + 1])
            taken.insert(a * 16 + b)
            pairs.append((a, b, true))
        }
        let maxPairs: Int = islandCount * (islandCount - 1) / 2
        let total: Int = random.int(pairs.count...min(12, maxPairs))
        var tries: Int = 0
        while pairs.count < total && tries < 200 {
            tries += 1
            let u: Int = random.int(0...(islandCount - 1))
            let v: Int = random.int(0...(islandCount - 1))
            guard u != v else { continue }
            let a: Int = min(u, v)
            let b: Int = max(u, v)
            if taken.insert(a * 16 + b).inserted { pairs.append((a, b, false)) }
        }
        // Shuffle the string order (Fisher-Yates).
        var i: Int = pairs.count - 1
        while i > 0 {
            let j: Int = random.int(0...i)
            pairs.swapAt(i, j)
            i -= 1
        }
        // Lengths and target pegs; path strings tuned to resonate in mode 1 or 5.
        var lengths: [Int] = []
        var targets: [Int] = []
        var options: [[(peg: Int, mode: Int, frequency: Int)]] = []
        for pair in pairs {
            let length: Int = random.int(1...6)
            lengths.append(length)
            if pair.path {
                let peg: Int = pick(edgeModes(length: length), &random).peg
                targets.append(peg)
                var choices: [(peg: Int, mode: Int, frequency: Int)] = []
                for option in edgeModes(length: length) where option.peg == peg { choices.append(option) }
                options.append(choices)
            } else {
                targets.append(random.int(1...12))
                options.append([])
            }
        }
        // Steps: one resonating tone per path string (shared frequencies are reused), then random extra tones.
        let stepCount: Int = random.int(1...4)
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<stepCount {
            var tones: [HarmonicBridgesTone] = []
            var heard: Set<Int> = []
            for index in 0..<pairs.count where pairs[index].path {
                let option: (peg: Int, mode: Int, frequency: Int) = pick(options[index], &random)
                if heard.insert(option.frequency).inserted {
                    tones.append(HarmonicBridgesTone(frequency: option.frequency, strength: random.int(1...3)))
                }
            }
            let wanted: Int = max(tones.count, random.int(1...3))
            var extra: Int = 0
            while tones.count < wanted && extra < 50 {
                extra += 1
                let frequency: Int = random.int(1...72)
                if heard.insert(frequency).inserted {
                    tones.append(HarmonicBridgesTone(frequency: frequency, strength: random.int(1...3)))
                }
            }
            steps.append(tones)
        }
        // The threshold: 1 … the smallest swing of a path string at its target peg over every step.
        var smallest: Int = Int.max
        for index in 0..<pairs.count where pairs[index].path {
            let string = HarmonicBridgesString(a: pairs[index].a, b: pairs[index].b, length: lengths[index],
                                               peg: targets[index])
            for (step, tones) in steps.enumerated() {
                let resonance = HarmonicBridgesResonance(string: string, index: index, step: step, tones: tones,
                                                         peg: targets[index], threshold: 1)
                for value in resonance.swing { smallest = min(smallest, value) }
            }
        }
        guard smallest >= 1 else { return nil }
        let threshold: Int = random.int(1...min(smallest, 12))
        // Starting pegs: scramble path strings (at least one); lock some unscrambled strings.
        var starting: [Int] = targets
        var scrambled: [Bool] = Array(repeating: false, count: pairs.count)
        var pathIndices: [Int] = []
        for index in 0..<pairs.count where pairs[index].path { pathIndices.append(index) }
        let forced: Int = pick(pathIndices, &random)
        for index in pathIndices where index == forced || random.int(0...1) == 0 {
            var peg: Int = random.int(1...11)
            if peg >= targets[index] { peg += 1 }
            starting[index] = peg
            scrambled[index] = true
        }
        var strings: [HarmonicBridgesString] = []
        for index in 0..<pairs.count {
            let locked: Bool = !scrambled[index] && random.int(0...3) == 0
            strings.append(HarmonicBridgesString(a: pairs[index].a, b: pairs[index].b, length: lengths[index],
                                                 peg: starting[index], locked: locked))
        }
        var actions: [(string: Int, peg: Int)] = []
        for index in 0..<pairs.count where starting[index] != targets[index] { actions.append((index, targets[index])) }
        let budget: Int = actions.count + 1 + random.int(0...5)
        guard let level = try? HarmonicBridgesLevel(
            id: "fixture-\(seed)", seed: seed, difficulty: random.int(1...5), islands: islands, strings: strings,
            start: start, goal: goal, steps: steps, threshold: threshold, budget: budget,
            tutorial: random.int(0...3) == 0) else { return nil }
        guard level.report(pegs: targets).goalReachedInEveryStep else { return nil }
        guard !level.report(pegs: level.startingPegs).goalReachedInEveryStep else { return nil }
        return HarmonicBridgesFixture(level: level, winningActions: actions, winningPegs: targets,
                                      path: pathIndices)
    }

    /// A hand-made level for exact cases: islands 0 … 3, start 0, goal 3, threshold `threshold` (default 2), budget 6.
    ///
    ///     string 0: island 0 to island 1, length 1, peg 2
    ///     string 1: island 1 to island 3, length 2, peg 4
    ///     string 2: island 0 to island 2, length 3, peg 3
    ///     string 3: island 2 to island 3, length 1, peg 5
    ///     step 0: tone 2 (strength 2)              step 1: tones 1 and 3 (strength 1 each)
    ///
    /// Step 0: strings 0 and 1 resonate in mode 1 (swing 2 6 8 6 2, bridges); string 2 in mode 2 (6 6 0 6 6, not a
    /// bridge); string 3 not at all. The start reaches islands 0, 1 and 3. Step 1: string 2 resonates in modes 1 and 3
    /// (5 3 8 3 5, a bridge); nothing else resonates; the start reaches islands 0 and 2, the goal is missed and the
    /// broken string is string 0 (the lowest-index string across the cut). Tuning string 3 to peg 1 makes it resonate
    /// in modes 1 and 3 in step 1 and wins.
    static func handLevel(threshold: Int = 2, budget: Int = 6, tutorial: Bool = false,
                          lockedLast: Bool = false) -> HarmonicBridgesLevel {
        do {
            return try HarmonicBridgesLevel(
                id: "hand", seed: 1, difficulty: 1,
                islands: [HarmonicBridgesIsland(x: 1, y: 5), HarmonicBridgesIsland(x: 5, y: 2),
                          HarmonicBridgesIsland(x: 5, y: 8), HarmonicBridgesIsland(x: 10, y: 5)],
                strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 2),
                          HarmonicBridgesString(a: 1, b: 3, length: 2, peg: 4),
                          HarmonicBridgesString(a: 0, b: 2, length: 3, peg: 3),
                          HarmonicBridgesString(a: 2, b: 3, length: 1, peg: 5, locked: lockedLast)],
                start: 0, goal: 3,
                steps: [[HarmonicBridgesTone(frequency: 2, strength: 2)],
                        [HarmonicBridgesTone(frequency: 1, strength: 1), HarmonicBridgesTone(frequency: 3, strength: 1)]],
                threshold: threshold, budget: budget, tutorial: tutorial)
        } catch {
            preconditionFailure("the hand level is valid: \(error)")
        }
    }
}
