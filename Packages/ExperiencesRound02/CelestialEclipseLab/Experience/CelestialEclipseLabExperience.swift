// CelestialEclipseLabExperience — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-005, 007, 008). The public face
// of the framework `CelestialEclipseLabExperience`: the experience's id and the factory the one app's registry calls
// (the same parameter list as Starlit Cartouche's). Reduce Motion stops the corona halos pulsing; Reduce Flashing caps
// the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import CelestialEclipseLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Celestial Eclipse Lab as an experience of the one app.
public enum CelestialEclipseLabExperience {
    /// The catalog id `r02-g17.celestial-eclipse-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: CelestialEclipseLabExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` stops the halo pulse, `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<CelestialEclipseLabPresenter> {
        ExperienceShell(id: id, presenter: CelestialEclipseLabPresenter(reduceMotion: reduceMotion,
                                                                        reduceFlashing: reduceFlashing))
    }
}
#endif
