// VisualProgrammingLabExperience — feature 167 (A23-P02) T-A23-206 (FR-A23-201, FR-A23-207; clarification Q5;
// contracts/experience.md "Factory"). The public face of the framework `VisualProgrammingLabExperience`: the
// experience's id and the factory the one app's registry calls, as `ShaderStudioExperience` does. The state (the graph
// and the selection) travels in the host's saved session state (snapshot schema 1); saving graphs and examples to the
// experience's storage come with A23-P04, so the storage is not read yet.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Visual Programming Lab as an experience of the one app.
public enum VisualProgrammingLabExperience {
    /// The catalog id `a23.visual-programming-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: LabCore.experienceID)

    /// The experience registered as `id`; `storage` is kept for A23-P04 (saving), unused here.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id)
    }

    /// The experience's shell with its presenter exposed (tests); the presenter gets the shell's port and reads the
    /// shell's current state for its touches and feedback.
    @MainActor
    static func make(id: ExperienceID) -> ExperienceShell<LabPresenter> {
        let presenter = LabPresenter()
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.currentCore = { [weak shell] in shell?.engine.core }
        return shell
    }
}
