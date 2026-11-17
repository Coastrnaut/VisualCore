// DaylightSavingTests — feature 131 (A18-P01) T-A18-108 (FR-A18-105; SC-A18-102, SC-A18-103; research D4; spec edge
// cases). America/New_York in 2026: spring forward on 2026-03-08 at 07:00 UTC never shows 02:xx and the deadline before
// it shows 03:00; fall back on 2026-11-01 at 06:00 UTC shows 01:59 twice; deadlines always increase; at midnight the
// date line changes in the same update as the time.
import Foundation
import Testing
import VisualCoreExperience
@testable import AmbientClockCore

@Suite struct DaylightSavingTests {
    /// 24-hour German text in New York, so the hour is two digits and unambiguous.
    private static let preferences = ClockPreferences(hourCycle: .h24, showSeconds: false, showDate: false)
    private static let environment = ClockFixtures.environment(locale: "de_DE", zone: ClockFixtures.newYork)

    /// The normalized time line at `date`.
    private static func time(_ date: Date) -> String {
        ClockFormatter.display(at: date, preferences: preferences, environment: environment).time
    }

    /// The time lines of every whole minute from `start` to `end` inclusive.
    private static func minutes(from start: String, to end: String) -> [(Date, String)] {
        var rows: [(Date, String)] = []
        var instant = ClockFixtures.date(start)
        let last = ClockFixtures.date(end)
        while instant <= last {
            rows.append((instant, ClockFixtures.normalized(time(instant))))
            instant = instant.addingTimeInterval(60)
        }
        return rows
    }

    @Test func springForwardNeverShowsTheMissingHour() {
        let rows = Self.minutes(from: "2026-03-08T06:58:00Z", to: "2026-03-08T07:01:00Z")
        #expect(rows.count == 4)
        for row in rows {
            #expect(!row.1.hasPrefix("02:"), "\(row.0) shows \(row.1)")
        }
        #expect(rows.map(\.1) == ["01:58", "01:59", "03:00", "03:01"])
    }

    @Test func theDeadlineBeforeSpringForwardShowsThreeOClock() {
        let before = ClockFixtures.date("2026-03-08T06:59:30Z")
        let deadline = ClockSchedule.nextDeadline(after: before, showSeconds: false, calendar: Self.environment.calendar)
        #expect(deadline == ClockFixtures.date("2026-03-08T07:00:00Z"))
        #expect(ClockFixtures.normalized(Self.time(deadline)) == "03:00")
        let secondDeadline = ClockSchedule.nextDeadline(after: ClockFixtures.date("2026-03-08T06:59:59Z"),
                                                        showSeconds: true, calendar: Self.environment.calendar)
        #expect(secondDeadline == ClockFixtures.date("2026-03-08T07:00:00Z"))
    }

    @Test func fallBackShowsTheRepeatedMinuteTwice() {
        let rows = Self.minutes(from: "2026-11-01T05:58:00Z", to: "2026-11-01T07:00:00Z")
        let repeated = rows.filter { $0.1 == "01:59" }.map(\.0)
        #expect(repeated == [ClockFixtures.date("2026-11-01T05:59:00Z"), ClockFixtures.date("2026-11-01T06:59:00Z")])
        #expect(rows.first?.1 == "01:58")
        #expect(rows.last?.1 == "02:00")
        let afterChange = rows.first { $0.0 == ClockFixtures.date("2026-11-01T06:00:00Z") }
        #expect(afterChange?.1 == "01:00")
    }

    @Test func deadlinesAlwaysIncreaseAcrossBothChanges() {
        let windows = [("2026-03-08T06:58:00Z", "2026-03-08T07:02:00Z"), ("2026-11-01T05:58:00Z", "2026-11-01T07:00:00Z")]
        for window in windows {
            let end = ClockFixtures.date(window.1)
            for seconds in [false, true] {
                var current = ClockFixtures.date(window.0).addingTimeInterval(-0.5)
                var steps = 0
                while current < end {
                    let next = ClockSchedule.nextDeadline(after: current, showSeconds: seconds,
                                                          calendar: Self.environment.calendar)
                    #expect(next > current)
                    #expect(next.timeIntervalSince(current) <= (seconds ? 1 : 60))
                    current = next
                    steps += 1
                }
                let span = end.timeIntervalSince(ClockFixtures.date(window.0))
                #expect(steps == Int(span / (seconds ? 1 : 60)) + 1, "\(window.0) \(seconds)")
            }
        }
    }

    @Test func fallBackDeadlinesStepOneMinuteThroughTheChange() {
        let calendar = Self.environment.calendar
        let before = ClockFixtures.date("2026-11-01T05:59:30Z")
        #expect(ClockSchedule.nextDeadline(after: before, showSeconds: false, calendar: calendar)
                == ClockFixtures.date("2026-11-01T06:00:00Z"))
        let after = ClockFixtures.date("2026-11-01T06:00:30Z")
        #expect(ClockSchedule.nextDeadline(after: after, showSeconds: false, calendar: calendar)
                == ClockFixtures.date("2026-11-01T06:01:00Z"))
    }

    @Test func midnightChangesTheDateWithTheTime() {
        // 2026-06-15T03:59:30Z is 23:59:30 on Sunday 14 June in New York; the next minute is midnight on the 15th.
        var state = AmbientClockState(preferences: ClockPreferences(hourCycle: .h24),
                                      systemLocale: Locale(identifier: "en_US"),
                                      systemTimeZone: ClockFixtures.newYork)
        state.apply(.timeSet(ClockFixtures.date("2026-06-15T03:59:30Z")))
        let before = state.display
        let deadline = state.nextDeadline
        #expect(deadline == ClockFixtures.date("2026-06-15T04:00:00Z"))
        #expect(before.map { ClockFixtures.normalized($0.time) } == "23:59")
        #expect(before?.date.contains("14") == true)
        #expect(before?.date.contains("15") == false)
        if let deadline { state.apply(.timeSet(deadline)) }
        let after = state.display
        #expect(after.map { ClockFixtures.normalized($0.time) } == "00:00")
        #expect(after?.date.contains("15") == true)
        #expect(after?.date.contains("14") == false)
        #expect(after?.spoken.contains(after?.date ?? "-") == true)
    }
}
