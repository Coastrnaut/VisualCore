// StarlitCartoucheExperience — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005, 007, 008). The public face
// of the framework `StarlitCartoucheExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Voxel Origami's). Reduce Motion stops the firmament and the ship's glide; Reduce Flashing caps
// the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import StarlitCartoucheCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Starlit Cartouche as an experience of the one app.
public enum StarlitCartoucheExperience {
    /// The catalog id `r02-g16.starlit-cartouche`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: StarlitCartoucheExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stops the firmament and the ship's glide, `reduceFlashing`
    /// caps the glow; `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<StarlitCartouchePresenter> {
        ExperienceShell(id: id, presenter: StarlitCartouchePresenter(reduceMotion: reduceMotion,
                                                                     reduceFlashing: reduceFlashing))
    }
}
#endif
