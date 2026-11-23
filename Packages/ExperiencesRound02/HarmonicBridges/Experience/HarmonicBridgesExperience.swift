// HarmonicBridgesExperience — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-005, 007, 008). The public face of
// the framework `HarmonicBridgesExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Echo Cartographer's). Reduce Motion draws the strings at rest and holds the shown step; Reduce
// Flashing caps the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import HarmonicBridgesCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Harmonic Bridges as an experience of the one app.
public enum HarmonicBridgesExperience {
    /// The catalog id `r02-g12.harmonic-bridges`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: HarmonicBridgesExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` draws the strings at rest and holds the shown step,
    /// `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved from R02-G12-07 on).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<HarmonicBridgesPresenter> {
        ExperienceShell(id: id, presenter: HarmonicBridgesPresenter(reduceMotion: reduceMotion,
                                                                    reduceFlashing: reduceFlashing))
    }
}
#endif
