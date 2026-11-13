// AccessibilityPlayers.swift — plays planned haptic feedback and VoiceOver announcements through public UIKit APIs
// (feature 226, R02-F26, T-R02F26-010 and T-R02F26-013; FR-R02F26-021, FR-R02F26-041; research R5). The planners in
// VisualCoreSimulation decide what to play; these players only perform it, outside the game's state, so haptics and
// announcements never change a state digest. Recording sinks stand in for the system ones in tests and automation.
import UIKit
import VisualCoreSimulation

/// Performs one planned haptic feedback kind.
@MainActor
public protocol HapticSink {
    /// Plays the feedback for `kind`; must not touch game state.
    func play(_ kind: HapticKind)
}

/// Posts one planned accessibility announcement.
@MainActor
public protocol AnnouncementSink {
    /// Announces `text` (already localized by the caller from a string catalog).
    func announce(_ text: String)
}

/// Plays haptics through the system feedback generators, each created once and prepared ahead of use.
@MainActor
public final class SystemHapticSink: HapticSink {
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// Creates the generators and prepares them so the first feedback has low latency.
    public init() {
        prepare()
    }

    /// Prepares every generator again; call when feedback is expected soon (for example when a game starts).
    public func prepare() {
        selection.prepare()
        notification.prepare()
        light.prepare()
        medium.prepare()
        heavy.prepare()
    }

    /// Plays `kind` on its generator and prepares that generator for the next event.
    public func play(_ kind: HapticKind) {
        switch kind {
        case .selection:
            selection.selectionChanged()
            selection.prepare()
        case .success:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .warning:
            notification.notificationOccurred(.warning)
            notification.prepare()
        case .error:
            notification.notificationOccurred(.error)
            notification.prepare()
        case .impactLight:
            light.impactOccurred()
            light.prepare()
        case .impactMedium:
            medium.impactOccurred()
            medium.prepare()
        case .impactHeavy:
            heavy.impactOccurred()
            heavy.prepare()
        }
    }
}

/// Posts announcements through `UIAccessibility.post(notification: .announcement, argument:)`.
@MainActor
public final class SystemAnnouncementSink: AnnouncementSink {
    /// Creates the sink; it holds no state.
    public init() {}

    /// Posts `text` as a VoiceOver announcement; the system ignores it while no assistive technology is running.
    public func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

/// Records the haptic kinds it receives, in order, for tests and automation.
@MainActor
public final class RecordingHapticSink: HapticSink {
    /// Every kind played so far, oldest first.
    public private(set) var played: [HapticKind] = []

    /// Creates an empty recorder.
    public init() {}

    /// Appends `kind` to `played`.
    public func play(_ kind: HapticKind) {
        played.append(kind)
    }

    /// Forgets everything recorded.
    public func reset() {
        played.removeAll()
    }
}

/// Records the announcement texts it receives, in order, for tests and automation.
@MainActor
public final class RecordingAnnouncementSink: AnnouncementSink {
    /// Every text announced so far, oldest first.
    public private(set) var announced: [String] = []

    /// Creates an empty recorder.
    public init() {}

    /// Appends `text` to `announced`.
    public func announce(_ text: String) {
        announced.append(text)
    }

    /// Forgets everything recorded.
    public func reset() {
        announced.removeAll()
    }
}
