// MoonlitMechanismExperience — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005, 007, 008). The public face
// of the framework `MoonlitMechanismExperience`: the experience's id and the factory the one app's registry calls (the
// same parameter list as Acoustic Constellator's). Reduce Motion draws the gears at the set-up phases of the shown key
// frame without a turning preview; Reduce Flashing caps the glow gain. iOS only: the Core builds on the host, this
// target needs the GL host.
#if os(iOS)
import MoonlitMechanismCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Moonlit Mechanism as an experience of the one app.
public enum MoonlitMechanismExperience {
    /// The catalog id `r02-g14.moonlit-mechanism`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MoonlitMechanismExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` draws the gears at the shown key frame's set-up phases
    /// without a turning preview, `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved in a
    /// later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<MoonlitMechanismPresenter> {
        ExperienceShell(id: id, presenter: MoonlitMechanismPresenter(reduceMotion: reduceMotion,
                                                                     reduceFlashing: reduceFlashing))
    }
}
#endif
