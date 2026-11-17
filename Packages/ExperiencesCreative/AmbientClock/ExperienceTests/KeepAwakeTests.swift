// KeepAwakeTests — feature 134 (A18-P04) T-A18-406 (FR-A18-407, FR-A18-408; G-AWAKE; clarification Q4;
// contracts/power.md "Keep-awake"). Keeping the screen on through a recording `IdleTimerPort` injected into the
// factory, a private notification centre and a session (setup and teardown through the host):
//   - with the setting off the port is never set to true through setup, `didBecomeActive`, `willResignActive`,
//     `didEnterBackground` and teardown;
//   - with `screen.keepAwake [1]` the port is true while the clock is visible (after setup, once the presenter follows
//     the core), false at `willResignActive` and `didEnterBackground`, true again at `didBecomeActive`, false when the
//     setting goes off and at teardown; after teardown a notification writes nothing;
//   - the port is written only when its value changes (`writeCount`).
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// An idle-timer port that records every value written.
@MainActor
final class RecordingIdleTimer: IdleTimerPort {
    /// The values written, in order.
    private(set) var written: [Bool] = []
    /// The current value; each write is recorded.
    var keepsScreenAwake = false {
        didSet { written.append(keepsScreenAwake) }
    }
}

@MainActor
@Suite(.serialized) struct KeepAwakeTests {
    /// Opens Ambient Clock in `session` with `port` and `center` and draws one frame.
    private func open(_ session: ExperienceSession, port: RecordingIdleTimer, center: NotificationCenter) async throws
        -> ExperienceShell<AmbientPresenter> {
        let id = AmbientTest.id
        let box = AmbientEnvironmentBox()
        let provider = box.provider
        var made: ExperienceShell<AmbientPresenter>?
        session.qualityPin = 0
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AmbientClockExperience.make(id: id, clock: FixedClock(AmbientFixtures.instant),
                                                    environment: provider, center: center, idleTimer: port)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        view.layoutIfNeeded()
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return try #require(made)
    }

    /// Sends `screen.keepAwake` with `value` and lets the presenter follow the core.
    private func setKeepAwake(_ value: Double, shell: ExperienceShell<AmbientPresenter>) throws {
        let result = shell.handle(control: "screen.keepAwake", values: [value])
        #expect(result == .accepted)
        shell.presenter.follow(try AmbientTest.core(shell))
    }

    @Test func withTheSettingOffThePortIsNeverSetToTrue() async throws {
        let port = RecordingIdleTimer()
        let center = NotificationCenter()
        let session = ExperienceSession()
        let shell = try await open(session, port: port, center: center)
        shell.presenter.follow(try AmbientTest.core(shell))
        #expect(shell.presenter.isVisible)
        let names = [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                     UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification]
        for name in names {
            center.post(name: name, object: nil)
            #expect(!port.keepsScreenAwake, "\(name.rawValue)")
        }
        let off = shell.handle(control: "screen.keepAwake", values: [0])
        #expect(off == .accepted)
        shell.presenter.follow(try AmbientTest.core(shell))
        session.close()
        #expect(!shell.presenter.isVisible)
        #expect(!port.written.contains(true))
        #expect(!port.keepsScreenAwake)
        #expect(shell.presenter.keepAwake.writeCount == 0)
        #expect(!shell.presenter.keepAwake.isHolding)
    }

    @Test func withTheSettingOnThePortFollowsEveryTransition() async throws {
        let port = RecordingIdleTimer()
        let center = NotificationCenter()
        let session = ExperienceSession()
        let shell = try await open(session, port: port, center: center)
        let presenter = shell.presenter
        #expect(port.written == [], "nothing is written before the setting is on")
        try setKeepAwake(1, shell: shell)
        #expect(port.keepsScreenAwake, "visible after setup with the setting on")
        #expect(presenter.keepAwake.isHolding && presenter.keepAwake.writeCount == 1)
        presenter.follow(try AmbientTest.core(shell))
        _ = try AmbientTest.picture(session)
        #expect(presenter.keepAwake.writeCount == 1, "no write without a change")
        // (notification, expected value, expected write count)
        let steps: [(Notification.Name, Bool, Int)] = [
            (UIApplication.willResignActiveNotification, false, 2),
            (UIApplication.didEnterBackgroundNotification, false, 2),
            (UIApplication.didBecomeActiveNotification, true, 3),
            (UIApplication.didBecomeActiveNotification, true, 3),
            (UIApplication.didEnterBackgroundNotification, false, 4),
            (UIApplication.didBecomeActiveNotification, true, 5),
        ]
        for (name, value, writes) in steps {
            center.post(name: name, object: nil)
            #expect(port.keepsScreenAwake == value, "\(name.rawValue)")
            #expect(presenter.keepAwake.writeCount == writes, "\(name.rawValue)")
        }
        try setKeepAwake(0, shell: shell)
        #expect(!port.keepsScreenAwake, "the setting off releases the screen")
        #expect(presenter.keepAwake.writeCount == 6)
        try setKeepAwake(1, shell: shell)
        #expect(port.keepsScreenAwake)
        #expect(presenter.keepAwake.writeCount == 7)
        session.close()
        #expect(!port.keepsScreenAwake, "teardown releases the screen")
        #expect(presenter.keepAwake.writeCount == 8)
        #expect(port.written == [true, false, true, false, true, false, true, false])
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        #expect(!port.keepsScreenAwake, "after teardown nothing is observed")
        #expect(port.written.count == 8)
    }

    @Test func theControllerWritesOnlyOnChange() {
        let port = RecordingIdleTimer()
        let controller = KeepAwakeController(port: port)
        let steps: [(Bool, Bool, Bool, Int)] = [(false, true, false, 0), (false, false, false, 0),
                                                (true, false, false, 0), (true, true, true, 1),
                                                (true, true, true, 1), (false, true, false, 2),
                                                (true, true, true, 3), (true, false, false, 4)]
        for (setting, visible, holding, writes) in steps {
            controller.update(setting: setting, visible: visible)
            #expect(controller.isHolding == holding, "setting \(setting) visible \(visible)")
            #expect(port.keepsScreenAwake == holding, "setting \(setting) visible \(visible)")
            #expect(controller.writeCount == writes, "setting \(setting) visible \(visible)")
        }
        #expect(port.written == [true, false, true, false])
    }
}
