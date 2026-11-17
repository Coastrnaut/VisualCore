// KeepAwake — feature 134 (A18-P04) T-A18-404/406 (FR-A18-407, FR-A18-408; G-AWAKE; contracts/power.md
// "Keep-awake"). Keeping the screen on while Ambient Clock is shown, when the person asked for it (`screen.keepAwake`).
//
//   - `IdleTimerPort` is the one switch the controller writes (`keepsScreenAwake`); `ApplicationIdleTimer` is its
//     only UIKit implementation and this file is the only one of `Packages/ExperiencesCreative/AmbientClock` that
//     names the application's idle-timer property (the source scan of the tests checks it). Tests inject a recording
//     port.
//   - `KeepAwakeController.update(setting:visible:)` holds the screen awake exactly while the setting is on and the
//     clock is visible (the presenter's setup or `didBecomeActive` until `willResignActive`, `didEnterBackground` or
//     teardown), and writes the port only when that value changes. With the setting off the port is never set to
//     true.
//   - The device brightness is never written.
import UIKit

/// The switch that keeps the screen from dimming and locking while the clock is shown.
@MainActor
protocol IdleTimerPort: AnyObject {
    /// Whether the system's idle timer is held off, so the screen stays on.
    var keepsScreenAwake: Bool { get set }
}

/// The application's idle timer (`UIApplication.shared`): the only implementation that touches UIKit.
@MainActor
final class ApplicationIdleTimer: IdleTimerPort {
    /// Creates the port over the shared application.
    init() {}

    /// Reads and writes `UIApplication.shared.isIdleTimerDisabled`.
    var keepsScreenAwake: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}

/// Holds the screen awake while the setting is on and the clock is visible (see the file header).
@MainActor
final class KeepAwakeController {
    /// The switch written on change.
    let port: any IdleTimerPort
    /// Whether the controller currently holds the screen awake (the last value written; false at first).
    private(set) var isHolding = false
    /// The number of writes to the port so far (each one a change).
    private(set) var writeCount = 0

    /// A controller over `port`; nothing is written until the first `update(setting:visible:)` that holds.
    init(port: any IdleTimerPort) {
        self.port = port
    }

    /// Holds the screen awake when `setting` and `visible` are both true, releases it otherwise; the port is written
    /// only when that value changes.
    func update(setting: Bool, visible: Bool) {
        let wanted = setting && visible
        guard wanted != isHolding else { return }
        isHolding = wanted
        writeCount += 1
        port.keepsScreenAwake = wanted
    }
}
