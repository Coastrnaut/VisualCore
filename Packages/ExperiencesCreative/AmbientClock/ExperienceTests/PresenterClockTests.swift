// PresenterClockTests — feature 132 (A18-P02) T-A18-205 (FR-A18-206; SC-A18-202; research D2; contracts/
// experience.md "Time"; spec edge case "Rendering unavailable"). The presenter's clock with a fixed clock source, an
// injected environment and a private notification centre: `tick` sends the source's instant as `time.set` (the core's
// instant equals it) and returns a deadline strictly later on a whole minute (seconds off) or a whole second (seconds
// on); with no frame drawn, advancing the fixed clock by 60 s and ticking moves the text to the next minute; a new
// zone the provider reports is adopted at the next tick; after `stopMonitoring`, and after the session's teardown, a
// posted notification sends nothing.
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct PresenterClockTests {
    @Test func tickSendsTheClocksInstantAndReturnsTheNextWholeMinute() async throws {
        for zone in [AmbientFixtures.newYork, AmbientFixtures.kolkata] {
            let now = AmbientFixtures.date("2026-06-15T18:05:17Z").addingTimeInterval(0.25)
            let clock = FixedClock(now)
            let shell = try await AmbientTest.shell(clock: clock, box: AmbientEnvironmentBox(zone: zone))
            let revision = shell.port.revision
            let deadline = shell.presenter.tick(port: shell.port)
            let core = try AmbientTest.core(shell)
            #expect(core.instant == now.timeIntervalSince1970, "\(zone.identifier)")
            #expect(shell.port.revision == revision + 1, "\(zone.identifier): one time.set accepted")
            #expect(deadline > now, "\(zone.identifier)")
            #expect(deadline.timeIntervalSince(now) <= 60, "\(zone.identifier)")
            #expect(deadline.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0, "\(zone.identifier)")
            #expect(deadline == AmbientFixtures.date("2026-06-15T18:06:00Z"), "\(zone.identifier)")
            #expect(shell.presenter.display.nextDeadline == deadline)
        }
    }

    @Test func withSecondsShownTheDeadlineIsTheNextWholeSecond() async throws {
        let now = AmbientFixtures.date("2026-06-15T18:05:17Z").addingTimeInterval(0.25)
        let clock = FixedClock(now)
        let shell = try await AmbientTest.shell(clock: clock)
        let set = shell.presenter.setFormat(hourCycle: 2, showSeconds: true, showDate: false, port: shell.port)
        #expect(set == .accepted)
        let deadline = shell.presenter.tick(port: shell.port)
        #expect(deadline > now)
        #expect(deadline.timeIntervalSince(now) <= 1)
        #expect(deadline.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) == 0)
        #expect(deadline == AmbientFixtures.date("2026-06-15T18:05:18Z"))
        // On a whole second the deadline is the next one, strictly later.
        clock.set(deadline)
        let next = shell.presenter.tick(port: shell.port)
        #expect(next == AmbientFixtures.date("2026-06-15T18:05:19Z"))
        #expect(try AmbientTest.core(shell).instant == deadline.timeIntervalSince1970)
    }

    @Test func withNoFrameDrawnTickingMovesTheTextToTheNextMinute() async throws {
        let clock = FixedClock(AmbientFixtures.instant)
        let shell = try await AmbientTest.shell(clock: clock)
        #expect(shell.presenter.lastDrawCount == 0)
        #expect(shell.presenter.scene == nil, "no render host: nothing is drawn")
        shell.presenter.tick(port: shell.port)
        #expect(AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "") == "2:05 PM")
        clock.advance(by: 60)
        let deadline = shell.presenter.tick(port: shell.port)
        #expect(AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "") == "2:06 PM")
        #expect(AmbientFixtures.normalized(shell.presenter.mirror.display?.time ?? "") == "2:06 PM")
        #expect(try AmbientTest.core(shell).instant == AmbientFixtures.instant.timeIntervalSince1970 + 60)
        // At the returned deadline the text moves again.
        clock.set(deadline)
        shell.presenter.tick(port: shell.port)
        #expect(AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "") == "2:07 PM")
        #expect(shell.presenter.lastDrawCount == 0)
    }

    @Test func aZoneTheProviderReportsIsAdoptedAtTheNextTick() async throws {
        let box = AmbientEnvironmentBox()
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant), box: box)
        shell.presenter.tick(port: shell.port)
        #expect(AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "") == "2:05 PM")
        box.set(zone: AmbientFixtures.kolkata)
        shell.presenter.tick(port: shell.port)
        #expect(AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "") == "11:35 PM")
        #expect(try AmbientTest.core(shell).revision == 0, "no notification, no time.changed")
    }

    @Test func afterStopMonitoringNoTimeChangeIsSent() async throws {
        let center = NotificationCenter()
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant), center: center)
        let presenter = shell.presenter
        presenter.startMonitoring()
        #expect(presenter.monitor?.isRunning == true)
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        #expect(try AmbientTest.core(shell).revision == 1)
        #expect(presenter.timeChangeCount == 1)
        presenter.stopMonitoring()
        #expect(presenter.monitor?.isRunning == false)
        let revision = shell.port.revision
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(try AmbientTest.core(shell).revision == 1)
        #expect(presenter.timeChangeCount == 1)
        #expect(shell.port.revision == revision, "nothing was sent")
    }

    @Test func theSessionStartsTheMonitorInSetupAndStopsItInTeardown() async throws {
        let center = NotificationCenter()
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, center: center)
        let presenter = shell.presenter
        #expect(presenter.monitor?.isRunning == true, "setup starts the monitor")
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        #expect(try AmbientTest.core(shell).revision == 1)
        #expect(presenter.timeChangeCount == 1)
        session.close()
        #expect(presenter.monitor?.isRunning != true, "teardown stops the monitor")
        #expect(presenter.scene == nil)
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(presenter.timeChangeCount == 1, "after teardown nothing is sent")
    }
}
