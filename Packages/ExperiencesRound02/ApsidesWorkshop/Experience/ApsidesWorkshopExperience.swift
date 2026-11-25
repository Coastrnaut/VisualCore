// ApsidesWorkshopExperience — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-005, 007, 008). The public face of
// the framework `ApsidesWorkshopExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Celestial Eclipse Lab's). Reduce Motion stops the star's glow pulsing; Reduce Flashing caps the
// glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import ApsidesWorkshopCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Apsides Workshop as an experience of the one app.
public enum ApsidesWorkshopExperience {
    /// The catalog id `r02-g18.apsides-workshop`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ApsidesWorkshopExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stops the star's pulse, `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<ApsidesWorkshopPresenter> {
        ExperienceShell(id: id, presenter: ApsidesWorkshopPresenter(reduceMotion: reduceMotion,
                                                                    reduceFlashing: reduceFlashing))
    }
}
#endif
