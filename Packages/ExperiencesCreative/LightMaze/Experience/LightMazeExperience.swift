// LightMazeExperience — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121, FR-A13-122). The public face of the
// framework `LightMazeExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Tiny Worlds', so the registry entry mirrors it). The maze travels in the host's saved session state; the
// experience keeps no files of its own in this phase. There is no motion, so Reduce Motion changes nothing, and nothing
// flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Light Maze as an experience of the one app.
public enum LightMazeExperience {
    /// The catalog id `a13.light-maze`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MazeCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the maze travels in the host's saved
    /// session state); `reduceMotion` and `reduceFlashing` change nothing (no motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<MazePresenter> {
        ExperienceShell(id: id, presenter: MazePresenter(experienceID: id))
    }
}
