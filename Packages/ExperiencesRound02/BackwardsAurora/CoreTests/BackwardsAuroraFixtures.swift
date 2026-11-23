// BackwardsAuroraFixtures — feature 391 (R02-G10-01) T-R02G1001-002 (SC-R02G1001-001 … 005). Seeded test levels shared
// by the Backwards Aurora kernel tests. Deterministic: `SeededRandom`, no clock. Fixture seed 2_391.
//
// `fixture(_:)` builds a level backwards from its true wave: a gently curving target (each step's slope changes by at
// most 3), the bend limit L at the target's worst bend (so the target is smooth), then 1 … 4 reversals of sections that
// are not palindromes applied to the target to give the opening wave. Played forwards in the opposite order, the same
// reversals restore the target. The breaking limit B is at least the largest seam bend met on that path (so the known
// reversals never tear) and the checkpoints are chosen so that neither the opening wave nor any wave before the last
// known reversal wins: the level is won exactly on the last known reversal. The budget is the number of reversals plus
// 0 … 3.
import Foundation
import VisualCoreSimulation
@testable import BackwardsAuroraCore

/// A fixture level with its known winning reversals.
struct BackwardsAuroraFixture {
    /// The level.
    let level: BackwardsAuroraLevel
    /// The winning reversals as sections (start, end), in playing order; the last one wins.
    let sections: [(start: Int, end: Int)]
    /// The waves after each known reversal (the last is the target).
    let waves: [BackwardsAuroraWave]
}

enum BackwardsAuroraFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_391

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> BackwardsAuroraFixture {
        var random = SeededRandom(seed: seed)
        for _ in 0..<512 {
            if let fixture = attempt(seed, &random) { return fixture }
        }
        preconditionFailure("fixture \(seed): no level after 512 attempts")
    }

    /// One attempt at a fixture of seed `seed`; nil when the drawn values do not make a valid level.
    static func attempt(_ seed: UInt64, _ random: inout SeededRandom) -> BackwardsAuroraFixture? {
        let count: Int = random.int(BackwardsAuroraWave.lengthRange)
        var samples: [Int] = []
        var height: Int = random.int(-40...40)
        var slope: Int = random.int(-4...4)
        for _ in 0..<count {
            samples.append(min(max(height, -64), 64))
            slope = min(max(slope + random.int(-3...3), -8), 8)
            height += slope
        }
        guard let target = try? BackwardsAuroraWave(samples) else { return nil }
        let bendLimit: Int = max(1, target.worstBend)
        guard BackwardsAuroraLevel.bendLimits.contains(bendLimit) else { return nil }
        let shortest: Int = random.int(2...4)
        let longest: Int = random.int(max(shortest, 6)...count)
        let wanted: Int = random.int(1...4)
        // Backwards from the target: each reversal is undone by playing the same section forwards.
        var wave: BackwardsAuroraWave = target
        var backwards: [(start: Int, end: Int)] = []
        var tries: Int = 0
        while backwards.count < wanted && tries < 64 {
            tries += 1
            let length: Int = random.int(shortest...longest)
            let start: Int = random.int(0...(count - length))
            let end: Int = start + length - 1
            if wave.isPalindrome(start: start, end: end) { continue }
            wave = wave.reversed(start: start, end: end)
            backwards.append((start: start, end: end))
        }
        guard !backwards.isEmpty else { return nil }
        let opening: BackwardsAuroraWave = wave
        let sections: [(start: Int, end: Int)] = backwards.reversed()
        var waves: [BackwardsAuroraWave] = []
        var breaking: Int = bendLimit
        var current: BackwardsAuroraWave = opening
        for section in sections {
            current = current.reversed(start: section.start, end: section.end)
            for k in BackwardsAuroraWave.seams(start: section.start, end: section.end, count: count) {
                breaking = max(breaking, abs(current.bend(at: k)))
            }
            waves.append(current)
        }
        guard current == target else { return nil }
        breaking = min(breaking + random.int(0...4), BackwardsAuroraLevel.maximumBreakingLimit)
        guard breaking >= bendLimit, breaking <= BackwardsAuroraLevel.maximumBreakingLimit else { return nil }
        // Checkpoints: preferably where the opening wave differs from the target, then anywhere.
        let differing: [Int] = (0..<count).filter { opening.samples[$0] != target.samples[$0] }
        guard !differing.isEmpty else { return nil }
        let wantedCheckpoints: Int = random.int(BackwardsAuroraLevel.checkpointCounts)
        var checkpoints: Set<Int> = [differing[random.int(0...(differing.count - 1))]]
        while checkpoints.count < wantedCheckpoints {
            checkpoints.insert(random.int(0...1) == 0 && !differing.isEmpty
                               ? differing[random.int(0...(differing.count - 1))] : random.int(0...(count - 1)))
            if checkpoints.count >= min(wantedCheckpoints, count) { break }
        }
        let positions: [Int] = checkpoints.sorted()
        guard BackwardsAuroraLevel.checkpointCounts.contains(positions.count) else { return nil }
        // No wave before the last known reversal may win.
        for earlier in [opening] + waves.dropLast() where BackwardsAuroraLevel.wins(
            earlier, target: target, checkpoints: positions, bendLimit: bendLimit) {
            return nil
        }
        let budget: Int = sections.count + random.int(0...3)
        guard let level = try? BackwardsAuroraLevel(
            id: "fixture-\(seed)", seed: seed, difficulty: 1 + Int(seed % 5), opening: opening, target: target,
            checkpoints: positions, bendLimit: bendLimit, breakingLimit: breaking, shortest: shortest,
            longest: longest, budget: budget, tutorial: seed % 7 == 0) else { return nil }
        return BackwardsAuroraFixture(level: level, sections: sections, waves: waves)
    }

    /// The fixtures of seeds `seed + 1 … seed + count`.
    static func fixtures(_ count: Int, seed: UInt64 = seed) -> [BackwardsAuroraFixture] {
        var result: [BackwardsAuroraFixture] = []
        for offset in 1...count { result.append(fixture(seed &+ UInt64(offset))) }
        return result
    }
}
