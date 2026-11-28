// MyceliumArchitectExperience — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-005, 007, 008). The public face
// of the framework `MyceliumArchitectExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Binary Gardens'). Nothing moves by itself under Reduce Motion: the vein pulses, the toxin
// ripples, the hyphae fuzz and the spores stand still (`u_motion` 0), and the shown pulse never advances by time;
// Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this target needs the GL host. Modelled on
// `BinaryGardensExperience` (feature 503).
#if os(iOS)
import MyceliumArchitectCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Mycelium Architect as an experience of the one app.
public enum MyceliumArchitectExperience {
    /// The catalog id `r02-g22.mycelium-architect`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MyceliumArchitectExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stills the vein pulses, ripples, fuzz and spores;
    /// `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<MyceliumArchitectPresenter> {
        ExperienceShell(id: id, presenter: MyceliumArchitectPresenter(reduceMotion: reduceMotion,
                                                                      reduceFlashing: reduceFlashing))
    }
}
#endif
