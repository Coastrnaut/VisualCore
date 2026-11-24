// VoxelOrigamiExperience — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005, 007, 008). The public face of
// the framework `VoxelOrigamiExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Moonlit Mechanism's). Reduce Motion draws the chain still at presentation time 0; Reduce Flashing
// caps the glow gain. iOS only: the Core builds on the host, this target needs the GL host.
#if os(iOS)
import VisualCoreExperience
import VisualCoreExperienceHost
import VoxelOrigamiCore

/// Builds Voxel Origami as an experience of the one app.
public enum VoxelOrigamiExperience {
    /// The catalog id `r02-g15.voxel-origami`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: VoxelOrigamiExperienceCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` draws the chain still at presentation time 0,
    /// `reduceFlashing` caps the glow; `storage` is not used yet (progress is saved in a later feature).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<VoxelOrigamiPresenter> {
        ExperienceShell(id: id, presenter: VoxelOrigamiPresenter(reduceMotion: reduceMotion,
                                                                 reduceFlashing: reduceFlashing))
    }
}
#endif
