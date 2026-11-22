// ChronoConstellatorExperience — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-005, 008). The public face of the
// framework `ChronoConstellatorExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Colorfall Canyons's). Reduce Motion holds the ribbon shimmer still; Reduce Flashing caps the glow
// gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import ChronoConstellatorCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Chrono Constellator as an experience of the one app.
public enum ChronoConstellatorExperience {
    /// The catalog id `r02-g06.chrono-constellator`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ChronoConstellatorExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the ribbon shimmer still and `reduceFlashing` caps the
    /// glow; `storage` is not used yet (progress is saved from R02-G06-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<ChronoConstellatorPresenter> {
        ExperienceShell(id: id, presenter: ChronoConstellatorPresenter(reduceMotion: reduceMotion,
                                                                       reduceFlashing: reduceFlashing))
    }
}
#endif
