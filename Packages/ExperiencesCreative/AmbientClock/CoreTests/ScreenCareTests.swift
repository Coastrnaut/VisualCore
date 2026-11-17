// ScreenCareTests — feature 134 (A18-P04) T-A18-403 (FR-A18-406; SC-A18-404; clarification Q3). contracts/power.md
// "Drift" and "Dim": the drift stays within 8 points over a day sampled every 60 s, moves at most 6 points per minute,
// is deterministic and is zero under reduced motion; the idle dim is 1 at 599 s, 0.6 at 600 s and 1 after a new action.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct ScreenCareTests {
    @Test func theConstantsAreTheDocumentedValues() {
        #expect(ScreenCare.amplitude == 8)
        #expect(ScreenCare.periodX == 600)
        #expect(ScreenCare.periodY == 840)
        #expect(ScreenCare.idleInterval == 600)
        #expect(ScreenCare.idleDim == 0.6)
    }

    @Test func theDriftIsBoundedAndSlowOverADay() {
        var previous = ScreenCare.drift(at: 0, reduceMotion: false)
        var largest = 0.0
        for sample in 1...1440 {
            let offset = ScreenCare.drift(at: Double(sample) * 60, reduceMotion: false)
            #expect(abs(offset.x) <= 8 && abs(offset.y) <= 8, "\(sample)")
            #expect(abs(offset.x - previous.x) <= 6 && abs(offset.y - previous.y) <= 6, "\(sample)")
            largest = max(largest, abs(offset.x), abs(offset.y))
            previous = offset
        }
        #expect(largest > 7, "the drift actually moves")
    }

    @Test func theDriftIsDeterministicAndZeroUnderReducedMotion() {
        for t in [0.0, 37.5, 150, 1_234.25, 86_399] {
            #expect(ScreenCare.drift(at: t, reduceMotion: false) == ScreenCare.drift(at: t, reduceMotion: false))
            #expect(ScreenCare.drift(at: t, reduceMotion: true) == .zero)
        }
        let quarter = ScreenCare.drift(at: 150, reduceMotion: false)
        #expect(abs(quarter.x - 8) < 1e-9)
        #expect(ScreenCare.drift(at: .nan, reduceMotion: false) == .zero)
    }

    @Test func theIdleDimStartsAtSixHundredSecondsAndANewActionRestoresIt() {
        let action = 1_000.0
        #expect(ScreenCare.dimFactor(now: action + 599, lastAction: action) == 1)
        #expect(ScreenCare.dimFactor(now: action + 600, lastAction: action) == 0.6)
        #expect(ScreenCare.dimFactor(now: action + 5_000, lastAction: action) == 0.6)
        let newAction = action + 700
        #expect(ScreenCare.dimFactor(now: newAction, lastAction: newAction) == 1)
        #expect(ScreenCare.dimFactor(now: newAction + 1, lastAction: newAction) == 1)
    }
}
