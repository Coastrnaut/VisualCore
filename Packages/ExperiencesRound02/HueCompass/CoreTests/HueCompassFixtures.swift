// HueCompassFixtures — feature 331 (R02-G04-01) T-R02G0401-002 (SC-R02G0401-001 … 005). Seeded test levels with a known
// solution, shared by the Hue Compass kernel tests. A fixture draws the offset, the 96 fog densities, the target, the
// tolerances and the allowance at random, and a start bearing farther from the target than the bearing tolerance. Its
// known solution is: probe at the start, turn by the signed shortest step to the target (no turn when that is zero),
// then select the target bearing with the target's band. It needs two units, the smallest allowance. Deterministic: a
// SplitMix64 generator, no clock. Fixture seed 2_331.
import Foundation
@testable import HueCompassCore

/// A small deterministic generator (SplitMix64).
struct HueCompassRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}

/// A seeded level with its known solution.
struct HueCompassFixture {
    let level: HueCompassLevel
    let solution: [HueCompassAction]
}

enum HueCompassFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_331

    /// The signed shortest turn from `from` to `to`, −47 … 48 (48 for opposite bearings).
    static func shortestTurn(from: Int, to: Int) -> Int {
        let d: Int = ((to - from) % 96 + 96) % 96
        return d <= 48 ? d : d - 96
    }

    /// Fixture `index`: a deterministic level and its known solution.
    static func fixture(_ index: Int, tutorial: Bool = false) -> HueCompassFixture {
        var random = HueCompassRandom(seed: seed &+ UInt64(index) &* 7_919)
        let offset: Int = random.int(0...23)
        var fog: [Int] = []
        for _ in 0..<96 { fog.append(random.int(0...9)) }
        let target: Int = random.int(0...95)
        let bearingTolerance: Int = random.int(0...4)
        let bandTolerance: Int = random.int(0...2)
        let allowance: Int = random.int(2...24)
        var start: Int = random.int(0...95)
        while HueCompassWheel.bearingDistance(start, target) <= bearingTolerance { start = random.int(0...95) }
        let level: HueCompassLevel
        do {
            level = try HueCompassLevel(id: "fixture-\(index)", seed: seed &+ UInt64(index), band: 1 + index % 5,
                                        offset: offset, fog: fog, target: target, start: start,
                                        bearingTolerance: bearingTolerance, bandTolerance: bandTolerance,
                                        allowance: allowance, tutorial: tutorial)
        } catch {
            preconditionFailure("fixture \(index) is valid by construction: \(error)")
        }
        var solution: [HueCompassAction] = [.probe]
        let turn: Int = shortestTurn(from: start, to: target)
        if turn != 0 { solution.append(.turn(turn)) }
        solution.append(.select(bearing: target, band: level.targetBand))
        return HueCompassFixture(level: level, solution: solution)
    }
}
