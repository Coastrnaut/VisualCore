// ArcadeAnnouncements — feature 078 (A10-P04) T-A10-402 (FR-A10-420; clarification 4; research D4; edge case
// "VoiceOver announcements during a burst of events"). The VoiceOver texts of a run change and their rate limit.
//
// `ArcadeAnnouncements.texts(for:run:newHighScore:)` turns effect cues (``ArcadeEffects/plan(previous:current:)``)
// into texts, in cue order: a hit → "Hit, n lives left" ("Hit, 1 life left" for one) with the run's lives after the
// step; a wave → "Wave n" with the run's wave; game over → "Game over, score s", replaced by "New high score s" when
// the run's score entered the high-score table; a pickup → nothing (pickups are never announced). Numbers are plain
// digits.
//
// `ArcadeAnnouncer` wraps `AnnouncementPlanner(minimumInterval: 1.0)`: each step the presenter passes the step's cues
// and its time; a batch of texts collapses to its last one (the most significant: game over or a new high score comes
// last), which is posted when a second has passed since the last post and otherwise held, replacing an older held
// one; a step without texts posts the held one once the second has passed. At most one announcement is returned per
// call and posted announcements are at least one second apart. With VoiceOver off nothing is posted or held.
import Foundation
import VisualCoreSimulation

/// The VoiceOver texts of effect cues (see the file header).
public enum ArcadeAnnouncements {
    /// The texts for `cues` in cue order, using `run` (the current run) for lives, wave and score; game over reads
    /// "New high score s" when `newHighScore` is true. Pickups give no text.
    public static func texts(for cues: [EffectCue], run: GameRun, newHighScore: Bool) -> [String] {
        cues.compactMap { text(for: $0.kind, run: run, newHighScore: newHighScore) }
    }

    /// The text of one cue kind, or nil for a pickup.
    public static func text(for kind: EffectCue.Kind, run: GameRun, newHighScore: Bool) -> String? {
        switch kind {
        case .pickup: return nil
        case .hit: return run.lives == 1 ? "Hit, 1 life left" : "Hit, \(run.lives) lives left"
        case .wave: return "Wave \(run.wave)"
        case .over: return newHighScore ? "New high score \(run.score)" : "Game over, score \(run.score)"
        }
    }

    /// The announcement kind of a cue kind: waves are level changes, hits and game over are outcomes (nil for a
    /// pickup, which is not announced).
    public static func announcementKind(for kind: EffectCue.Kind) -> AnnouncementKind? {
        switch kind {
        case .pickup: return nil
        case .hit, .over: return .outcome
        case .wave: return .level
        }
    }
}

/// Rate-limits the arcade's announcements to at most one per second (see the file header).
public struct ArcadeAnnouncer: Sendable, Equatable {
    /// The shortest time between two posted announcements, in seconds.
    public static let minimumInterval = 1.0

    /// The underlying planner (`AnnouncementPlanner(minimumInterval: 1.0)`).
    public private(set) var planner = AnnouncementPlanner(minimumInterval: ArcadeAnnouncer.minimumInterval)

    /// Creates an announcer with nothing posted or held.
    public init() {}

    /// Whether VoiceOver is running; turning it off drops a held announcement.
    public var enabled: Bool {
        get { planner.enabled }
        set { planner.enabled = newValue }
    }

    /// The announcement held back by the rate limit, if any.
    public var pending: Announcement? { planner.pending }

    /// Processes one step at `time` (seconds on the caller's clock): the last announced cue of `cues` is submitted
    /// (posted now or held); without announced cues the held announcement is posted once the interval has passed.
    /// Returns the announcement to post now, or nil.
    public mutating func update(cues: [EffectCue], run: GameRun, newHighScore: Bool, time: Double) -> Announcement? {
        let spoken = cues.compactMap { cue -> Announcement? in
            guard let text = ArcadeAnnouncements.text(for: cue.kind, run: run, newHighScore: newHighScore),
                  let kind = ArcadeAnnouncements.announcementKind(for: cue.kind) else { return nil }
            return Announcement(text: text, kind: kind, time: time)
        }
        guard let last = spoken.last else { return planner.flush(now: time) }
        return planner.submit(last)
    }
}
