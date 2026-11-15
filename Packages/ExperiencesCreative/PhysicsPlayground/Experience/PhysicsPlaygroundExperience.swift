// PhysicsPlaygroundExperience — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121, FR-A11-122). The public face
// of the framework `PhysicsPlaygroundExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Neon Arcade's, so the registry entry mirrors it). The world travels in the host's saved
// session state; the experience keeps no files of its own in this phase. There is no decorative motion, so Reduce
// Motion changes nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Physics Playground as an experience of the one app.
public enum PhysicsPlaygroundExperience {
    /// The catalog id `a11.physics-playground`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: PlaygroundCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the world travels in the host's saved
    /// session state); `reduceMotion` and `reduceFlashing` change nothing (no decorative motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<PlaygroundPresenter> {
        ExperienceShell(id: id, presenter: PlaygroundPresenter(experienceID: id))
    }
}
