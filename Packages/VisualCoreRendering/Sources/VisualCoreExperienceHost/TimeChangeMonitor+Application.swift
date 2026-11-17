// TimeChangeMonitor+Application — feature 131 T-A18-103 (FR-A18-102; G-CLOCK; contract specs/131-ac-p01-clock-a11y/
// contracts/clock.md "Monitor"). The application names of the time-change monitor: Foundation's names plus the
// significant time change and the return to the foreground, which only UIKit posts.
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import VisualCoreExperience

#if canImport(UIKit)
extension TimeChangeMonitor {
    /// The names an app observes: `foundationNames` (time zone, locale, calendar day) plus
    /// `UIApplication.significantTimeChangeNotification` (significantTime) and
    /// `UIApplication.willEnterForegroundNotification` (foreground), so every `TimeChangeKind` is mapped once.
    public static let applicationNames: [Notification.Name: TimeChangeKind] = foundationNames.merging([
        UIApplication.significantTimeChangeNotification: .significantTime,
        UIApplication.willEnterForegroundNotification: .foreground,
    ]) { current, _ in current }
}
#endif
