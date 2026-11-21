// HueCompassExperience — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-005, 008). The public face of the
// framework `HueCompassExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Wave Knot Keeper's). Reduce Motion holds the fog drift still; Reduce Flashing caps the glow gain.
// iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import HueCompassCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Hue Compass as an experience of the one app.
public enum HueCompassExperience {
    /// The catalog id `r02-g04.hue-compass`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: HueCompassExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the fog drift still and `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved from R02-G04-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<HueCompassPresenter> {
        ExperienceShell(id: id, presenter: HueCompassPresenter(reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing))
    }
}
#endif
