// SpokenTimeTests — feature 131 (A18-P01) T-A18-109 (FR-A18-107; clarification Q5; research D6). The spoken string
// names the time (with the day period for 12-hour) and the date when it is shown, in each fixture locale; a run of
// minute `time.set` actions announces nothing; `time.speak` bursts within 0.5 s post at most one, the newest held back
// until the interval has passed; nothing is spoken before the first `time.set`.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import AmbientClockCore

@Suite struct SpokenTimeTests {
    /// A state in `locale` and New York with the given preferences, set to the fixture instant.
    private static func state(locale: String, _ preferences: ClockPreferences = ClockPreferences())
        -> AmbientClockState {
        var state = AmbientClockState(preferences: preferences, systemLocale: Locale(identifier: locale),
                                      systemTimeZone: ClockFixtures.newYork)
        state.apply(.timeSet(ClockFixtures.instant))
        return state
    }

    /// `text` without its digits, separators and spaces: the day period of a 12-hour time line.
    private static func period(of text: String) -> String {
        var kept = ""
        for scalar in ClockFixtures.normalized(text).unicodeScalars {
            if scalar.properties.numericType != nil { continue }
            if scalar == ":" || scalar == " " || scalar == "." { continue }
            if scalar.properties.generalCategory == .format { continue }
            kept.unicodeScalars.append(scalar)
        }
        return kept
    }

    @Test func spokenNamesTheTimeAndTheDateInEachLocale() {
        for id in ClockFixtures.localeIDs {
            let state = Self.state(locale: id)
            guard let display = state.display else {
                Issue.record("no display for \(id)")
                continue
            }
            #expect(!display.time.isEmpty, "\(id)")
            #expect(!display.date.isEmpty, "\(id)")
            #expect(display.spoken.contains(display.time), "\(id)")
            #expect(display.spoken.contains(display.date), "\(id)")
            #expect(display.spoken == display.time + ", " + display.date, "\(id)")
        }
    }

    @Test func spokenIsTheTimeAloneWhenTheDateIsHidden() {
        for id in ClockFixtures.localeIDs {
            let state = Self.state(locale: id, ClockPreferences(showDate: false))
            #expect(state.display?.spoken == state.display?.time, "\(id)")
        }
    }

    @Test func twelveHourSpokenNamesTheDayPeriod() {
        for id in ClockFixtures.localeIDs {
            let state = Self.state(locale: id, ClockPreferences(hourCycle: .h12))
            guard let display = state.display else {
                Issue.record("no display for \(id)")
                continue
            }
            let period = Self.period(of: display.time)
            #expect(!period.isEmpty, "\(id) \(display.time)")
            #expect(ClockFixtures.normalized(display.spoken).contains(period), "\(id) \(display.spoken)")
        }
        let english = Self.state(locale: "en_US", ClockPreferences(hourCycle: .h12))
        #expect(english.display?.spoken.contains("PM") == true)
    }

    @Test func theAnnouncementCarriesTheSpokenString() {
        for id in ClockFixtures.localeIDs {
            var state = Self.state(locale: id)
            let announcement = state.apply(.timeSpeak(at: 0))
            #expect(announcement?.text == state.display?.spoken, "\(id)")
            #expect(announcement?.kind == .state, "\(id)")
        }
    }

    @Test func aRunOfMinuteUpdatesAnnouncesNothing() {
        var state = Self.state(locale: "en_US")
        var announced = 0
        var instant = ClockFixtures.instant
        for _ in 0..<60 {
            instant = instant.addingTimeInterval(60)
            if state.apply(.timeSet(instant)) != nil { announced += 1 }
        }
        #expect(announced == 0)
        #expect(state.planner.pending == nil)
        #expect(state.now == instant)
    }

    @Test func aBurstPostsAtMostOneUntilTheIntervalPasses() {
        var state = Self.state(locale: "en_US")
        let first = state.apply(.timeSpeak(at: 0))
        #expect(first != nil)
        let second = state.apply(.timeSpeak(at: 0.2))
        #expect(second == nil)
        #expect(state.planner.pending?.time == 0.2)
        let early = state.flushAnnouncement(at: 0.4)
        #expect(early == nil)
        let flushed = state.flushAnnouncement(at: 0.6)
        #expect(flushed?.text == state.display?.spoken)
        #expect(state.planner.pending == nil)
        let nothingLeft = state.flushAnnouncement(at: 2)
        #expect(nothingLeft == nil)
    }

    @Test func aNewSpeakAfterTheIntervalPosts() {
        var state = Self.state(locale: "de_DE")
        let first = state.apply(.timeSpeak(at: 0))
        let held = state.apply(.timeSpeak(at: 0.2))
        let later = state.apply(.timeSpeak(at: 0.6))
        #expect(first != nil)
        #expect(held == nil)
        #expect(later?.time == 0.6)
        #expect(state.planner.pending == nil)
    }

    @Test func aBurstKeepsTheNewestSpokenString() {
        var state = Self.state(locale: "en_US", ClockPreferences(hourCycle: .h24))
        let first = state.apply(.timeSpeak(at: 0))
        state.apply(.timeSet(ClockFixtures.instant.addingTimeInterval(60)))
        let held = state.apply(.timeSpeak(at: 0.1))
        let flushed = state.flushAnnouncement(at: 0.5)
        #expect(first.map { ClockFixtures.normalized($0.text) }?.hasPrefix("14:05") == true)
        #expect(held == nil)
        #expect(flushed.map { ClockFixtures.normalized($0.text) }?.hasPrefix("14:06") == true)
    }

    @Test func nothingIsSpokenBeforeTheFirstTimeSet() {
        var state = AmbientClockState(preferences: ClockPreferences(), systemLocale: Locale(identifier: "en_US"),
                                      systemTimeZone: ClockFixtures.newYork)
        let spoken = state.apply(.timeSpeak(at: 0))
        #expect(spoken == nil)
        #expect(state.planner.pending == nil)
        state.apply(.timeSet(ClockFixtures.instant))
        let now = state.apply(.timeSpeak(at: 0.1))
        #expect(now != nil)
    }
}
