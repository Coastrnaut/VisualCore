// EffectsComposerExperience — feature 181 (A25-P02) T-A25-206 (FR-A25-202, FR-A25-207; contracts/experience.md
// "Registration"). The public face of the framework `EffectsComposerExperience`: the experience's id and the factory
// the one app's registry calls, as `GraphicsBenchmarkLabExperience` does. The chain travels in the host's saved session
// state (snapshot schema 1); the edit history does not.
//
// Feature 182 (A25-P03) T-A25-304 (clarification Q3): `storage` holds the presets (`PresetLibrary`); the factory hands
// the presenter the shell's port and current core, so opening a preset is one undoable edit through the core.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Effects Composer as an experience of the one app.
public enum EffectsComposerExperience {
    /// The catalog id `a25.effects-composer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ComposerCore.experienceID)

    /// The experience registered as `id`; `storage` holds the presets (feature 182).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id, storage: Optional(storage))
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets the library over `storage` (none
    /// without it), the shell's port and its current core.
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil) -> ExperienceShell<ComposerPresenter> {
        let presenter = ComposerPresenter(storage: storage)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.currentCore = { [weak shell] in shell?.engine.core }
        return shell
    }
}
