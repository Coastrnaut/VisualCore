// DifficultyTests — feature 076 (A10-P02) T-A10-202 (FR-A10-203; clarification 3; research D2; SC-A10-202). The
// difficulty ramp, host-free and short: the values per level (fall speed (3 + 0.2 L)…min(5, 3.6 + 0.2 L), spawn gap
// max(20, 40 − 2.5 L) rounded down, orb multiplier 1 + L / 2); from wave to wave the speeds and the density never
// decrease and the multiplier never falls; from wave 9 on every value stays at the ceiling; the capsule speed bound
// (A10-P01 research D3) holds at the ceiling; waves below 1 count as wave 1.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct DifficultyTests {
    @Test func theValuesFollowTheRamp() {
        let levels = (1...9).map { Difficulty(wave: $0) }
        #expect(levels.map(\.level) == Array(0...8))
        #expect(levels.map(\.spawnGap) == [40, 37, 35, 32, 30, 27, 25, 22, 20])
        #expect(levels.map(\.orbMultiplier) == [1, 1, 2, 2, 3, 3, 4, 4, 5])
        for d in levels {
            let l = Double(d.level)
            #expect(abs(d.fallSpeed.lowerBound - (3 + 0.2 * l)) < 1e-12)
            #expect(abs(d.fallSpeed.upperBound - min(5, 3.6 + 0.2 * l)) < 1e-12)
        }
        #expect(Difficulty(wave: 1).fallSpeed == 3.0...3.6)
        #expect(abs(Difficulty.ceiling.fallSpeed.lowerBound - 4.6) < 1e-12)
        #expect(Difficulty.ceiling.fallSpeed.upperBound == 5)
        #expect(Difficulty.ceilingLevel == 8 && Difficulty.ceiling.wave == 9)
    }

    @Test func difficultyNeverFallsAndStopsAtTheCeiling() {
        var previous = Difficulty(wave: 1)
        for wave in 2...200 {
            let d = Difficulty(wave: wave)
            #expect(d.wave == wave)
            #expect(d.fallSpeed.lowerBound >= previous.fallSpeed.lowerBound)
            #expect(d.fallSpeed.upperBound >= previous.fallSpeed.upperBound)
            #expect(d.spawnGap <= previous.spawnGap)
            #expect(d.orbMultiplier >= previous.orbMultiplier)
            #expect(d.level <= Difficulty.ceilingLevel && d.spawnGap >= Difficulty.minSpawnGap)
            #expect(d.fallSpeed.upperBound <= Difficulty.maxFallSpeed)
            if wave >= 9 {
                #expect(d.level == 8 && d.fallSpeed == Difficulty.ceiling.fallSpeed && d.spawnGap == 20
                        && d.orbMultiplier == 5)
            }
            previous = d
        }
    }

    @Test func theCapsuleSpeedBoundHoldsAtTheCeiling() {
        let perStep = Difficulty.ceiling.fallSpeed.upperBound * GameSimulation.step
        #expect(perStep < 0.6)                         // the smallest summed radius: bar 0.2 + player 0.4
        #expect(abs(perStep - 5.0 / 60) < 1e-12)
        #expect(GameSimulation.fallSpeedRange.upperBound == Difficulty.maxFallSpeed)
    }

    @Test func wavesBelowOneCountAsWaveOne() {
        #expect(Difficulty(wave: 0) == Difficulty(wave: 1))
        #expect(Difficulty(wave: -5) == Difficulty(wave: 1))
    }
}
