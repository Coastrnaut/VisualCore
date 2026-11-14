// AnalysisDisplayTests — feature 048 (A06-P02) T-A06-205 (FR-A06-210, FR-A06-212; data-model "AnalysisDisplay",
// research D6). The display mapping of VisualCore Music Lab, host-free and short: the −80…0 dB height map with its
// clamps and NaN, the bar count, the level words at their edges, the beat clamp and threshold, and the silent display.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct AnalysisDisplayTests {
    @Test func theHeightMapsMinusEightyToZeroLinearlyAndClamps() {
        #expect(AnalysisDisplay.floorDB == -80)
        #expect(AnalysisDisplay.height(dB: -120) == 0)
        #expect(AnalysisDisplay.height(dB: -80) == 0)
        #expect(AnalysisDisplay.height(dB: -40) == 0.5)
        #expect(AnalysisDisplay.height(dB: 0) == 1)
        #expect(AnalysisDisplay.height(dB: 6) == 1)
        #expect(AnalysisDisplay.height(dB: .nan) == 0)
    }

    @Test func oneBarIsDrawnPerBandWithTheMappedHeights() {
        for count in [0, 1, 8, 16, 32] {
            let display = AnalysisDisplay(
                bandDB: Array(repeating: -40, count: count), rmsDB: -40, peakDB: 0, beat: 0)
            #expect(display.bars.count == count)
            #expect(display.bars.allSatisfy { $0 == 0.5 })
        }
        let display = AnalysisDisplay(bandDB: [-120, -80, -40, 0, 6, .nan], rmsDB: -40, peakDB: 0, beat: 0.25)
        #expect(display.bars == [0, 0, 0.5, 1, 1, 0])
        #expect(display.level == 0.5)
        #expect(display.peakMark == 1)
        #expect(display.beat == 0.25)
    }

    @Test func theLevelWordsFollowTheThresholds() {
        #expect(LevelWord.quietBelowDB == -40)
        #expect(LevelWord.mediumBelowDB == -20)
        #expect(LevelWord.from(rmsDB: -41) == .quiet)
        #expect(LevelWord.from(rmsDB: -40) == .medium)
        #expect(LevelWord.from(rmsDB: -21) == .medium)
        #expect(LevelWord.from(rmsDB: -20) == .loud)
        #expect(LevelWord.from(rmsDB: -5) == .loud)
        #expect(LevelWord.from(rmsDB: .nan) == .quiet)
        #expect(LevelWord.quiet.rawValue == "quiet")
        #expect(LevelWord.medium.rawValue == "medium")
        #expect(LevelWord.loud.rawValue == "loud")
    }

    @Test func theBeatIsClampedAndCountsOnlyAboveOneHalf() {
        func display(beat: Float) -> AnalysisDisplay {
            AnalysisDisplay(bandDB: [], rmsDB: -80, peakDB: -80, beat: beat)
        }
        #expect(AnalysisDisplay.beatThreshold == 0.5)
        #expect(display(beat: -1).beat == 0)
        #expect(display(beat: 2).beat == 1)
        #expect(display(beat: .nan).beat == 0)
        #expect(display(beat: .nan).isBeat == false)
        #expect(display(beat: 0.5).isBeat == false)
        #expect(display(beat: 0.51).isBeat == true)
        #expect(display(beat: 2).isBeat == true)
    }

    @Test func theSilentDisplayIsAllZero() {
        let silent = AnalysisDisplay.silent(bandCount: 16)
        #expect(silent.bars.count == 16)
        #expect(silent.bars.allSatisfy { $0 == 0 })
        #expect(silent.level == 0)
        #expect(silent.peakMark == 0)
        #expect(silent.beat == 0)
        #expect(silent.isBeat == false)
        #expect(AnalysisDisplay.silent(bandCount: 0).bars.isEmpty)
    }
}
