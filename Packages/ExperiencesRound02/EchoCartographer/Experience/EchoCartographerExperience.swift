// EchoCartographerExperience — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005, 008). The public face of the
// framework `EchoCartographerExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Backwards Aurora's). Reduce Motion draws the rings and flares at rest; Reduce Flashing caps the glow
// gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import EchoCartographerCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Echo Cartographer as an experience of the one app.
public enum EchoCartographerExperience {
    /// The catalog id `r02-g11.echo-cartographer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: EchoCartographerExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` draws the rings and flares at rest, `reduceFlashing` caps the
    /// glow; `storage` is not used yet (progress is saved from R02-G11-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<EchoCartographerPresenter> {
        ExperienceShell(id: id, presenter: EchoCartographerPresenter(reduceMotion: reduceMotion,
                                                                     reduceFlashing: reduceFlashing))
    }
}
#endif
