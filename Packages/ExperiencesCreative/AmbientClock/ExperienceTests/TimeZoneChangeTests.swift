// TimeZoneChangeTests — feature 132 (A18-P02) T-A18-205 (FR-A18-206; SC-A18-202; contracts/experience.md
// "Time-zone fixture", "Foreground"). The time follows the world, with a fixed instant, an environment box and a
// private notification centre (the monitor started through `startMonitoring` with the factory's port, no frame drawn):
// at New York the text shows New York time; the provider switches to Kolkata and `NSSystemTimeZoneDidChange` is posted:
// exactly one `time.changed` is sent and the text shows Kolkata time for the same instant; the return to the
// foreground sends one `time.changed`; a locale change reformats; a notification with another name, or with no port,
// sends nothing.
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct TimeZoneChangeTests {
    /// A monitored shell at New York in en_US with the fixed instant, ticked once; with `hourCycle` set first.
    private func monitored(hourCycle: Int, box: AmbientEnvironmentBox, center: NotificationCenter) async throws
        -> ExperienceShell<AmbientPresenter> {
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant), box: box, center: center)
        let set = shell.presenter.setFormat(hourCycle: hourCycle, showSeconds: false, showDate: true, port: shell.port)
        #expect(set == .accepted)
        shell.presenter.startMonitoring()
        shell.presenter.tick(port: shell.port)
        return shell
    }

    /// The presenter's normalized time line.
    private func time(_ shell: ExperienceShell<AmbientPresenter>) -> String {
        AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "")
    }

    @Test func aZoneChangeSendsOneTimeChangeAndShowsKolkataTimeForTheSameInstant() async throws {
        let cases: [(Int, String, String)] = [(0, "2:05 PM", "11:35 PM"), (1, "2:05 PM", "11:35 PM"),
                                              (2, "14:05", "23:35")]
        for (cycle, newYork, kolkata) in cases {
            let box = AmbientEnvironmentBox()
            let center = NotificationCenter()
            let shell = try await monitored(hourCycle: cycle, box: box, center: center)
            #expect(time(shell) == newYork, "cycle \(cycle)")
            #expect(try AmbientTest.core(shell).revision == 0)
            box.set(zone: AmbientFixtures.kolkata)
            center.post(name: .NSSystemTimeZoneDidChange, object: nil)
            let core = try AmbientTest.core(shell)
            #expect(core.revision == 1, "cycle \(cycle): exactly one time.changed")
            #expect(shell.presenter.timeChangeCount == 1)
            #expect(shell.presenter.display.recomputations == 1)
            #expect(core.instant == AmbientFixtures.instant.timeIntervalSince1970, "the same instant")
            #expect(time(shell) == kolkata, "cycle \(cycle)")
            #expect(shell.presenter.display.systemTimeZone.identifier == "Asia/Kolkata")
            let expected = AmbientFixtures.expected(at: AmbientFixtures.instant, hourCycle: cycle, showSeconds: false,
                                                    showDate: true, locale: AmbientFixtures.enUS,
                                                    zone: AmbientFixtures.kolkata)
            #expect(shell.presenter.describe(core) == expected.spoken)
            #expect(shell.accessibilitySummary == expected.spoken)
        }
    }

    @Test func theTimeChangeKindsAreTheIndicesOfTheirCases() {
        #expect(AmbientCore.value(of: .foreground) == 0)
        #expect(AmbientCore.value(of: .significantTime) == 1)
        #expect(AmbientCore.value(of: .timeZone) == 2)
        #expect(AmbientCore.value(of: .locale) == 3)
        #expect(AmbientCore.value(of: .calendarDay) == 4)
        #expect(TimeChangeMonitor.applicationNames[.NSSystemTimeZoneDidChange] == .timeZone)
        #expect(TimeChangeMonitor.applicationNames[UIApplication.willEnterForegroundNotification] == .foreground)
        #expect(TimeChangeMonitor.applicationNames.count == 5)
    }

    @Test func theReturnToTheForegroundSendsOneTimeChange() async throws {
        let center = NotificationCenter()
        let shell = try await monitored(hourCycle: 0, box: AmbientEnvironmentBox(), center: center)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(try AmbientTest.core(shell).revision == 1, "exactly one time.changed")
        #expect(shell.presenter.timeChangeCount == 1)
        #expect(time(shell) == "2:05 PM")
    }

    @Test func everyApplicationNameSendsOneTimeChange() async throws {
        let center = NotificationCenter()
        let shell = try await monitored(hourCycle: 0, box: AmbientEnvironmentBox(), center: center)
        let names = Array(TimeChangeMonitor.applicationNames.keys)
        for (index, name) in names.enumerated() {
            center.post(name: name, object: nil)
            #expect(try AmbientTest.core(shell).revision == index + 1, "\(name.rawValue)")
        }
        #expect(shell.presenter.timeChangeCount == 5)
        center.post(name: Notification.Name("a18.unrelated"), object: nil)
        #expect(try AmbientTest.core(shell).revision == 5, "another name sends nothing")
    }

    @Test func aLocaleChangeReformatsTheText() async throws {
        let box = AmbientEnvironmentBox()
        let center = NotificationCenter()
        let shell = try await monitored(hourCycle: 0, box: box, center: center)
        #expect(time(shell) == "2:05 PM")
        box.set(locale: AmbientFixtures.deDE, zone: AmbientFixtures.kolkata)
        center.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        #expect(try AmbientTest.core(shell).revision == 1)
        #expect(time(shell) == "23:35")
    }

    @Test func withoutAPortANotificationSendsNothing() {
        let center = NotificationCenter()
        let box = AmbientEnvironmentBox()
        let presenter = AmbientPresenter(clock: FixedClock(AmbientFixtures.instant), environment: box.provider,
                                         center: center, reduceMotion: false)
        #expect(presenter.port == nil)
        presenter.startMonitoring()
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        #expect(presenter.timeChangeCount == 0)
        presenter.stopMonitoring()
    }
}
