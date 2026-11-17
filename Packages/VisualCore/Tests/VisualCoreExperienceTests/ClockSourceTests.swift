// ClockSourceTests — feature 131 T-A18-102 (FR-A18-101; contract clock.md "Source"): the fixed clock returns, sets and
// advances its instant; the system clock reads `Date()` with no offset.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct ClockSourceTests {
    @Test func fixedClockReturnsSetsAndAdvancesItsInstant() {
        let start = Date(timeIntervalSince1970: 1_789_000_000)
        let clock = FixedClock(start)
        #expect(clock.now == start)
        #expect(clock.now == start)
        clock.advance(by: 61.5)
        #expect(clock.now == start.addingTimeInterval(61.5))
        clock.advance(by: -1.5)
        #expect(clock.now == start.addingTimeInterval(60))
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        clock.set(later)
        #expect(clock.now == later)
    }

    @Test func fixedClockIsUsableAsAnySource() {
        let start = Date(timeIntervalSince1970: 0)
        let source: any ClockSource = FixedClock(start)
        #expect(source.now == start)
    }

    @Test func systemClockLiesBetweenReadsBeforeAndAfter() {
        let before = Date()
        let now = SystemClock().now
        let after = Date()
        #expect(before <= now && now <= after)
    }
}
