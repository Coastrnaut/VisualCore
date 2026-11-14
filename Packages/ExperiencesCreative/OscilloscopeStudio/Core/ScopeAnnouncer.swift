// ScopeAnnouncer — feature 065 (A08-P05) T-A08-503 (FR-A08-520; SC-A08-503; clarification 4; data-model
// "ScopeAnnouncer"). The gate between Oscilloscope Studio's state changes (view, freeze, trigger, clipping, channel
// count after a route change) and the shared announcement sink: only while VoiceOver runs, at most one announcement
// per 1.5 s, changed text only; the latest text offered inside the interval is held and announced by `tick(at:)` once
// the interval has passed. Pure: text, time and the VoiceOver flag in, the decision out; the presenter hands
// ``lastAnnounced`` to the sink. Modelled on Audio Odyssey's `JourneyAnnouncer`; the text builders use plain words.
import Foundation

/// Rate-limits the scope's spoken announcements and speaks only while VoiceOver runs.
public struct ScopeAnnouncer: Sendable, Equatable {
    /// The shortest time between two announcements, in seconds.
    public static let interval = 1.5

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
    ///   running, for empty text or a non-finite time, when the text repeats the last announcement (any pending text
    ///   is then dropped), or when less than ``interval`` has passed since the last announcement; in the latter case
    ///   the text replaces any older pending text and is announced later by ``tick(at:)``.
    @discardableResult
    public mutating func announce(_ text: String, at time: Double) -> Bool {
        guard voiceOverRunning, !text.isEmpty, time.isFinite else { return false }
        if text == lastAnnounced {
            pending = nil
            return false
        }
        if let lastTime, time - lastTime < Self.interval {
            pending = text
            return false
        }
        record(text, at: time)
        return true
    }

    /// Announces the pending text once the interval has passed.
    /// - Parameter time: The current time in seconds; a non-finite time is ignored.
    /// - Returns: The pending text when VoiceOver runs, at least ``interval`` has passed since the last announcement
    ///   and it differs from the last announced text, else nil. A pending text equal to the last one is dropped.
    public mutating func tick(at time: Double) -> String? {
        guard voiceOverRunning, time.isFinite, let text = pending else { return nil }
        if text == lastAnnounced {
            pending = nil
            return nil
        }
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

    // MARK: - Text builders

    /// "Waveform view", "XY view" or "Spectrum view".
    public static func viewChanged(_ display: ScopeDisplay) -> String {
        switch display {
        case .waveform: "Waveform view"
        case .xy: "XY view"
        case .spectrum: "Spectrum view"
        }
    }

    /// "Frozen" or "Live again".
    public static func freeze(_ frozen: Bool) -> String {
        frozen ? "Frozen" : "Live again"
    }

    /// "Trigger lost" or "Trigger found".
    public static func trigger(locked: Bool) -> String {
        locked ? "Trigger found" : "Trigger lost"
    }

    /// "Clipping" or "Clipping ended".
    public static func clipping(_ clipping: Bool) -> String {
        clipping ? "Clipping" : "Clipping ended"
    }

    /// The channel count after a route change: "Input has one channel, XY needs two channels",
    /// "Input has two channels" or "Input has N channels" (0 or fewer gives "No input channels").
    public static func channels(_ count: Int) -> String {
        switch count {
        case ...0: "No input channels"
        case 1: "Input has one channel, XY needs two channels"
        case 2: "Input has two channels"
        default: "Input has \(count) channels"
        }
    }
}
