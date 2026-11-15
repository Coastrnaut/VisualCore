// TinyWorldsExperience — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121, FR-A12-122). The public face of the
// framework `TinyWorldsExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Physics Playground's, so the registry entry mirrors it). The world travels in the host's saved
// session state; the experience keeps no files of its own in this phase. There is no motion, so Reduce Motion changes
// nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Tiny Worlds as an experience of the one app.
public enum TinyWorldsExperience {
    /// The catalog id `a12.tiny-worlds`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: WorldsCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the world travels in the host's saved
    /// session state); `reduceMotion` and `reduceFlashing` change nothing (no motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<WorldsPresenter> {
        ExperienceShell(id: id, presenter: WorldsPresenter(experienceID: id))
    }
}
