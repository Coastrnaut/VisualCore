// TimeChangeMonitor — feature 131 T-A18-102 (FR-A18-102; G-CLOCK; contract specs/131-ac-p01-clock-a11y/contracts/
// clock.md "Monitor"). Maps notification names to time-change kinds over an injected `NotificationCenter` and reports
// one event per posted notification, synchronously on the posting thread. Foundation only: the application names
// (`significantTimeChangeNotification`, `willEnterForegroundNotification`) are added by `VisualCoreExperienceHost`.
import Foundation
import Synchronization

/// Why the displayed time may need to be recomputed.
public enum TimeChangeKind: String, CaseIterable, Sendable {
    /// The app returned to the foreground.
    case foreground
    /// The system reported a significant time change (for example a clock adjustment or midnight).
    case significantTime
    /// The system time zone changed.
    case timeZone
    /// The current locale changed.
    case locale
    /// The calendar day changed.
    case calendarDay
}

/// Observes time-related notifications and calls a handler once per notification with its kind.
///
/// After `start()`, each notification whose name is a key of `names` calls the handler exactly once, on the posting
/// thread; after `stop()` (or deinitialization) none does. A notification with another name is ignored, and calling
/// `start()` again while running observes nothing twice.
public final class TimeChangeMonitor: Sendable {
    /// The names Foundation posts on every platform: the system time zone, the current locale and the calendar day.
    public static let foundationNames: [Notification.Name: TimeChangeKind] = [
        .NSSystemTimeZoneDidChange: .timeZone,
        NSLocale.currentLocaleDidChangeNotification: .locale,
        .NSCalendarDayChanged: .calendarDay,
    ]

    /// The notification center observed.
    public let center: NotificationCenter
    /// The observed notification names and the kind each reports.
    public let names: [Notification.Name: TimeChangeKind]
    private let handler: @Sendable (TimeChangeKind) -> Void
    private let tokens: Mutex<[TokenBox]?> = Mutex(nil)

    /// Creates a stopped monitor.
    /// - Parameters:
    ///   - center: The notification center to observe (`.default` in the app; a private center in tests).
    ///   - names: The notification names to observe and the kind each reports.
    ///   - handler: Called once per observed notification with its kind, on the posting thread.
    public init(center: NotificationCenter = .default,
                names: [Notification.Name: TimeChangeKind] = TimeChangeMonitor.foundationNames,
                handler: @escaping @Sendable (TimeChangeKind) -> Void) {
        self.center = center
        self.names = names
        self.handler = handler
    }

    deinit {
        stop()
    }

    /// Whether the monitor is observing its names.
    public var isRunning: Bool { tokens.withLock { $0 != nil } }

    /// Starts observing every name in `names`. Calling it while running does nothing.
    public func start() {
        tokens.withLock { tokens in
            guard tokens == nil else { return }
            let handler = self.handler
            tokens = names.map { name, kind in
                TokenBox(center.addObserver(forName: name, object: nil, queue: nil) { _ in handler(kind) })
            }
        }
    }

    /// Stops observing. Calling it while stopped does nothing.
    public func stop() {
        let removed = tokens.withLock { tokens -> [TokenBox] in
            defer { tokens = nil }
            return tokens ?? []
        }
        for box in removed { center.removeObserver(box.token) }
    }
}

/// An observation token held only under the monitor's lock.
private struct TokenBox: @unchecked Sendable {
    let token: any NSObjectProtocol
    init(_ token: any NSObjectProtocol) { self.token = token }
}
