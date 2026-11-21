// WaveKnotKeeperExperience — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005, 008). The public face of the
// framework `WaveKnotKeeperExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Lissajous Labyrinth's). Reduce Motion holds the caustic pulses still; Reduce Flashing caps the glow.
// iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import VisualCoreExperience
import VisualCoreExperienceHost
import WaveKnotKeeperCore

/// Builds Wave Knot Keeper as an experience of the one app.
public enum WaveKnotKeeperExperience {
    /// The catalog id `r02-g03.wave-knot-keeper`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: WaveKnotKeeperExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the pulses still and `reduceFlashing` caps the glow;
    /// `storage` is not used yet (progress is saved from R02-G03-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<WaveKnotKeeperPresenter> {
        ExperienceShell(id: id, presenter: WaveKnotKeeperPresenter(reduceMotion: reduceMotion,
                                                                   reduceFlashing: reduceFlashing))
    }
}
#endif
