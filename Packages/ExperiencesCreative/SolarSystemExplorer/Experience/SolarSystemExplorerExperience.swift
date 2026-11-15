// SolarSystemExplorerExperience — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5), with Reduce
// Motion by feature 105 (A14-P03) T-A14-308 (FR-A14-320). The public face of the framework
// `SolarSystemExplorerExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Light Maze's, so the registry entry mirrors it). The selection travels in the host's saved session state; the
// experience keeps no files of its own. The only motion is the eased focus flight, which Reduce Motion cuts to a single
// frame; nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Solar System Explorer as an experience of the one app.
public enum SolarSystemExplorerExperience {
    /// The catalog id `a14.solar-system-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SolarCore.experienceID)

    /// The experience registered as `id`. `storage` is not used (the selection travels in the host's saved session
    /// state); `reduceMotion` cuts the focus flight to a single frame; `reduceFlashing` changes nothing (nothing
    /// flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience with its presenter exposed (tests): `reduceMotion` cuts the focus flight; `announcementSink`
    /// replaces the system's VoiceOver announcements (nil: the system's).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     announcementSink: (any AnnouncementSink)? = nil) -> ExperienceShell<SolarPresenter> {
        ExperienceShell(id: id, presenter: SolarPresenter(experienceID: id, reduceMotion: reduceMotion,
                                                          announcementSink: announcementSink))
    }
}
