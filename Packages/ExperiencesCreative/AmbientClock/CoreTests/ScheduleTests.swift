// ScheduleTests — feature 131 (A18-P01) T-A18-108 (FR-A18-105; SC-A18-102; research D3). The next redraw deadline is
// strictly later than the instant and lies on a whole second (seconds shown) or a whole minute in the clock's zone
// (seconds hidden), including the half-hour zone Asia/Kolkata; an instant exactly on a boundary gives the next one.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct ScheduleTests {
    /// A Gregorian calendar in `zone`.
    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// Instants on and between boundaries around the formatter fixture.
    private static let instants: [Date] = [
        ClockFixtures.date("2026-06-15T18:05:09Z"),
        ClockFixtures.date("2026-06-15T18:05:09Z").addingTimeInterval(0.25),
        ClockFixtures.date("2026-06-15T18:05:59Z").addingTimeInterval(0.999),
        ClockFixtures.date("2026-06-15T18:05:00Z"),
        ClockFixtures.date("2026-06-15T23:59:59Z").addingTimeInterval(0.5),
        ClockFixtures.date("2026-01-01T00:00:00Z"),
    ]

    @Test func deadlinesAreStrictlyLater() {
        for zone in [ClockFixtures.newYork, ClockFixtures.kolkata] {
            let calendar = Self.calendar(zone)
            for instant in Self.instants {
                for seconds in [false, true] {
                    let deadline = ClockSchedule.nextDeadline(after: instant, showSeconds: seconds, calendar: calendar)
                    #expect(deadline > instant, "\(instant) \(seconds) \(zone.identifier)")
                    #expect(deadline.timeIntervalSince(instant) <= (seconds ? 1 : 60), "\(instant) \(seconds)")
                }
            }
        }
    }

    @Test func withSecondsTheDeadlineIsAWholeSecond() {
        let calendar = Self.calendar(ClockFixtures.newYork)
        for instant in Self.instants {
            let deadline = ClockSchedule.nextDeadline(after: instant, showSeconds: true, calendar: calendar)
            let value = deadline.timeIntervalSince1970
            #expect(value == value.rounded(.down), "\(instant)")
        }
    }

    @Test func withoutSecondsTheDeadlineIsAWholeMinuteInTheZone() {
        for zone in [ClockFixtures.newYork, ClockFixtures.kolkata] {
            let calendar = Self.calendar(zone)
            for instant in Self.instants {
                let deadline = ClockSchedule.nextDeadline(after: instant, showSeconds: false, calendar: calendar)
                #expect(calendar.component(.second, from: deadline) == 0, "\(instant) \(zone.identifier)")
                #expect(calendar.component(.nanosecond, from: deadline) == 0, "\(instant) \(zone.identifier)")
            }
        }
    }

    @Test func kolkataMinutesFollowTheHalfHourOffset() {
        // 18:05:09Z is 23:35:09 IST; the next minute is 23:36:00 IST = 18:06:00Z.
        let calendar = Self.calendar(ClockFixtures.kolkata)
        let deadline = ClockSchedule.nextDeadline(after: ClockFixtures.instant, showSeconds: false, calendar: calendar)
        #expect(deadline == ClockFixtures.date("2026-06-15T18:06:00Z"))
        #expect(calendar.component(.hour, from: deadline) == 23)
        #expect(calendar.component(.minute, from: deadline) == 36)
        // 18:29:30Z is 23:59:30 IST; the next minute is midnight IST = 18:30:00Z.
        let lateEvening = ClockFixtures.date("2026-06-15T18:29:30Z")
        let midnight = ClockSchedule.nextDeadline(after: lateEvening, showSeconds: false, calendar: calendar)
        #expect(midnight == ClockFixtures.date("2026-06-15T18:30:00Z"))
        #expect(calendar.component(.hour, from: midnight) == 0)
        #expect(calendar.component(.day, from: midnight) == 16)
    }

    @Test func anInstantOnABoundaryGivesTheNextBoundary() {
        let calendar = Self.calendar(ClockFixtures.newYork)
        let onMinute = ClockFixtures.date("2026-06-15T18:05:00Z")
        #expect(ClockSchedule.nextDeadline(after: onMinute, showSeconds: false, calendar: calendar)
                == ClockFixtures.date("2026-06-15T18:06:00Z"))
        #expect(ClockSchedule.nextDeadline(after: onMinute, showSeconds: true, calendar: calendar)
                == ClockFixtures.date("2026-06-15T18:05:01Z"))
        let onSecond = ClockFixtures.date("2026-06-15T18:05:09Z")
        #expect(ClockSchedule.nextDeadline(after: onSecond, showSeconds: true, calendar: calendar)
                == ClockFixtures.date("2026-06-15T18:05:10Z"))
        let kolkataMinute = ClockFixtures.date("2026-06-15T18:00:00Z")
        #expect(ClockSchedule.nextDeadline(after: kolkataMinute, showSeconds: false,
                                           calendar: Self.calendar(ClockFixtures.kolkata))
                == ClockFixtures.date("2026-06-15T18:01:00Z"))
    }

    @Test func aFractionRoundsUpToTheNextBoundary() {
        let calendar = Self.calendar(ClockFixtures.newYork)
        let fraction = ClockFixtures.date("2026-06-15T18:05:09Z").addingTimeInterval(0.25)
        #expect(ClockSchedule.nextDeadline(after: fraction, showSeconds: true, calendar: calendar)
                == ClockFixtures.date("2026-06-15T18:05:10Z"))
        #expect(ClockSchedule.nextDeadline(after: fraction, showSeconds: false, calendar: calendar)
                == ClockFixtures.date("2026-06-15T18:06:00Z"))
    }

    @Test func chainedDeadlinesAdvanceOneStepAtATime() {
        let calendar = Self.calendar(ClockFixtures.kolkata)
        var current = ClockFixtures.instant
        for _ in 0..<120 {
            let next = ClockSchedule.nextDeadline(after: current, showSeconds: true, calendar: calendar)
            #expect(next > current)
            current = next
        }
        #expect(current == ClockFixtures.date("2026-06-15T18:07:09Z"))
    }
}
