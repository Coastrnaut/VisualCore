// FormatterTests — feature 131 (A18-P01) T-A18-106 (FR-A18-104; SC-A18-101, SC-A18-104; clarification Q3; research
// D5). The time line, date line and spoken string at a fixed instant (2026-06-15T18:05:09Z) in America/New_York
// (14:05:09 EDT) and Asia/Kolkata (23:35:09 IST) for en_US, de_DE, ja_JP and ar_EG; the system, 12-hour and 24-hour
// cycles; seconds on and off; date on and off; Arabic-Indic digits for ar_EG. Text is compared after mapping U+202F
// and U+00A0 to a plain space; only strings that are stable across system versions are compared exactly.
import Foundation
import Testing
@testable import AmbientClockCore

/// Shared fixtures of the AmbientClockCore tests: fixed instants, the four locales, the two zones and the text
/// normalization of research D5.
enum ClockFixtures {
    /// The four fixture locales.
    static let localeIDs = ["en_US", "de_DE", "ja_JP", "ar_EG"]
    /// New York (daylight saving).
    static let newYork = TimeZone(identifier: "America/New_York")!
    /// Kolkata (UTC+5:30, no daylight saving).
    static let kolkata = TimeZone(identifier: "Asia/Kolkata")!
    /// The fixed instant of the formatter fixtures: 14:05:09 in New York, 23:35:09 in Kolkata, Monday 15 June 2026.
    static let instant = date("2026-06-15T18:05:09Z")

    /// The instant of an ISO 8601 UTC string such as "2026-06-15T18:05:09Z".
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let value = formatter.date(from: iso) else { preconditionFailure("bad fixture date \(iso)") }
        return value
    }

    /// `text` with U+202F and U+00A0 mapped to a plain space.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// Whether `text` has at least one digit and every digit is Arabic-Indic (U+0660…U+0669).
    static func usesOnlyArabicIndicDigits(_ text: String) -> Bool {
        var digits = 0
        for scalar in text.unicodeScalars where scalar.properties.numericType != nil {
            guard (0x0660...0x0669).contains(scalar.value) else { return false }
            digits += 1
        }
        return digits > 0
    }

    /// The environment for a fixed locale and zone.
    static func environment(locale id: String, zone: TimeZone) -> ClockEnvironment {
        ClockEnvironment(preferences: ClockPreferences(), systemLocale: Locale(identifier: id), systemTimeZone: zone)
    }

    /// The normalized display of `date` with the given preferences in a fixed locale and zone.
    static func display(_ date: Date = instant, locale id: String, zone: TimeZone,
                        preferences: ClockPreferences) -> ClockDisplay {
        let raw = ClockFormatter.display(at: date, preferences: preferences,
                                         environment: environment(locale: id, zone: zone))
        return ClockDisplay(time: normalized(raw.time), date: normalized(raw.date), spoken: normalized(raw.spoken))
    }
}

@Suite struct FormatterTests {
    /// One exact time-line fixture.
    private struct TimeCase {
        var locale: String
        var zone: TimeZone
        var cycle: HourCycle
        var seconds: Bool
        var expected: String
    }

    @Test func templatesFollowTheHourCycleAndSeconds() {
        #expect(ClockFormatter.timeTemplate(hourCycle: .system, showSeconds: false) == "jmm")
        #expect(ClockFormatter.timeTemplate(hourCycle: .h12, showSeconds: false) == "hmma")
        #expect(ClockFormatter.timeTemplate(hourCycle: .h24, showSeconds: false) == "HHmm")
        #expect(ClockFormatter.timeTemplate(hourCycle: .h24, showSeconds: true) == "HHmmss")
    }

    @Test func theLocalesUseTheirOwnHourCycle() {
        #expect(ClockFormatter.usesTwelveHourClock(locale: Locale(identifier: "en_US")))
        #expect(!ClockFormatter.usesTwelveHourClock(locale: Locale(identifier: "de_DE")))
    }

    @Test func stableTimeLinesAreExact() {
        let cases = [
            TimeCase(locale: "en_US", zone: ClockFixtures.newYork, cycle: .system, seconds: false, expected: "2:05 PM"),
            TimeCase(locale: "en_US", zone: ClockFixtures.newYork, cycle: .h12, seconds: false, expected: "2:05 PM"),
            TimeCase(locale: "en_US", zone: ClockFixtures.newYork, cycle: .h24, seconds: false, expected: "14:05"),
            TimeCase(locale: "en_US", zone: ClockFixtures.newYork, cycle: .system, seconds: true,
                     expected: "2:05:09 PM"),
            TimeCase(locale: "en_US", zone: ClockFixtures.kolkata, cycle: .system, seconds: false,
                     expected: "11:35 PM"),
            TimeCase(locale: "en_US", zone: ClockFixtures.kolkata, cycle: .h24, seconds: false, expected: "23:35"),
            TimeCase(locale: "de_DE", zone: ClockFixtures.newYork, cycle: .system, seconds: false, expected: "14:05"),
            TimeCase(locale: "de_DE", zone: ClockFixtures.newYork, cycle: .h24, seconds: true, expected: "14:05:09"),
            TimeCase(locale: "de_DE", zone: ClockFixtures.kolkata, cycle: .system, seconds: false, expected: "23:35"),
            TimeCase(locale: "ja_JP", zone: ClockFixtures.newYork, cycle: .h24, seconds: false, expected: "14:05"),
            TimeCase(locale: "ja_JP", zone: ClockFixtures.newYork, cycle: .system, seconds: false, expected: "14:05"),
            TimeCase(locale: "ja_JP", zone: ClockFixtures.kolkata, cycle: .h24, seconds: true, expected: "23:35:09"),
        ]
        for item in cases {
            let preferences = ClockPreferences(hourCycle: item.cycle, showSeconds: item.seconds)
            let shown = ClockFixtures.display(locale: item.locale, zone: item.zone, preferences: preferences)
            #expect(shown.time == item.expected, "\(item.locale) \(item.zone.identifier) \(item.cycle)")
        }
    }

