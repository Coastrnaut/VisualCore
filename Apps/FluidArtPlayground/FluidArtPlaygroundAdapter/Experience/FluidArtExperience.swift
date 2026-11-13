// FluidArtExperience — feature 193 (UA-F07) T-U07-021 (FR-U07-010, FR-U07-021; research R1, R6). The public face of the
// framework `FluidArtPlaygroundExperience`: the experience's id and the factory the one app's registry calls.
import FluidArtPlaygroundAdapterCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Fluid Art Playground as an experience of the one app.
public enum FluidArtExperience {
    /// The catalog id `a02.fluid-art-playground`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: FluidArtCore.experienceID)

    /// The experience registered as `id`, with the person's Reduce Flashing choice as it is in effect now. It keeps
    /// nothing in storage: the standalone app stored no configuration either.
    @MainActor
    public static func make(id: ExperienceID, reduceFlashing: Bool) -> any Experience {
        ExperienceShell(id: id, presenter: FluidArtPresenter(experienceID: id, reduceFlashing: reduceFlashing))
    }
}
