// InfiniteGeometryExperience — feature 040 (A05-P01) T-A05-105 (FR-A05-131, FR-A05-132). The public face of the
// framework `InfiniteGeometryExperience`: the experience's id and the factory the one app's registry calls.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Infinite Geometry as an experience of the one app.
public enum InfiniteGeometryExperience {
    /// The catalog id `a05.infinite-geometry`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: GeometryCore.experienceID)

    /// The experience registered as `id`. Infinite Geometry keeps nothing in `storage` (the host writes the saved
    /// session state beside it), and its compositions are static, so Reduce Motion and Reduce Flashing change nothing
    /// it draws; the parameters keep the registry's one factory signature.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        ExperienceShell(id: id, presenter: GeometryPresenter(experienceID: id))
    }
}
