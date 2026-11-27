// BinaryGardensExperience — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-005, 007, 008). The public face of
// the framework `BinaryGardensExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Mushroom Weather's). No position moves by time; Reduce Motion stops the coronas and the pollen
// motes (`u_motion` 0); Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this target needs
// the GL host. Modelled on `MushroomWeatherExperience` (feature 493).
#if os(iOS)
import BinaryGardensCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Binary Gardens as an experience of the one app.
public enum BinaryGardensExperience {
    /// The catalog id `r02-g21.binary-gardens`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: BinaryGardensExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stops the coronas and motes; `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<BinaryGardensPresenter> {
        ExperienceShell(id: id, presenter: BinaryGardensPresenter(reduceMotion: reduceMotion,
                                                                  reduceFlashing: reduceFlashing))
    }
}
#endif
