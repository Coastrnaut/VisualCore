// ParticleExperience — feature 193 (UA-F07) T-U07-027 (FR-U07-010, FR-U07-021; research R1, R6). The public face of the
// framework `ParticleUniverseExperience`: the experience's id and the factory the one app's registry calls.
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Particle Universe as an experience of the one app.
public enum ParticleExperience {
    /// The catalog id `a04.particle-universe`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ParticleCore.experienceID)

    /// The experience registered as `id`, with the person's Reduce Motion and Reduce Flashing choices as they are in
    /// effect now, over its own storage area: the scene library lives there (feature 036 A04-P04), and the app's saved
    /// session state (`state.json`) is written beside it by the host (feature 038 A04-P06,
    /// docs/apps/particle-universe/privacy-and-credits.md).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        let scale = UITraitCollection.current.displayScale
        return ExperienceShell(id: id, presenter: ParticlePresenter(experienceID: id, storage: storage, reduceMotion: reduceMotion,
                                                                    reduceFlashing: reduceFlashing,
                                                                    displayScale: scale > 0 ? scale : 2))
    }
}
