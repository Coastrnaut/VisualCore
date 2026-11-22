// FacetedForgeExperience — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-005, 008). The public face of the
// framework `FacetedForgeExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Amethyst Escape's). Reduce Motion holds the shimmer still and shows the opening without easing;
// Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import FacetedForgeCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Faceted Forge as an experience of the one app.
public enum FacetedForgeExperience {
    /// The catalog id `r02-g08.faceted-forge`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: FacetedForgeExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the shimmer still and shows the opening without easing,
    /// `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved from R02-G08-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<FacetedForgePresenter> {
        ExperienceShell(id: id, presenter: FacetedForgePresenter(reduceMotion: reduceMotion,
                                                                 reduceFlashing: reduceFlashing))
    }
}
#endif
