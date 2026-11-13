// ExperienceFeedback.swift — haptics and VoiceOver announcements for experiences (feature 226, R02-F26 T-R02F26-014;
// FR-R02F26-020, 021, 040 to 042; clarification 3). An experience plans through its action port; this object applies
// the person's switch, the rate limits and the system players. It never touches an experience's state, so haptics and
// announcements cannot change a state digest.
import Foundation
import QuartzCore
import UIKit
import VisualCoreSimulation
import VisualCoreUI

/// The route from experiences to the system's haptic feedback and accessibility announcements, on the main actor.
@MainActor
public final class ExperienceFeedback {
    /// The one route the app's experiences use.
    public static let shared = ExperienceFeedback()

    /// Whether haptic feedback plays: the person's switch in Settings (on by default).
    public var hapticsEnabled: Bool {
        get { haptics.enabled }
        set { haptics.enabled = newValue }
    }

    private var haptics: HapticPlanner
    private var announcements: AnnouncementPlanner
    private let hapticSink: any HapticSink
    private let announcementSink: any AnnouncementSink
    private let clock: () -> Double
    private let voiceOverRunning: () -> Bool

    /// Creates a route with the system players, the media clock and VoiceOver's running state; tests pass their own.
    public init(hapticSink: (any HapticSink)? = nil, announcementSink: (any AnnouncementSink)? = nil,
                clock: (() -> Double)? = nil, voiceOverRunning: (() -> Bool)? = nil) {
        self.hapticSink = hapticSink ?? SystemHapticSink()
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
        self.clock = clock ?? { CACurrentMediaTime() }
        self.voiceOverRunning = voiceOverRunning ?? { UIAccessibility.isVoiceOverRunning }
        haptics = HapticPlanner()
        announcements = AnnouncementPlanner()
    }

    /// Plays `kind` now unless the switch is off or a feedback played less than the planner's interval ago.
    public func haptic(_ kind: HapticKind) {
        if let event = haptics.submit(HapticEvent(kind: kind, time: clock())) { hapticSink.play(event.kind) }
    }

    /// Announces `text` (from a string catalog) to VoiceOver now, or after the planner's interval when an
    /// announcement was just made; nothing while VoiceOver is off.
    public func announce(_ text: String, kind: AnnouncementKind) {
        announcements.enabled = voiceOverRunning()
        if let now = announcements.submit(Announcement(text: text, kind: kind, time: clock())) {
            announcementSink.announce(now.text)
        }
    }

    /// Posts a held announcement whose interval has passed; the session calls it once per frame.
    public func flush() {
        if let held = announcements.flush(now: clock()) { announcementSink.announce(held.text) }
    }
}

extension ExperienceActionPort {
    /// Plans haptic feedback of `kind` through the shared route (feature 226); the person's switch decides.
    public func haptic(_ kind: HapticKind, route: ExperienceFeedback = .shared) {
        route.haptic(kind)
    }

    /// Plans an announcement of `text` through the shared route (feature 226); only while VoiceOver runs.
    public func announce(_ text: String, kind: AnnouncementKind, route: ExperienceFeedback = .shared) {
        route.announce(text, kind: kind)
    }
}