    @Test func twelveHourOnAGermanClockShowsTheDayPeriod() {
        let h12 = ClockFixtures.display(locale: "de_DE", zone: ClockFixtures.newYork,
                                        preferences: ClockPreferences(hourCycle: .h12))
        let h24 = ClockFixtures.display(locale: "de_DE", zone: ClockFixtures.newYork,
                                        preferences: ClockPreferences(hourCycle: .h24))
        #expect(h12.time != "14:05")
        #expect(h12.time != h24.time)
        #expect(h12.time.contains("2"))
        #expect(h12.time.contains("05"))
        #expect(!h12.time.contains("14"))
    }

    @Test func secondsAddTheSecondField() {
        for id in ["en_US", "de_DE", "ja_JP"] {
            let off = ClockFixtures.display(locale: id, zone: ClockFixtures.newYork, preferences: ClockPreferences())
            let on = ClockFixtures.display(locale: id, zone: ClockFixtures.newYork,
                                           preferences: ClockPreferences(showSeconds: true))
            #expect(on.time.contains(":09"), "\(id)")
            #expect(!off.time.contains(":09"), "\(id)")
        }
        let arabicOn = ClockFixtures.display(locale: "ar_EG", zone: ClockFixtures.newYork,
                                             preferences: ClockPreferences(showSeconds: true))
        let arabicOff = ClockFixtures.display(locale: "ar_EG", zone: ClockFixtures.newYork,
                                              preferences: ClockPreferences())
        #expect(arabicOn.time.contains("\u{0660}\u{0669}"))
        #expect(!arabicOff.time.contains("\u{0660}\u{0669}"))
    }

    @Test func arabicUsesArabicIndicDigitsEverywhere() {
        let cycles: [HourCycle] = [.system, .h12, .h24]
        for cycle in cycles {
            for zone in [ClockFixtures.newYork, ClockFixtures.kolkata] {
                let preferences = ClockPreferences(hourCycle: cycle, showSeconds: true, showDate: true)
                let shown = ClockFixtures.display(locale: "ar_EG", zone: zone, preferences: preferences)
                #expect(ClockFixtures.usesOnlyArabicIndicDigits(shown.time), "\(cycle) \(zone.identifier)")
                #expect(ClockFixtures.usesOnlyArabicIndicDigits(shown.date), "\(cycle) \(zone.identifier)")
            }
        }
    }

    @Test func dateOffIsEmpty() {
        for id in ClockFixtures.localeIDs {
            let shown = ClockFixtures.display(locale: id, zone: ClockFixtures.newYork,
                                              preferences: ClockPreferences(showDate: false))
            #expect(shown.date == "", "\(id)")
            #expect(shown.spoken == shown.time, "\(id)")
        }
    }

    @Test func dateOnNamesTheDay() {
        for id in ["en_US", "de_DE", "ja_JP"] {
            for zone in [ClockFixtures.newYork, ClockFixtures.kolkata] {
                let shown = ClockFixtures.display(locale: id, zone: zone, preferences: ClockPreferences())
                #expect(shown.date.contains("15"), "\(id) \(zone.identifier)")
                #expect(shown.date.contains("2026"), "\(id) \(zone.identifier)")
            }
        }
        let english = ClockFixtures.display(locale: "en_US", zone: ClockFixtures.newYork, preferences: ClockPreferences())
        #expect(english.date.contains("June"))
        #expect(english.date.contains("Monday"))
        let german = ClockFixtures.display(locale: "de_DE", zone: ClockFixtures.newYork, preferences: ClockPreferences())
        #expect(german.date.contains("Juni"))
        let japanese = ClockFixtures.display(locale: "ja_JP", zone: ClockFixtures.newYork, preferences: ClockPreferences())
        #expect(japanese.date.contains("6月"))
        let arabic = ClockFixtures.display(locale: "ar_EG", zone: ClockFixtures.newYork, preferences: ClockPreferences())
        #expect(arabic.date.contains("\u{0661}\u{0665}"))
    }

    @Test func theZoneDecidesTheDayNearMidnight() {
        // 2026-06-15T20:00:00Z is 16:00 on the 15th in New York and 01:30 on the 16th in Kolkata.
        let evening = ClockFixtures.date("2026-06-15T20:00:00Z")
        let newYork = ClockFixtures.display(evening, locale: "en_US", zone: ClockFixtures.newYork,
                                            preferences: ClockPreferences(hourCycle: .h24))
        let kolkata = ClockFixtures.display(evening, locale: "en_US", zone: ClockFixtures.kolkata,
                                            preferences: ClockPreferences(hourCycle: .h24))
        #expect(newYork.time == "16:00")
        #expect(kolkata.time == "01:30")
        #expect(newYork.date.contains("15"))
        #expect(kolkata.date.contains("16"))
    }

    @Test func formattingIsRepeatable() {
        for id in ClockFixtures.localeIDs {
            let preferences = ClockPreferences(showSeconds: true)
            let first = ClockFixtures.display(locale: id, zone: ClockFixtures.kolkata, preferences: preferences)
            let second = ClockFixtures.display(locale: id, zone: ClockFixtures.kolkata, preferences: preferences)
            #expect(first == second, "\(id)")
        }
    }
}
