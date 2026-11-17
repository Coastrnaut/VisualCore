// StateTests — feature 131 (A18-P01) T-A18-108 (FR-A18-105, FR-A18-106; SC-A18-103; G-STATE; research D6). The
// clock's state: `time.set` sets the display and the next deadline; each of the five `time.changed` kinds adds exactly
// one recomputation; equal action sequences give equal states; `prefs.set` reformats; a new system zone moves the
// shown time under the system zone policy only; only `time.speak` returns an announcement.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import AmbientClockCore

@Suite struct StateTests {
    /// A state in en_US and New York with the given preferences.
    private static func state(_ preferences: ClockPreferences = ClockPreferences()) -> AmbientClockState {
        AmbientClockState(preferences: preferences, systemLocale: Locale(identifier: "en_US"),
                          systemTimeZone: ClockFixtures.newYork)
    }

    /// The normalized time line of `state`, or nil before the first `time.set`.
    private static func time(_ state: AmbientClockState) -> String? {
        state.display.map { ClockFixtures.normalized($0.time) }
    }

    @Test func theActionIdsAreDocumented() {
        #expect(AmbientClockAction.timeSet(ClockFixtures.instant).id == "time.set")
        #expect(AmbientClockAction.timeChanged(.foreground).id == "time.changed")
        #expect(AmbientClockAction.prefsSet(ClockPreferences()).id == "prefs.set")
        #expect(AmbientClockAction.timeSpeak(at: 0).id == "time.speak")
    }

    @Test func beforeTheFirstTimeSetNothingIsShown() {
        let state = Self.state()
        #expect(state.now == nil)
        #expect(state.display == nil)
        #expect(state.nextDeadline == nil)
        #expect(state.recomputations == 0)
        #expect(state.planner.minimumInterval == 0.5)
    }

    @Test func timeSetSetsTheDisplayAndTheDeadline() {
        var state = Self.state(ClockPreferences(hourCycle: .h24))
        state.apply(.timeSet(ClockFixtures.instant))
        #expect(state.now == ClockFixtures.instant)
        #expect(Self.time(state) == "14:05")
        #expect(state.nextDeadline == ClockFixtures.date("2026-06-15T18:06:00Z"))
        #expect(state.recomputations == 0)
    }

    @Test func eachTimeChangeKindAddsOneRecomputation() {
        var state = Self.state()
        state.apply(.timeSet(ClockFixtures.instant))
        var expected = 0
        for kind in TimeChangeKind.allCases {
            state.apply(.timeChanged(kind, systemLocale: Locale(identifier: "en_US"),
                                     systemTimeZone: ClockFixtures.newYork))
            expected += 1
            #expect(state.recomputations == expected, "\(kind)")
        }
        #expect(TimeChangeKind.allCases.count == 5)
        #expect(state.recomputations == 5)
    }

    @Test func aTimeChangeBeforeTheFirstTimeSetStillCounts() {
        var state = Self.state()
        state.apply(.timeChanged(.significantTime, systemLocale: Locale(identifier: "en_US"),
                                 systemTimeZone: ClockFixtures.newYork))
        #expect(state.recomputations == 1)
        #expect(state.display == nil)
    }

    @Test func equalActionSequencesGiveEqualStates() {
        let actions: [AmbientClockAction] = [
            .timeSet(ClockFixtures.instant),
            .prefsSet(ClockPreferences(hourCycle: .h12, showSeconds: true)),
            .timeChanged(.timeZone, systemLocale: Locale(identifier: "de_DE"), systemTimeZone: ClockFixtures.kolkata),
            .timeSpeak(at: 1),
            .timeSet(ClockFixtures.instant.addingTimeInterval(61)),
            .timeSpeak(at: 1.2),
            .timeChanged(.calendarDay, systemLocale: Locale(identifier: "de_DE"),
                         systemTimeZone: ClockFixtures.kolkata),
        ]
        var first = Self.state()
        var second = Self.state()
        for action in actions {
            let a = first.apply(action)
            let b = second.apply(action)
            #expect(a == b, "\(action.id)")
        }
        #expect(first == second)
        #expect(first.recomputations == 2)
    }

    @Test func prefsSetReformats() {
        var state = Self.state(ClockPreferences(hourCycle: .h24))
        state.apply(.timeSet(ClockFixtures.instant))
        #expect(Self.time(state) == "14:05")
        state.apply(.prefsSet(ClockPreferences(hourCycle: .h12)))
        #expect(Self.time(state) == "2:05 PM")
        state.apply(.prefsSet(ClockPreferences(hourCycle: .h24, showSeconds: true)))
        #expect(Self.time(state) == "14:05:09")
        #expect(state.nextDeadline == ClockFixtures.date("2026-06-15T18:05:10Z"))
        state.apply(.prefsSet(ClockPreferences(hourCycle: .h24, showDate: false)))
        #expect(state.display?.date == "")
        state.apply(.prefsSet(ClockPreferences(hourCycle: .h24, timeZone: .fixed("Asia/Kolkata"))))
        #expect(Self.time(state) == "23:35")
    }

    @Test func aNewSystemZoneMovesTheTimeUnderTheSystemPolicy() {
        var state = Self.state(ClockPreferences(hourCycle: .h24))
        state.apply(.timeSet(ClockFixtures.instant))
        #expect(Self.time(state) == "14:05")
        state.apply(.timeChanged(.timeZone, systemLocale: Locale(identifier: "en_US"),
                                 systemTimeZone: ClockFixtures.kolkata))
        #expect(Self.time(state) == "23:35")
        #expect(state.environment.timeZone.identifier == "Asia/Kolkata")
    }

    @Test func aFixedZoneIgnoresANewSystemZone() {
        var state = Self.state(ClockPreferences(hourCycle: .h24, timeZone: .fixed("America/New_York")))
        state.apply(.timeSet(ClockFixtures.instant))
        state.apply(.timeChanged(.timeZone, systemLocale: Locale(identifier: "en_US"),
                                 systemTimeZone: ClockFixtures.kolkata))
        #expect(Self.time(state) == "14:05")
        #expect(state.recomputations == 1)
    }

    @Test func aNewSystemLocaleReformatsUnderTheSystemPolicy() {
        var state = Self.state()
        state.apply(.timeSet(ClockFixtures.instant))
        #expect(Self.time(state) == "2:05 PM")
        state.apply(.timeChanged(.locale, systemLocale: Locale(identifier: "de_DE"),
                                 systemTimeZone: ClockFixtures.newYork))
        #expect(Self.time(state) == "14:05")
    }

    @Test func onlyTimeSpeakReturnsAnAnnouncement() {
        var state = Self.state()
        let set = state.apply(.timeSet(ClockFixtures.instant))
        let changed = state.apply(.timeChanged(.foreground, systemLocale: Locale(identifier: "en_US"),
                                               systemTimeZone: ClockFixtures.newYork))
        let prefs = state.apply(.prefsSet(ClockPreferences(hourCycle: .h24)))
        #expect(set == nil)
        #expect(changed == nil)
        #expect(prefs == nil)
        let spoken = state.apply(.timeSpeak(at: 0))
        #expect(spoken != nil)
        #expect(spoken?.text == state.display?.spoken)
        #expect(spoken?.kind == .state)
        #expect(spoken?.time == 0)
    }
}
