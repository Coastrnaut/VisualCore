// GraphicsBenchmarkLabExperience — feature 174 (A24-P02) T-A24-207 (FR-A24-205, FR-A24-207; contracts/experience.md
// "Factory"). The public face of the framework `GraphicsBenchmarkLabExperience`: the experience's id and the factory
// the one app's registry calls, as `VisualProgrammingLabExperience` does. The state (the selected case and the request
// counters) travels in the host's saved session state (snapshot schema 1). Feature 176 (A24-P04) T-A24-406: `storage`
// holds the saved results (``ResultLibrary``), handed to the presenter.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Graphics Benchmark Lab as an experience of the one app.
public enum GraphicsBenchmarkLabExperience {
    /// The catalog id `a24.graphics-benchmark-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: BenchCore.experienceID)

    /// The experience registered as `id`; `storage` holds the saved results (feature 176).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id, storage: Optional(storage))
    }

    /// The experience's shell with its presenter exposed (tests): the presenter's library over `storage` (none
    /// without storage) and its exports through `exporter`.
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil,
                     exporter: ResultExporter = ResultExporter()) -> ExperienceShell<BenchPresenter> {
        ExperienceShell(id: id, presenter: BenchPresenter(storage: storage, exporter: exporter))
    }
}
