// ShaderStudioExperience — feature 160 (A22-P02) T-A22-204 (FR-A22-201, FR-A22-207; clarification Q5). The public face
// of the framework `ShaderStudioExperience`: the experience's id and the factory the one app's registry calls. The
// state (template, values, textures, run and reset counts) travels in the host's saved session state (snapshot
// schema 1); the edited source is the presenter's document, kept by the project library (feature 162, A22-P04
// T-A22-410), which reads and writes the experience's `storage`.
import Foundation
import ShaderStudioCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Shader Studio as an experience of the one app.
public enum ShaderStudioExperience {
    /// The catalog id `a22.shader-studio`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: StudioCore.experienceID)

    /// The experience registered as `id`; `storage` holds the project library (feature 162).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id, storage: Optional(storage))
    }

    /// The experience's shell with its presenter exposed (tests); the presenter gets the shell's port and, when
    /// `storage` is given, a project library over it (without one the library is unavailable).
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil) -> ExperienceShell<StudioPresenter> {
        let presenter = StudioPresenter(storage: storage)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
