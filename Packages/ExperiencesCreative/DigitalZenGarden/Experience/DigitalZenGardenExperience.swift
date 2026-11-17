// DigitalZenGardenExperience — feature 146 (A20-P02) T-A20-204 (FR-A20-201, FR-A20-206; clarification Q5). The public
// face of the framework `DigitalZenGardenExperience`: the experience's id and the factory the one app's registry calls
// (the same parameter list as Ambient Clock's, so the registry entry mirrors it). Nothing animates on its own, so Reduce
// Motion changes nothing (raking is direct) and nothing flashes, so Reduce Flashing changes nothing either. The garden
// travels in the host's saved session state (snapshot schema 1, the garden document); `storage` is not used in this
// phase (named gardens come in A20-P04).
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Digital Zen Garden as an experience of the one app.
public enum DigitalZenGardenExperience {
    /// The catalog id `a20.digital-zen-garden`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: GardenCore.experienceID)

    /// The experience registered as `id`; `storage`, `reduceMotion` and `reduceFlashing` change nothing in this
    /// phase (nothing animates or flashes and no garden is stored outside the session state).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `reduceMotion`, `forceFallback`
    /// (the sand in `rgba8` even where half floats render) and the shell's port.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     forceFallback: Bool = false) -> ExperienceShell<GardenPresenter> {
        let presenter = GardenPresenter(reduceMotion: reduceMotion, forceFallback: forceFallback)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
