// AccessibilityPlans.swift — VoiceOver announcement and haptic rate planning, state signs and Reduce Motion
// transitions (feature 226, R02-F26, T-R02F26-009 and T-R02F26-013; FR-R02F26-020, FR-R02F26-021, FR-R02F26-030,
// FR-R02F26-040, FR-R02F26-050; research R2, R3). Pure, host-testable logic; VisualCoreUI sinks post and play.
import Foundation

/// What an announcement reports, so a host can tell rejections from outcomes, level changes and state changes.
public enum AnnouncementKind: String, Sendable, Equatable, CaseIterable {
    /// An input was rejected (for example an illegal move).
    case rejection
    /// The result of an action.
    case outcome
    /// A level, round or stage change.
    case level
    /// A change of the scene's state.
    case state
}

/// One VoiceOver announcement. The text is supplied by the caller from a string catalog; nothing here builds text.
public struct Announcement: Sendable, Equatable {
    /// The localized text to speak.
    public var text: String
    /// What the announcement reports.
    public var kind: AnnouncementKind
    /// The time it was requested, in seconds on the caller's clock.
    public var time: Double

    /// Creates an announcement.
    public init(text: String, kind: AnnouncementKind, time: Double) {
        self.text = text
        self.kind = kind
        self.time = time
    }
}

/// Rate-limits VoiceOver announcements: at most one per `minimumInterval`; a burst merges to its newest announcement,
/// which `flush(now:)` posts once the interval has passed. When VoiceOver is off nothing is posted or held.
public struct AnnouncementPlanner: Sendable, Equatable {
    /// The shortest time between two posted announcements, in seconds.
    public let minimumInterval: Double
    /// Whether VoiceOver is running. Turning it off drops a pending announcement.
    public var enabled: Bool = true {
        didSet { if !enabled { pending = nil } }
    }
    /// The announcement held back by the rate limit, if any (the newest of a burst).
    public private(set) var pending: Announcement?
    private var lastPostTime: Double?

    /// Creates a planner with the given minimum interval (0.5 s by default).
    public init(minimumInterval: Double = 0.5) {
        self.minimumInterval = minimumInterval
    }

    /// Submits an announcement. Returns it when it should be posted now; otherwise holds it as the pending one
    /// (replacing an older pending one) and returns nil. Always nil, with nothing held, when disabled.
    public mutating func submit(_ announcement: Announcement) -> Announcement? {
        guard enabled else { pending = nil; return nil }
        if let last = lastPostTime, announcement.time - last < minimumInterval {
            pending = announcement
            return nil
        }
        pending = nil
        lastPostTime = announcement.time
        return announcement
    }

    /// Returns the pending announcement when the interval since the last post has passed at `now`, else nil.
    /// Always nil, with nothing held, when disabled.
    public mutating func flush(now: Double) -> Announcement? {
        guard enabled else { pending = nil; return nil }
        guard let held = pending else { return nil }
        if let last = lastPostTime, now - last < minimumInterval { return nil }
        pending = nil
        lastPostTime = now
        return held
    }
}

/// The haptic patterns the app plays (mapped to UIKit feedback generators by VisualCoreUI).
public enum HapticKind: String, Sendable, Equatable, CaseIterable {
    /// Selection change.
    case selection
    /// Success notification.
    case success
    /// Warning notification.
    case warning
    /// Error notification.
    case error
    /// Light impact.
    case impactLight
    /// Medium impact.
    case impactMedium
    /// Heavy impact.
    case impactHeavy
}

/// One requested haptic.
public struct HapticEvent: Sendable, Equatable {
    /// The pattern to play.
    public var kind: HapticKind
    /// The time it was requested, in seconds on the caller's clock.
    public var time: Double

    /// Creates a haptic event.
    public init(kind: HapticKind, time: Double) {
        self.kind = kind
        self.time = time
    }
}

/// Rate-limits haptics: at most one per `minimumInterval`; extras are dropped, never queued. Off plays nothing.
public struct HapticPlanner: Sendable, Equatable {
    /// The shortest time between two played haptics, in seconds.
    public let minimumInterval: Double
    /// Whether haptics are on (the user's setting).
    public var enabled: Bool = true
    private var lastPlayTime: Double?

    /// Creates a planner with the given minimum interval (0.05 s by default).
    public init(minimumInterval: Double = 0.05) {
        self.minimumInterval = minimumInterval
    }

    /// Returns the event when it should be played, or nil when disabled or within the interval of the last played one.
    public mutating func submit(_ event: HapticEvent) -> HapticEvent? {
        guard enabled else { return nil }
        if let last = lastPlayTime, event.time - last < minimumInterval { return nil }
        lastPlayTime = event.time
        return event
    }
}

/// A state shown by colour together with a non-colour sign, so the state never depends on colour alone.
public struct StateSign: Sendable, Equatable {
    /// The state's identifier.
    public var id: String
    /// The state's colour as a hex string (for example "#FF0000").
    public var colorHex: String
    /// The shape, glyph or pattern that marks the state without colour.
    public var sign: String

    /// Creates a state sign.
    public init(id: String, colorHex: String, sign: String) {
        self.id = id
        self.colorHex = colorHex
        self.sign = sign
    }
}

/// Checks that every state has a non-empty sign and that no two states share one. Returns sorted problems
/// ("<id>: no sign", "<sign>: used by <id1>, <id2>"); empty when the palette is valid.
public func stateSignProblems(_ signs: [StateSign]) -> [String] {
    var problems: [String] = []
    var owners: [String: [String]] = [:]
    for state in signs {
        let sign = state.sign.trimmingCharacters(in: .whitespacesAndNewlines)
        if sign.isEmpty {
            problems.append("\(state.id): no sign")
        } else {
            owners[sign, default: []].append(state.id)
        }
    }
    for (sign, ids) in owners where ids.count > 1 {
        problems.append("\(sign): used by \(ids.sorted().joined(separator: ", "))")
    }
    return problems.sorted()
}

/// The duration of an animated transition: 0 under Reduce Motion, otherwise `duration` (negative or non-finite → 0).
public func transitionDuration(_ duration: Double, reduceMotion: Bool) -> Double {
    guard !reduceMotion, duration.isFinite, duration > 0 else { return 0 }
    return duration
}
