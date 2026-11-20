// AuroraLoomExperience — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-005, 008). The public face of the
// framework `AuroraLoomExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Aurora's, A21). Reduce Motion holds the silk still; Reduce Flashing caps the glow. iOS only: the Core builds on
// the host, this target needs the GL host.
#if os(iOS)
import AuroraLoomCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Aurora Loom as an experience of the one app.
public enum AuroraLoomExperience {
    /// The catalog id `r02-g01.aurora-loom`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AuroraLoomExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the silk still and `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved from R02-G01-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<AuroraLoomPresenter> {
        ExperienceShell(id: id, presenter: AuroraLoomPresenter(reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing))
    }
}
#endif
