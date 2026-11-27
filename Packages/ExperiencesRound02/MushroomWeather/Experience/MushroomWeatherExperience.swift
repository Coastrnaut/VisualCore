// MushroomWeatherExperience — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-005, 007, 008). The public face of
// the framework `MushroomWeatherExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Microscopic Aurora's). The humidity field never moves by time; Reduce Motion stops the droplets and
// the spore motes (`u_motion` 0); Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this
// target needs the GL host. Modelled on `MicroscopicAuroraExperience` (feature 483).
#if os(iOS)
import MushroomWeatherCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Mushroom Weather as an experience of the one app.
public enum MushroomWeatherExperience {
    /// The catalog id `r02-g20.mushroom-weather`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MushroomWeatherExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stops the droplets and motes; `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<MushroomWeatherPresenter> {
        ExperienceShell(id: id, presenter: MushroomWeatherPresenter(reduceMotion: reduceMotion,
                                                                    reduceFlashing: reduceFlashing))
    }
}
#endif
