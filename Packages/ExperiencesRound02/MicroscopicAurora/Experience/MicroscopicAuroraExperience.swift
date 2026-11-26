// MicroscopicAuroraExperience — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-005, 007, 008). The public face
// of the framework `MicroscopicAuroraExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Apsides Workshop's). Nothing moves by time, so Reduce Motion changes nothing further; Reduce
// Flashing caps the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import MicroscopicAuroraCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Microscopic Aurora as an experience of the one app.
public enum MicroscopicAuroraExperience {
    /// The catalog id `r02-g19.microscopic-aurora`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MicroscopicAuroraExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceFlashing` caps the glow; `reduceMotion` is kept for the shared
    /// signature (the scene is still already); `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<MicroscopicAuroraPresenter> {
        ExperienceShell(id: id, presenter: MicroscopicAuroraPresenter(reduceMotion: reduceMotion,
                                                                      reduceFlashing: reduceFlashing))
    }
}
#endif
