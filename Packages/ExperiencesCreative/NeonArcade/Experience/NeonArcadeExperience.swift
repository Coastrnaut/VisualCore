// NeonArcadeExperience — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121, FR-A10-122). The public face of the
// framework `NeonArcadeExperience`: the experience's id and the factory the one app's registry calls. The run travels
// in the host's saved session state; the experience keeps no files of its own in this phase. Reduce Motion halves the
// glow pulse and the background drift (presentation only); nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Neon Arcade as an experience of the one app.
public enum NeonArcadeExperience {
    /// The catalog id `a10.neon-arcade`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ArcadeCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the run travels in the host's saved
    /// session state); `reduceMotion` halves the glow pulse and the background drift; `reduceFlashing` changes nothing
    /// (no element flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false) -> ExperienceShell<ArcadePresenter> {
        ExperienceShell(id: id, presenter: ArcadePresenter(experienceID: id, reduceMotion: reduceMotion))
    }
}
