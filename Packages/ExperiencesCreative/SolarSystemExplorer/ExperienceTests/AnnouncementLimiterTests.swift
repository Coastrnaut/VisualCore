// AnnouncementLimiterTests — feature 106 (A14-P04) T-A14-408 (FR-A14-401; clarification Q1; edge case "Rapid
// announcements"). The announcement limit of Solar System Explorer on a clock the test drives (no wall-clock wait or
// assertion): event announcements always pass; the periodic spoken date passes at most once per 10 s, counted from
// the last announcement of either kind; empty text never passes.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience

/// A clock the test moves by hand.
final class ManualClock: @unchecked Sendable {
    /// The current instant.
    var time = Date(timeIntervalSince1970: 1_000_000)

    /// Moves the clock `seconds` forward.
    func advance(_ seconds: TimeInterval) { time = time.addingTimeInterval(seconds) }
}

final class AnnouncementLimiterTests: XCTestCase {
    func testEventAnnouncementsAlwaysPass() {
        let clock = ManualClock()
        var limiter = AnnouncementLimiter(now: { clock.time })
        XCTAssertEqual(AnnouncementLimiter.minimumInterval, 10)
        for i in 0..<5 {
            XCTAssertEqual(limiter.eventAnnouncement("Time paused. \(i)"), "Time paused. \(i)")
            clock.advance(0.1)
        }
        XCTAssertEqual(limiter.passed, 5)
        XCTAssertNil(limiter.eventAnnouncement(""), "empty text is never announced")
    }

    func testThePeriodicDatePassesAtMostOnceEveryTenSeconds() {
        let clock = ManualClock()
        var limiter = AnnouncementLimiter(now: { clock.time })
        XCTAssertEqual(limiter.periodicDateAnnouncement("Date A."), "Date A.", "the first passes")
        var passedTimes: [Double] = [0]
        var elapsed = 0.0
        // 60 s of frames at 0.5 s: passes at 10, 20, …, 60 only.
        for _ in 0..<120 {
            clock.advance(0.5)
            elapsed += 0.5
            if limiter.periodicDateAnnouncement("Date at \(elapsed).") != nil { passedTimes.append(elapsed) }
        }
        XCTAssertEqual(passedTimes, [0, 10, 20, 30, 40, 50, 60])
        for i in passedTimes.indices.dropFirst() {
            XCTAssertGreaterThanOrEqual(passedTimes[i] - passedTimes[i - 1], AnnouncementLimiter.minimumInterval)
        }
        XCTAssertEqual(limiter.held, 120 - 6)
        XCTAssertNil(limiter.periodicDateAnnouncement(""))
    }

    func testAnEventRestartsTheInterval() {
        let clock = ManualClock()
        var limiter = AnnouncementLimiter(now: { clock.time })
        XCTAssertNotNil(limiter.periodicDateAnnouncement("Date 1."))
        clock.advance(9)
        XCTAssertNotNil(limiter.eventAnnouncement("Time playing at 1 year/s."), "an event passes inside the interval")
        clock.advance(9)
        XCTAssertNil(limiter.periodicDateAnnouncement("Date 2."), "9 s after the event")
        clock.advance(1)
        XCTAssertEqual(limiter.periodicDateAnnouncement("Date 3."), "Date 3.", "10 s after the event")
        clock.advance(-5)
        XCTAssertNil(limiter.periodicDateAnnouncement("Date 4."), "a clock that went back does not pass")
    }
}
