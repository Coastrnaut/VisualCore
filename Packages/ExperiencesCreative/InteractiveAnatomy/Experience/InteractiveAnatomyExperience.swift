// InteractiveAnatomyExperience — feature 125 (A17-P02) T-A17-204 (FR-A17-202, FR-A17-210). The public face of the
// framework `InteractiveAnatomyExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Molecular Explorer's and Simulation Lab's, so the registry entry mirrors them). The view state
// travels in the host's saved session state; nothing is stored in `storage` in this phase. Framing and Reset view cut
// to the new view in one frame, so Reduce Motion changes nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Interactive Anatomy as an experience of the one app.
public enum InteractiveAnatomyExperience {
    /// The catalog id `a17.interactive-anatomy`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AnatomyCore.experienceID)

    /// The experience registered as `id`; `storage`, `reduceMotion` and `reduceFlashing` change nothing in this
    /// phase (nothing is stored, nothing moves on its own, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, storage: storage, reduceMotion: reduceMotion)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil,
                     reduceMotion: Bool = false) -> ExperienceShell<AnatomyPresenter> {
        ExperienceShell(id: id, presenter: AnatomyPresenter(experienceID: id))
    }
}
