// RunTimelineTests — feature 174 (A24-P02) T-A24-204 (SC-A24-202; clarification Q2). The spec's US2 frame times 0,
// 2.9, 3, 12.9, 13, 17.9 and 18 s with the plan 3/10/5 give warm-up, warm-up, measure, measure, cool-down, cool-down
// and finished, with the boundaries at exactly 3, 13 and 18 s; the same times shifted by a start of 100 s give the
// same phases; the end time is the start plus the total; a time before the start is warm-up. Synthetic times only.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct RunTimelineTests {
    /// The plan of the spec's US2: 3 s warm-up, 10 s measurement, 5 s cool-down.
    private static let plan = RunPlan(warmUpSeconds: 3, measureSeconds: 10, coolDownSeconds: 5)
    /// The US2 frame times, relative to the start.
    private static let times: [Double] = [0, 2.9, 3, 12.9, 13, 17.9, 18]
    /// The expected phase of each of ``times``.
    private static let expected: [RunPhase?] = [.warmUp, .warmUp, .measure, .measure, .coolDown, .coolDown, nil]

    @Test func phasesFromStartZero() {
        let timeline = RunTimeline(plan: Self.plan, start: 0)
        for (offset, time) in Self.times.enumerated() {
            let phase = timeline.phase(at: time)
            let want = Self.expected[offset]
            #expect(phase == want, "time \(time)")
        }
    }

    @Test func phasesFromStartHundred() {
        let timeline = RunTimeline(plan: Self.plan, start: 100)
        for (offset, time) in Self.times.enumerated() {
            let phase = timeline.phase(at: 100 + time)
            let want = Self.expected[offset]
            #expect(phase == want, "time \(100 + time)")
        }
    }

    @Test func endTimeIsStartPlusTotal() {
        let zero = RunTimeline(plan: Self.plan, start: 0).endTime
        let hundred = RunTimeline(plan: Self.plan, start: 100).endTime
        #expect(zero == 18)
        #expect(hundred == 118)
        let afterEnd = RunTimeline(plan: Self.plan, start: 100).phase(at: 1_000)
        #expect(afterEnd == nil)
    }

    @Test func timeBeforeStartIsWarmUp() {
        let phase = RunTimeline(plan: Self.plan, start: 100).phase(at: 99)
        #expect(phase == .warmUp)
    }
}
