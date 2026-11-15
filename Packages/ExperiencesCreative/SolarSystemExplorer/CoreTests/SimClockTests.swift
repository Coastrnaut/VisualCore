// SimClockTests — feature 106 (A14-P04) T-A14-404 (FR-A14-401, FR-A14-402; SC-A14-401, SC-A14-402; clarification Q1).
// The simulated clock, host-free and short: from day 0, N = 120 and 1,200 accumulated steps add rate × N / 120 days
// within 1e-9 at each rate; a step past either end clamps to it and stops, and a step from the upper end stops there;
// an invalid rate index moves nothing and does not stop; four rates with four labels; the date label with its time.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SimClockTests {
    @Test func ratesLabelsAndConstants() {
        #expect(SimClock.rates == [1, 7, 30, 365])
        #expect(SimClock.rateLabels.count == 4)
        #expect(SimClock.rateLabels == ["1 day/s", "1 week/s", "1 month/s", "1 year/s"])
        #expect(SimClock.stepSeconds == 1.0 / 120)
        #expect(SimClock.endOfRange == "end-of-range")
        #expect(SimClock.stopSentence == "The model's range ends here")
    }

    @Test func accumulatedStepsAddExactlyRateTimesStepsOver120() {
        let counts: [Int] = [120, 1_200]
        for rateIndex in 0..<SimClock.rates.count {
            for count in counts {
                var day: Double = 0
                var stoppedAny = false
                for _ in 0..<count {
                    let result = SimClock.advance(dayOffset: day, rateIndex: rateIndex)
                    day = result.dayOffset
                    if result.stopped { stoppedAny = true }
                }
                let expected: Double = SimClock.rates[rateIndex] * Double(count) / 120
                #expect(abs(day - expected) <= 1e-9, "rate \(rateIndex), \(count) steps: \(day) vs \(expected)")
                #expect(!stoppedAny, "rate \(rateIndex), \(count) steps")
            }
        }
    }

    @Test func aStepPastTheUpperEndClampsAndStops() {
        let upper: Double = SimulatedDate.range.upperBound
        let near = SimClock.advance(dayOffset: upper - 1, rateIndex: 3)
        #expect(near.dayOffset == upper)
        #expect(near.stopped)
        let atEnd = SimClock.advance(dayOffset: upper, rateIndex: 0)
        #expect(atEnd.dayOffset == upper)
        #expect(atEnd.stopped)
        let justInside = SimClock.advance(dayOffset: upper - 1, rateIndex: 0)
        #expect(justInside.dayOffset == upper - 1 + 1.0 / 120)
        #expect(!justInside.stopped)
    }

    @Test func aDayBelowTheLowerEndClampsAndStops() {
        let lower: Double = SimulatedDate.range.lowerBound
        let below = SimClock.advance(dayOffset: lower - 10, rateIndex: 0)
        #expect(below.dayOffset == lower)
        #expect(below.stopped)
        let fromLower = SimClock.advance(dayOffset: lower, rateIndex: 0)
        #expect(fromLower.dayOffset == lower + 1.0 / 120)
        #expect(!fromLower.stopped)
    }

    @Test func anInvalidRateIndexMovesNothing() {
        let indices: [Int] = [-1, 4, 99]
        for index in indices {
            let result = SimClock.advance(dayOffset: 12.5, rateIndex: index)
            #expect(result.dayOffset == 12.5, "index \(index)")
            #expect(!result.stopped, "index \(index)")
            #expect(SimClock.daysPerStep(rateIndex: index) == nil)
        }
    }

    @Test func theDateLabelShowsTheUTCTime() throws {
        #expect(SimulatedDate.j2000.labelWithTime == "2000-01-01 12:00 UTC")
        let newYear2025: SimulatedDate = try #require(SimulatedDate(dayOffset: 9_132))
        #expect(newYear2025.labelWithTime == "2025-01-01 12:00 UTC")
        let start: SimulatedDate = try #require(SimulatedDate(dayOffset: SimulatedDate.range.lowerBound))
        #expect(start.labelWithTime == "1950-01-01 00:00 UTC")
        var day: Double = 0
        for _ in 0..<120 { day = SimClock.advance(dayOffset: day, rateIndex: 0).dayOffset }
        let oneDayLater: SimulatedDate = try #require(SimulatedDate(dayOffset: day))
        #expect(oneDayLater.labelWithTime == "2000-01-02 12:00 UTC")
    }
}
