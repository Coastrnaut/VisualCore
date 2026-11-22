// AmethystEscapeExperience — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-005, 008). The public face of the
// framework `AmethystEscapeExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Chrono Constellator's). Reduce Motion holds the facet highlights still; Reduce Flashing caps the glow
// gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import AmethystEscapeCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Amethyst Escape as an experience of the one app.
public enum AmethystEscapeExperience {
    /// The catalog id `r02-g07.amethyst-escape`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AmethystEscapeExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the facet highlights still and `reduceFlashing` caps
    /// the glow; `storage` is not used yet (progress is saved from R02-G07-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<AmethystEscapePresenter> {
        ExperienceShell(id: id, presenter: AmethystEscapePresenter(reduceMotion: reduceMotion,
                                                                   reduceFlashing: reduceFlashing))
    }
}
#endif
