// AmbientClockState — feature 131 T-A18-107 (FR-A18-105, FR-A18-106, FR-A18-107; G-FORMAT, G-TIMEA11Y; research D6). The clock's
// state and its actions. The wall time enters only as actions; nothing here reads a clock.
import Foundation
import VisualCoreExperience
import VisualCoreSimulation

/// An action on the clock.
public enum AmbientClockAction: Equatable, Sendable {
    /// `time.set`: the current instant (from the host's clock source).
    case timeSet(Date)
    /// `time.changed`: the world changed (foreground, significant time, zone, locale or calendar day); carries the
    /// system locale and zone to resolve against from now on.
    case timeChanged(TimeChangeKind, systemLocale: Locale = .current, systemTimeZone: TimeZone = .current)
    /// `prefs.set`: new preferences.
    case prefsSet(ClockPreferences)
    /// `time.speak`: a request to announce the current spoken string, at `at` seconds on the caller's clock.
    case timeSpeak(at: Double)

    /// The action's id: `time.set`, `time.changed`, `prefs.set` or `time.speak`.
    public var id: String {
        switch self {
        case .timeSet: return "time.set"
        case .timeChanged: return "time.changed"
        case .prefsSet: return "prefs.set"
        case .timeSpeak: return "time.speak"
        }
    }
}

/// The clock's state.
public struct AmbientClockState: Equatable, Sendable {
    /// The last instant set, or nil before the first `time.set`.
    public private(set) var now: Date?
    /// The preferences in force.
    public private(set) var preferences: ClockPreferences
    /// The system locale used for the `.system` locale policy.
    public private(set) var systemLocale: Locale
    /// The system time zone used for the `.system` zone policy.
    public private(set) var systemTimeZone: TimeZone
    /// The resolved environment.
    public private(set) var environment: ClockEnvironment
    /// The text for ``now``, or nil before the first `time.set`.
    public private(set) var display: ClockDisplay?
    /// The next redraw deadline after ``now``, or nil before the first `time.set`.
    public private(set) var nextDeadline: Date?
    /// How many `time.changed` actions have been applied.
    public private(set) var recomputations: Int = 0
    /// The announcement rate limiter (0.5 s).
    public var planner: AnnouncementPlanner = AnnouncementPlanner(minimumInterval: 0.5)

    /// Creates the state with the given preferences and system locale and zone.
    public init(preferences: ClockPreferences = ClockPreferences(), systemLocale: Locale = .current,
                systemTimeZone: TimeZone = .current) {
        self.preferences = preferences
        self.systemLocale = systemLocale
        self.systemTimeZone = systemTimeZone
        self.environment = ClockEnvironment(preferences: preferences, systemLocale: systemLocale,
                                            systemTimeZone: systemTimeZone)
    }

    /// Applies an action. Returns the announcement to post now, which only `time.speak` can produce (the current
    /// spoken string, when the planner lets it through; a burst keeps its newest as the planner's pending one).
    @discardableResult
    public mutating func apply(_ action: AmbientClockAction) -> Announcement? {
        switch action {
        case .timeSet(let date):
            now = date
            refresh()
            return nil
        case .timeChanged(_, let locale, let zone):
            systemLocale = locale
            systemTimeZone = zone
            rebuildEnvironment()
            refresh()
            recomputations += 1
            return nil
        case .prefsSet(let newPreferences):
            preferences = newPreferences
            rebuildEnvironment()
            refresh()
            return nil
        case .timeSpeak(let time):
            guard let spoken = display?.spoken else { return nil }
            return planner.submit(Announcement(text: spoken, kind: .state, time: time))
        }
    }

    /// Posts the planner's pending announcement once its interval has passed at `now` (seconds on the caller's
    /// clock); nil otherwise.
    public mutating func flushAnnouncement(at now: Double) -> Announcement? {
        planner.flush(now: now)
    }

    private mutating func rebuildEnvironment() {
        environment = ClockEnvironment(preferences: preferences, systemLocale: systemLocale,
                                       systemTimeZone: systemTimeZone)
    }

    private mutating func refresh() {
        guard let now else { display = nil; nextDeadline = nil; return }
        display = ClockFormatter.display(at: now, preferences: preferences, environment: environment)
        nextDeadline = ClockSchedule.nextDeadline(after: now, showSeconds: preferences.showSeconds,
                                                  calendar: environment.calendar)
    }
}
