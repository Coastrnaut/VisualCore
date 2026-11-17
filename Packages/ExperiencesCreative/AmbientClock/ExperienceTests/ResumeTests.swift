// ResumeTests — feature 134 (A18-P04) T-A18-406 (FR-A18-405, FR-A18-406; SC-A18-402; G-SCREENCARE; clarifications
// Q3, Q5; contracts/power.md "Resume", "Dim"). The return to the foreground and the idle dim, with a fixed clock, an
// injected environment (en_US in New York) and a private notification centre:
//   - the display shows 2:05 PM; the clock moves on 30 minutes; posting `willEnterForegroundNotification` shows
//     2:35 PM at once, with no frame drawn (the draw count is unchanged), with and without a render host;
//   - the presenter's dim factor is 1 at 599 s after the last action, 0.6 at 600 s and 1 again after `noteAction()`.
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ResumeTests {
    /// The presenter's normalized time line.
    private func time(_ shell: ExperienceShell<AmbientPresenter>) -> String {
        AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "")
    }

    @Test func theReturnToTheForegroundShowsTheNewTimeBeforeAnyDraw() async throws {
        let clock = FixedClock(AmbientFixtures.instant)
        let center = NotificationCenter()
        let shell = try await AmbientTest.shell(clock: clock, center: center)
        let presenter = shell.presenter
        #expect(presenter.port != nil)
        presenter.startMonitoring()
        presenter.tick(port: shell.port)
        #expect(time(shell) == "2:05 PM")
        let draws = presenter.lastDrawCount
        let drawCount = presenter.drawCount
        clock.advance(by: 30 * 60)
        #expect(time(shell) == "2:05 PM", "nothing changes before the notification")
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(time(shell) == "2:35 PM")
        #expect(presenter.mirror.display?.time == presenter.display.display?.time)
        #expect(presenter.lastDrawCount == draws && presenter.drawCount == drawCount, "no draw")
        let core = try AmbientTest.core(shell)
        #expect(core.instant == AmbientFixtures.instant.timeIntervalSince1970 + 1800)
        #expect(core.revision == 1)
        presenter.stopMonitoring()
    }

    @Test func inASessionTheNewTimeIsShownWithoutAFrame() async throws {
        let clock = FixedClock(AmbientFixtures.instant)
        let center = NotificationCenter()
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, clock: clock, center: center)
        let presenter = shell.presenter
        #expect(presenter.monitor?.isRunning == true)
        presenter.tick(port: shell.port)
        #expect(time(shell) == "2:05 PM")
        let draws = presenter.lastDrawCount
        #expect(draws == 1)
        clock.advance(by: 30 * 60)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(time(shell) == "2:35 PM")
        #expect(presenter.lastDrawCount == draws, "the text changed before any draw")
        session.close()
    }

    @Test func theDimFactorIsSixTenthsAfterTenIdleMinutesAndOneAfterAnAction() async throws {
        let clock = FixedClock(AmbientFixtures.instant)
        let shell = try await AmbientTest.shell(clock: clock)
        let presenter = shell.presenter
        #expect(presenter.lastActionInstant == AmbientFixtures.instant.timeIntervalSince1970)
        #expect(presenter.currentDim == 1)
        // The ticks are not a person's action.
        let steps: [(Double, Double)] = [(300, 1), (299, 1), (1, 0.6), (60, 0.6)]
        for (seconds, dim) in steps {
            clock.advance(by: seconds)
            presenter.tick(port: shell.port)
            #expect(presenter.currentDim == dim, "after \(seconds) s more")
            #expect(presenter.mirror.dim == dim, "after \(seconds) s more")
        }
        #expect(presenter.screenUniforms.dim == 0.6, "the scene is dimmed by day as well")
        presenter.noteAction()
        #expect(presenter.lastActionInstant == clock.now.timeIntervalSince1970)
        #expect(presenter.currentDim == 1)
        #expect(presenter.mirror.dim == 1)
        clock.advance(by: 599)
        #expect(presenter.currentDim == 1)
        clock.advance(by: 1)
        #expect(presenter.currentDim == ScreenCare.idleDim)
        #expect(ScreenCare.idleDim == 0.6 && ScreenCare.idleInterval == 600)
    }
}
