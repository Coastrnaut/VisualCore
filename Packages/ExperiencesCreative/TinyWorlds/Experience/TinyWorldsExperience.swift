// TinyWorldsExperience — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121, FR-A12-122); feature 090 (A12-P02)
// T-A12-205 (FR-A12-212). The public face of the framework `TinyWorldsExperience`: the experience's id and the factory
// the one app's registry calls (the same parameter list as Physics Playground's, so the registry entry mirrors it). The
// world travels in the host's saved session state; the experience keeps no files of its own. `reduceMotion` makes the
// drawn view move directly instead of easing (the presenter also reads the system setting every frame); nothing
// flashes, so `reduceFlashing` changes nothing.
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Tiny Worlds as an experience of the one app.
public enum TinyWorldsExperience {
    /// The catalog id `a12.tiny-worlds`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: WorldsCore.experienceID)

    /// The experience registered as `id`. `storage` is not used (the world travels in the host's saved session
    /// state); `reduceMotion` makes view changes direct; `reduceFlashing` changes nothing (nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience with its presenter exposed (tests): `systemReduceMotion`, `voiceOverRunning` and
    /// `announcementSink` replace the system's answers when given.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, systemReduceMotion: (@MainActor () -> Bool)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil,
                     announcementSink: (any AnnouncementSink)? = nil) -> ExperienceShell<WorldsPresenter> {
        ExperienceShell(id: id, presenter: WorldsPresenter(experienceID: id, reduceMotion: reduceMotion,
                                                           systemReduceMotion: systemReduceMotion,
                                                           voiceOverRunning: voiceOverRunning,
                                                           announcementSink: announcementSink))
    }
}
