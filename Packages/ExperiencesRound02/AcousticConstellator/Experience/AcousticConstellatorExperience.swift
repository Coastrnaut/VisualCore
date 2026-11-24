// AcousticConstellatorExperience — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-005, 007, 008). The public
// face of the framework `AcousticConstellatorExperience`: the experience's id and the factory the one app's registry
// calls (the same parameter list as Harmonic Bridges's). Reduce Motion draws the stars at tick 0 without pulsing and
// does not play the listen preview; Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this
// target needs the GL host.
#if os(iOS)
import AcousticConstellatorCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Acoustic Constellator as an experience of the one app.
public enum AcousticConstellatorExperience {
    /// The catalog id `r02-g13.acoustic-constellator`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AcousticConstellatorExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` draws the stars at tick 0 without pulsing and does not play
    /// the preview, `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<AcousticConstellatorPresenter> {
        ExperienceShell(id: id, presenter: AcousticConstellatorPresenter(reduceMotion: reduceMotion,
                                                                         reduceFlashing: reduceFlashing))
    }
}
#endif
