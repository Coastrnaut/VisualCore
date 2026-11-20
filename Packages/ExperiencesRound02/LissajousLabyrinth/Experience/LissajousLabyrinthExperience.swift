// LissajousLabyrinthExperience — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-005, 008). The public face of
// the framework `LissajousLabyrinthExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Aurora Loom's). Reduce Motion holds the tracer head still; Reduce Flashing caps the glow. iOS
// only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import LissajousLabyrinthCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Lissajous Labyrinth as an experience of the one app.
public enum LissajousLabyrinthExperience {
    /// The catalog id `r02-g02.lissajous-labyrinth`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: LissajousLabyrinthExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the tracer head still and `reduceFlashing` caps the
    /// glow; `storage` is not used yet (progress is saved from R02-G02-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<LissajousLabyrinthPresenter> {
        ExperienceShell(id: id, presenter: LissajousLabyrinthPresenter(reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing))
    }
}
#endif
