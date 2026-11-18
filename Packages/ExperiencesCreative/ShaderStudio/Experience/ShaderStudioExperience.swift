// ShaderStudioExperience — feature 160 (A22-P02) T-A22-204 (FR-A22-201, FR-A22-207; clarification Q5). The public face
// of the framework `ShaderStudioExperience`: the experience's id and the factory the one app's registry calls. The
// state (template, values, run count) travels in the host's saved session state (snapshot schema 1); the edited
// source is the presenter's document, saved with the project library from A22-P04. `storage` is not read or written
// in this phase.
import Foundation
import ShaderStudioCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Shader Studio as an experience of the one app.
public enum ShaderStudioExperience {
    /// The catalog id `a22.shader-studio`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: StudioCore.experienceID)

    /// The experience registered as `id`; `storage` is kept for the project library of A22-P04 (not used yet).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id)
    }

    /// The experience's shell with its presenter exposed (tests); the presenter gets the shell's port.
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<StudioPresenter> {
        let presenter = StudioPresenter()
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
