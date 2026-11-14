// JourneyAnnouncer — feature 058 (A07-P05) T-A07-503 (FR-A07-520; SC-A07-504; clarification 4; data-model
// "JourneyAnnouncer"). The gate between Audio Odyssey's state changes (world, source, preset applied, pause and resume)
// and the shared announcement sink: at most one announcement per 1.5 s, changed text only, and the latest text offered
// inside the interval is held and announced by `tick(at:)` once the interval has passed. Pure: text and time in, the
// text to speak now (or nil) out. Duplicated by design from A06's `AnnouncementGate` (clarification 4).
import Foundation

/// Rate-limits Audio Odyssey's spoken announcements and keeps the latest text that arrived too early.
public struct JourneyAnnouncer: Sendable, Equatable {
    /// The shortest time between two announcements, in seconds.
    public static let interval = 1.5

    /// The text of the last announcement, or nil before the first.
    public private(set) var lastAnnounced: String?
    /// The time of the last announcement in seconds, or nil before the first.
    public private(set) var lastTime: Double?
    /// The latest text offered inside the interval, waiting for `tick(at:)`; nil when nothing waits.
    public private(set) var pending: String?

    /// Creates an announcer that has announced nothing yet.
    public init() {}

    /// Offers a text for announcement.
    /// - Parameters:
    ///   - text: The text to announce; empty text is ignored.
    ///   - time: The current time in seconds on any monotonic clock; a non-finite time is ignored.
    /// - Returns: The text to announce now, or nil. Nil when the text repeats the last announcement (any pending text
    ///   is then dropped, because the state is back to what was last said), or when less than ``interval`` has passed
    ///   since the last announcement; in the latter case the text replaces any older pending text and is announced
    ///   later by ``tick(at:)``.
    public mutating func offer(_ text: String, at time: Double) -> String? {
        guard !text.isEmpty, time.isFinite else { return nil }
        if text == lastAnnounced {
            pending = nil
            return nil
        }
        if let lastTime, time - lastTime < Self.interval {
            pending = text
            return nil
        }
        return announce(text, at: time)
    }

    /// Announces the pending text once the interval has passed.
    /// - Parameter time: The current time in seconds; a non-finite time is ignored.
    /// - Returns: The pending text when at least ``interval`` has passed since the last announcement and it differs from
    ///   the last announced text, else nil. A pending text equal to the last announcement is dropped.
    public mutating func tick(at time: Double) -> String? {
        guard time.isFinite, let text = pending else { return nil }
        if text == lastAnnounced {
            pending = nil
            return nil
        }
        if let lastTime, time - lastTime < Self.interval { return nil }
        return announce(text, at: time)
    }

    /// Forgets the last announcement and any pending text.
    public mutating func reset() {
        lastAnnounced = nil
        lastTime = nil
        pending = nil
    }

    /// Records `text` as announced at `time`, clears the pending text and returns `text`.
    private mutating func announce(_ text: String, at time: Double) -> String {
        lastAnnounced = text
        lastTime = time
        pending = nil
        return text
    }
}
