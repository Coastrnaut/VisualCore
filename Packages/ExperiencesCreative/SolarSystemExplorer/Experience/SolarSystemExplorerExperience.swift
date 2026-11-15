// SolarSystemExplorerExperience — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5). The
// public face of the framework `SolarSystemExplorerExperience`: the experience's id and the factory the one app's
// registry calls (the same parameter list as Light Maze's, so the registry entry mirrors it). The selection travels
// in the host's saved session state; the experience keeps no files of its own in this phase. There is no motion, so
// Reduce Motion changes nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Solar System Explorer as an experience of the one app.
public enum SolarSystemExplorerExperience {
    /// The catalog id `a14.solar-system-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SolarCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the selection travels in the host's
    /// saved session state); `reduceMotion` and `reduceFlashing` change nothing (no motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<SolarPresenter> {
        ExperienceShell(id: id, presenter: SolarPresenter(experienceID: id))
    }
}
