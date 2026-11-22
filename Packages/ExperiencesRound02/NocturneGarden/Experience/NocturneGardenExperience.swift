// NocturneGardenExperience — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-005, 008). The public face of the
// framework `NocturneGardenExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Faceted Forge's). Reduce Motion holds the mist drift and the bloom sway still; Reduce Flashing caps
// the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import NocturneGardenCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Nocturne Garden as an experience of the one app.
public enum NocturneGardenExperience {
    /// The catalog id `r02-g09.nocturne-garden`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: NocturneGardenExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the mist and the sway still, `reduceFlashing` caps the
    /// glow; `storage` is not used yet (progress is saved from R02-G09-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<NocturneGardenPresenter> {
        ExperienceShell(id: id, presenter: NocturneGardenPresenter(reduceMotion: reduceMotion,
                                                                   reduceFlashing: reduceFlashing))
    }
}
#endif
