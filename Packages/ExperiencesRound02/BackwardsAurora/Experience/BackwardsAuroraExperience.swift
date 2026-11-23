// BackwardsAuroraExperience — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-005, 008). The public face of the
// framework `BackwardsAuroraExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Nocturne Garden's). Reduce Motion holds the pulses and the shimmer still; Reduce Flashing caps the
// glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import BackwardsAuroraCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Backwards Aurora as an experience of the one app.
public enum BackwardsAuroraExperience {
    /// The catalog id `r02-g10.backwards-aurora`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: BackwardsAuroraExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the pulses and the shimmer still, `reduceFlashing` caps
    /// the glow; `storage` is not used yet (progress is saved from R02-G10-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<BackwardsAuroraPresenter> {
        ExperienceShell(id: id, presenter: BackwardsAuroraPresenter(reduceMotion: reduceMotion,
                                                                    reduceFlashing: reduceFlashing))
    }
}
#endif
