// ColorfallCanyonsExperience — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-005, 008). The public face of the
// framework `ColorfallCanyonsExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Hue Compass's). Reduce Motion holds the flow bands still; Reduce Flashing caps the glow gain.
// iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import ColorfallCanyonsCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Colorfall Canyons as an experience of the one app.
public enum ColorfallCanyonsExperience {
    /// The catalog id `r02-g05.colorfall-canyons`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ColorfallCanyonsExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the flow bands still and `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved from R02-G05-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<ColorfallCanyonsPresenter> {
        ExperienceShell(id: id, presenter: ColorfallCanyonsPresenter(reduceMotion: reduceMotion,
                                                                     reduceFlashing: reduceFlashing))
    }
}
#endif
