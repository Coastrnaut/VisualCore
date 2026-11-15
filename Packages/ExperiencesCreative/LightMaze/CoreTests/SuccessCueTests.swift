// SuccessCueTests — feature 099 (A13-P04) T-A13-404 (FR-A13-420, FR-A13-421; clarification Q3; research D5;
// data-model "SuccessCue"). The success cue rules, host-free and short: sampled every 0.05 s from 0 to 0.75 s the
// border brightness rises and falls exactly once, never above the peak, and is 1 at 0 and from 0.6 s on; under Reduce
// Motion and under Reduce Flashing every sample is exactly 1; a negative or non-finite elapsed time gives 1; the solve
// words name the level, the moves (singular for 1) and the opened level only when one opened; the sound parameters lie
// within VisualCore's sound effect limits (checked numerically, no audio import).
import Foundation
import LightMazeCore
import Testing

@Suite struct SuccessCueTests {
    private func samples(reduceMotion: Bool, reduceFlashing: Bool) -> [(Double, Double)] {
        var result: [(Double, Double)] = []
        for step in 0...15 {
            let time: Double = Double(step) * 0.05
            result.append((time, SuccessCue.brightness(elapsed: time, reduceMotion: reduceMotion,
                                                       reduceFlashing: reduceFlashing)))
        }
        return result
    }

    @Test func brightnessRisesAndFallsOnce() {
        let values: [(Double, Double)] = samples(reduceMotion: false, reduceFlashing: false)
        var signChanges = 0
        var lastSign = 0
        for index in 1..<values.count {
            let difference: Double = values[index].1 - values[index - 1].1
            let sign: Int = difference > 0 ? 1 : (difference < 0 ? -1 : 0)
            if sign != 0 {
                if lastSign != 0 && sign != lastSign { signChanges += 1 }
                lastSign = sign
            }
        }
        #expect(signChanges == 1, "one rise and one fall")
        for (time, value) in values {
            #expect(value >= 1 && value <= SuccessCue.peak, "t = \(time)")
            if time >= SuccessCue.duration - 1e-9 {
                #expect(value == 1, "settled at t = \(time)")
            }
        }
        #expect(values[0].1 == 1, "starts at 1")
        let highest: Double = values.map { $0.1 }.max() ?? 0
        #expect(highest > 1.4 && highest <= SuccessCue.peak)
        #expect(SuccessCue.duration == 0.6 && SuccessCue.peak == 1.5)
    }

    @Test func reduceMotionAndReduceFlashingKeepTheBorderStatic() {
        for (time, value) in samples(reduceMotion: true, reduceFlashing: false) {
            #expect(value == 1, "reduce motion, t = \(time)")
        }
        for (time, value) in samples(reduceMotion: false, reduceFlashing: true) {
            #expect(value == 1, "reduce flashing, t = \(time)")
        }
        for (time, value) in samples(reduceMotion: true, reduceFlashing: true) {
            #expect(value == 1, "both, t = \(time)")
        }
    }

    @Test func invalidElapsedGivesOne() {
        #expect(SuccessCue.brightness(elapsed: -0.1, reduceMotion: false, reduceFlashing: false) == 1)
        #expect(SuccessCue.brightness(elapsed: .nan, reduceMotion: false, reduceFlashing: false) == 1)
        #expect(SuccessCue.brightness(elapsed: .infinity, reduceMotion: false, reduceFlashing: false) == 1)
    }

    @Test func solveWords() {
        #expect(SuccessCue.words(levelNumber: 3, moves: 5, nextOpened: true, isLast: false)
                == "Level 3 solved in 5 moves. Level 4 is open.")
        #expect(SuccessCue.words(levelNumber: 3, moves: 1, nextOpened: true, isLast: false)
                == "Level 3 solved in 1 move. Level 4 is open.")
        #expect(SuccessCue.words(levelNumber: 20, moves: 7, nextOpened: true, isLast: true)
                == "Level 20 solved in 7 moves.")
        #expect(SuccessCue.words(levelNumber: 4, moves: 2, nextOpened: false, isLast: false)
                == "Level 4 solved in 2 moves.")
    }

    @Test func soundParametersWithinSoundEffectLimits() {
        for frequency in [SuccessCue.soundStartFrequency, SuccessCue.soundEndFrequency] {
            #expect(frequency >= 40 && frequency <= 4000, "frequency \(frequency)")
        }
        #expect(SuccessCue.soundStartFrequency == 660 && SuccessCue.soundEndFrequency == 990)
        #expect(SuccessCue.soundDuration >= 0.02 && SuccessCue.soundDuration <= 1)
        #expect(SuccessCue.soundGain >= 0 && SuccessCue.soundGain <= 0.9)
        #expect(SuccessCue.soundAttack >= 0.002 && SuccessCue.soundRelease >= 0.002)
        #expect(SuccessCue.soundAttack + SuccessCue.soundRelease <= SuccessCue.soundDuration)
    }
}
