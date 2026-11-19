// EffectsComposerExperience — feature 181 (A25-P02) T-A25-206 (FR-A25-202, FR-A25-207; contracts/experience.md
// "Registration"). The public face of the framework `EffectsComposerExperience`: the experience's id and the factory
// the one app's registry calls, as `GraphicsBenchmarkLabExperience` does. The chain travels in the host's saved session
// state (snapshot schema 1); the edit history does not.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Effects Composer as an experience of the one app.
public enum EffectsComposerExperience {
    /// The catalog id `a25.effects-composer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ComposerCore.experienceID)

    /// The experience registered as `id`; nothing is stored yet, so `storage` is not used in this phase.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id)
    }

    /// The experience's shell with its presenter exposed (tests).
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<ComposerPresenter> {
        ExperienceShell(id: id, presenter: ComposerPresenter())
    }
}
