// DroppedFrameRuleTests — feature 175 (A24-P03) T-A24-306 (clarification Q4). The threshold is 1.5 × 1,000 / 60 ms
// = 25 ms; 24.9 and 25 are not dropped, 25.01 is; a frame without an interval is never dropped.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct DroppedFrameRuleTests {
    @Test func constants() {
        let period = DroppedFrameRule.periodMs
        let factor = DroppedFrameRule.factor
        let threshold = DroppedFrameRule.thresholdMs
        #expect(period == 1000.0 / 60.0)
        #expect(factor == 1.5)
        #expect(abs(threshold - 25) < 1e-9)
    }

    @Test func strictlyAboveTheThresholdIsDropped() {
        let cases: [(Double?, Bool)] = [(24.9, false), (25, false), (25.01, true), (nil, false), (0, false),
                                        (16.67, false), (33.3, true), (1_000, true)]
        for (interval, expected) in cases {
            let dropped = DroppedFrameRule.isDropped(intervalMs: interval)
            #expect(dropped == expected, "interval \(String(describing: interval))")
        }
    }
}
