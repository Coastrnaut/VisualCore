// AnnouncementLimiter — feature 106 (A14-P04) T-A14-408 (FR-A14-401; clarification Q1; edge case "Rapid
// announcements"; data-model "AnnouncementLimiter"). Decides which spoken announcements of Solar System Explorer pass:
//   - event announcements (time played or paused, a rate change, a tour stop change with its caption, the end of a
//     tour, the stop reason "The model's range ends here", a scale mode change) always pass;
//   - the periodic spoken date while time plays passes at most once per `minimumInterval` (10 s) of wall time, counted
//     from the last announcement of either kind (so an event and the next periodic date are never closer than 10 s).
// The wall clock is injected (`Date.init` in the app; a clock the test drives in tests), so the limiter is pure and
// testable without waiting; it never touches the engine state, so announcements never change a digest or a replay.
import Foundation

/// The rate limit of the spoken announcements (see the file header).
struct AnnouncementLimiter {
    /// The shortest wall time between a periodic announcement and the announcement before it (seconds).
    static let minimumInterval: TimeInterval = 10

    /// The wall clock.
    let now: () -> Date
    /// When the last announcement passed; nil before the first.
    private(set) var lastAnnounced: Date?
    /// The number of announcements that passed.
    private(set) var passed = 0
    /// The number of periodic announcements held back.
    private(set) var held = 0

    /// A limiter reading the wall clock `now`.
    init(now: @escaping () -> Date) {
        self.now = now
    }

    /// An event announcement: `text` always passes (nil only for empty text) and restarts the interval.
    mutating func eventAnnouncement(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        lastAnnounced = now()
        passed += 1
        return text
    }

    /// A periodic announcement (the spoken date while playing): `text` when at least ``minimumInterval`` seconds of
    /// wall time passed since the last announcement (or there was none), else nil; nil for empty text.
    mutating func periodicDateAnnouncement(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let time = now()
        if let last = lastAnnounced, time.timeIntervalSince(last) < Self.minimumInterval {
            held += 1
            return nil
        }
        lastAnnounced = time
        passed += 1
        return text
    }
}
