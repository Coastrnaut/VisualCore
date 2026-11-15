// SimulatedDateTests — feature 104 (A14-P02) T-A14-204 (FR-A14-211; clarification Q3; research D3; SC-A14-203). The
// simulated date, host-free and short: day 0 is J2000.0 labelled "2000-01-01"; 100 steps of +30 then 100 of −30 return
// exactly to 0 (and the same for ±1 and ±365); both range ends are accepted and one step beyond either is refused
// `a14.out-of-range` with nothing changed; a step outside {±1, ±30, ±365} is refused `a14.invalid-step`; labels are UTC
// calendar dates at the range ends.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SimulatedDateTests {
    /// `date` stepped by `days`, or nil when refused.
    private func step(_ date: SimulatedDate, _ days: Int) -> SimulatedDate? {
        switch date.stepped(by: days) {
        case .success(let next): return next
        case .failure: return nil
        }
    }

    /// The refusal of stepping `date` by `days`, or nil when accepted.
    private func refusal(_ date: SimulatedDate, _ days: Int) -> DateStepRefusal? {
        switch date.stepped(by: days) {
        case .success: return nil
        case .failure(let reason): return reason
        }
    }

    @Test func startIsJ2000LabelledFirstOfJanuary2000() {
        let start: SimulatedDate = SimulatedDate.j2000
        #expect(start.dayOffset == 0)
        #expect(start.label == "2000-01-01")
        #expect(start.date.timeIntervalSince1970 == 946_728_000)
        #expect(SimulatedDate.range == -18_262.5 ... 18_627.5)
        #expect(SimulatedDate.allowedSteps == [-365, -30, -1, 1, 30, 365])
    }

    @Test func hundredStepsForwardAndBackReturnExactly() throws {
        let sizes: [Int] = [30, 1, 365]
        for size in sizes {
            var date: SimulatedDate = SimulatedDate.j2000
            var count = 0
            while count < 100, let next = step(date, size) {
                date = next
                count += 1
            }
            let expectedForward: Int = size == 365 ? 51 : 100
            #expect(count == expectedForward, "step \(size)")
            for _ in 0..<count {
                date = try #require(step(date, -size), "back step \(size)")
            }
            #expect(date.dayOffset == 0, "step \(size): \(date.dayOffset)")
            #expect(date == SimulatedDate.j2000)
        }
        var thirty: SimulatedDate = SimulatedDate.j2000
        for _ in 0..<100 { thirty = try #require(step(thirty, 30)) }
        #expect(thirty.dayOffset == 3_000)
        for _ in 0..<100 { thirty = try #require(step(thirty, -30)) }
        #expect(thirty.dayOffset == 0)
    }

    @Test func rangeEndsAcceptedAndOneStepBeyondRefused() throws {
        let first = try #require(SimulatedDate(dayOffset: -18_262.5))
        let last = try #require(SimulatedDate(dayOffset: 18_627.5))
        #expect(first.label == "1950-01-01")
        #expect(last.label == "2051-01-01", "18,627.5 days is 2051-01-01 00:00 UTC")
        #expect(refusal(first, -1) == .outOfRange)
        #expect(refusal(last, 1) == .outOfRange)
        #expect(refusal(last, 365) == .outOfRange)
        #expect(DateStepRefusal.outOfRange.rawValue == "a14.out-of-range")
        #expect(step(first, 1)?.dayOffset == -18_261.5)
        #expect(step(last, -1)?.dayOffset == 18_626.5)
        #expect(first.dayOffset == -18_262.5 && last.dayOffset == 18_627.5, "a refusal changes nothing")
        #expect(SimulatedDate(dayOffset: -18_263) == nil)
        #expect(SimulatedDate(dayOffset: 18_628) == nil)
        #expect(SimulatedDate(dayOffset: .nan) == nil && SimulatedDate(dayOffset: .infinity) == nil)
    }

    @Test func stepsOutsideTheSetAreRefused() {
        let invalid: [Int] = [7, 0, 2, -2, 31, -364, 366, 1_000]
        for days in invalid {
            #expect(refusal(SimulatedDate.j2000, days) == .invalidStep, "step \(days)")
        }
        #expect(DateStepRefusal.invalidStep.rawValue == "a14.invalid-step")
        let valid: [Int] = [-365, -30, -1, 1, 30, 365]
        for days in valid {
            #expect(refusal(SimulatedDate.j2000, days) == nil, "step \(days)")
        }
    }

    @Test func labelsAreUTCCalendarDates() throws {
        let cases: [(Double, String)] = [(1, "2000-01-02"), (-1, "1999-12-31"), (-0.5, "2000-01-01"),
                                         (-0.6, "1999-12-31"), (366, "2001-01-01"), (9_132, "2025-01-01")]
        for (day, expected) in cases {
            let date = try #require(SimulatedDate(dayOffset: day))
            #expect(date.label == expected, "day \(day)")
        }
    }
}
