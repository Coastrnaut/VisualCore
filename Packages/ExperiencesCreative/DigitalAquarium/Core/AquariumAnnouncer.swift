// AquariumAnnouncer — feature 071 (A09-P04) T-A09-404 (FR-A09-420, 421; research D4; clarification Q4). The gate
// between Digital Aquarium's change sentences (``AquariumWording/change(from:to:)``) and the shared announcement sink:
// only while VoiceOver runs, at most one announcement per 3 s; the latest sentence offered inside the interval is held
// and announced by `tick(at:)` once the interval has passed. Unlike the scope's announcer, a sentence equal to the last
// one is announced again: the sentences name events ("Food dropped" twice is two feeds), not states. Pure: text, time
// and the VoiceOver flag in, the decision out; the presenter hands the text to the sink. Modelled on Oscilloscope
// Studio's `ScopeAnnouncer`.
import Foundation

/// Rate-limits the aquarium's spoken announcements and speaks only while VoiceOver runs.
public struct AquariumAnnouncer: Equatable, Sendable {
    /// The shortest time between two announcements, in seconds.
    public static let interval = 3.0

    /// Whether VoiceOver is running; while false nothing is announced and nothing is held.
    public var voiceOverRunning: Bool {
        didSet { if !voiceOverRunning { pending = nil } }
    }
    /// The text of the last announcement, or nil before the first.
    public private(set) var lastAnnounced: String?
    /// The time of the last announcement in seconds, or nil before the first.
    public private(set) var lastTime: Double?
    /// The latest text offered inside the interval, waiting for `tick(at:)`; nil when nothing waits.
    public private(set) var pending: String?

    /// Creates an announcer that has announced nothing yet.
    /// - Parameter voiceOverRunning: Whether VoiceOver is running (the presenter passes the system flag).
    public init(voiceOverRunning: Bool) {
        self.voiceOverRunning = voiceOverRunning
    }

    /// Offers `text` for announcement at `time` (seconds on any monotonic clock).
    /// - Returns: True when the text is to be spoken now (it is then ``lastAnnounced``). False while VoiceOver is not
    ///   running, for empty text or a non-finite time (nothing is held then), or when less than ``interval`` has
    ///   passed since the last announcement; in the latter case the text replaces any older pending text and is
    ///   announced later by ``tick(at:)``.
    @discardableResult
    public mutating func announce(_ text: String, at time: Double) -> Bool {
        guard voiceOverRunning, !text.isEmpty, time.isFinite else { return false }
        if let lastTime, time - lastTime < Self.interval {
            pending = text
            return false
        }
        record(text, at: time)
        return true
    }

    /// Announces the pending text once the interval has passed.
    /// - Parameter time: The current time in seconds; a non-finite time is ignored.
    /// - Returns: The pending text when VoiceOver runs and at least ``interval`` has passed since the last
    ///   announcement (it is then ``lastAnnounced`` and no longer pending), else nil.
    public mutating func tick(at time: Double) -> String? {
        guard voiceOverRunning, time.isFinite, let text = pending else { return nil }
        if let lastTime, time - lastTime < Self.interval { return nil }
        record(text, at: time)
        return text
    }

    /// Forgets the last announcement and any pending text (the VoiceOver flag is kept).
    public mutating func reset() {
        lastAnnounced = nil
        lastTime = nil
        pending = nil
    }

    /// Records `text` as announced at `time` and clears the pending text.
    private mutating func record(_ text: String, at time: Double) {
        lastAnnounced = text
        lastTime = time
        pending = nil
    }
}
