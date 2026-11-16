// MolecularExplorerExperience — feature 110 (A15-P01) T-A15-106 (FR-A15-131, FR-A15-132; clarification Q5). The
// public face of the framework `MolecularExplorerExperience`: the experience's id and the factory the one app's
// registry calls (the same parameter list as Solar System Explorer's, so the registry entry mirrors it). The selection
// travels in the host's saved session state; the experience keeps no files of its own in this phase. There is no
// motion, so Reduce Motion changes nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Molecular Explorer as an experience of the one app.
public enum MolecularExplorerExperience {
    /// The catalog id `a15.molecular-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MoleculeCore.experienceID)

    /// The experience registered as `id`. `storage` is not used in this phase (the selection travels in the host's
    /// saved session state); `reduceMotion` and `reduceFlashing` change nothing (no motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id)
    }

    /// The experience with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<MoleculePresenter> {
        ExperienceShell(id: id, presenter: MoleculePresenter(experienceID: id))
    }
}
