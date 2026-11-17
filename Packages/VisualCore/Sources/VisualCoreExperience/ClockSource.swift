// ClockSource — feature 131 T-A18-102 (FR-A18-101; G-CLOCK; contract specs/131-ac-p01-clock-a11y/contracts/clock.md
// "Source"). The one way an experience reads the current instant. In production the only reader of the wall clock is
// `SystemClock.now`; tests and replays construct `FixedClock`. Nothing adds an offset.
import Foundation
import Synchronization

/// A source of the current instant, injected wherever an experience needs the wall time.
public protocol ClockSource: Sendable {
    /// The current instant according to this source.
    var now: Date { get }
}

/// The system's wall clock: `now` is `Date()`, with no offset and no stored state.
public struct SystemClock: ClockSource {
    /// Creates the system clock.
    public init() {}

    /// The system's current instant, `Date()`.
    public var now: Date { Date() }
}

/// A clock that returns an injected instant until it is set or advanced, for tests and replays.
public final class FixedClock: ClockSource {
    private let instant: Mutex<Date>

    /// Creates a clock that reports `instant` until it is changed.
    /// - Parameter instant: The instant `now` returns.
    public init(_ instant: Date) {
        self.instant = Mutex(instant)
    }

    /// The injected instant.
    public var now: Date { instant.withLock { $0 } }

    /// Replaces the instant `now` returns.
    /// - Parameter instant: The new instant.
    public func set(_ instant: Date) {
        self.instant.withLock { $0 = instant }
    }

    /// Moves the instant by a number of seconds (negative values move it back).
    /// - Parameter interval: The seconds to add to the current instant.
    public func advance(by interval: TimeInterval) {
        instant.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}
