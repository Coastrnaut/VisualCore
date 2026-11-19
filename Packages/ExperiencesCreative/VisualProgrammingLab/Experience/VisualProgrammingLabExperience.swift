// VisualProgrammingLabExperience — feature 167 (A23-P02) T-A23-206 (FR-A23-201, FR-A23-207; clarification Q5;
// contracts/experience.md "Factory"). The public face of the framework `VisualProgrammingLabExperience`: the
// experience's id and the factory the one app's registry calls, as `ShaderStudioExperience` does. The state (the graph
// and the selection) travels in the host's saved session state (snapshot schema 1).
//
// Feature 169 (A23-P04) T-A23-404 (FR-A23-401, FR-A23-402; clarification Q2; contracts/library.md "Presenter"):
// `storage` holds the named graphs (`GraphLibrary`). The factory hands the presenter a restore of a graph through the
// shell's restore path (`restore(_:into:)`, as Digital Zen Garden's `restoreDocument`): a `LabCore` snapshot of the
// graph with no selection, the shell's seed, step and snapshot schema and the core's digest, so the engine checks it
// as any saved state and a refused restore changes nothing.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualProgrammingLabCore

/// Builds Visual Programming Lab as an experience of the one app.
public enum VisualProgrammingLabExperience {
    /// The catalog id `a23.visual-programming-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: LabCore.experienceID)

    /// The experience registered as `id`; `storage` holds the named graphs (feature 169).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage) -> any Experience {
        make(id: id, storage: Optional(storage))
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets the library over `storage`
    /// (none without it) reading graph files through `migrations`, the shell's port, its current state for the
    /// touches and feedback, and the restore of a graph (``restore(_:into:)``).
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil,
                     migrations: MigrationChain = GraphDocument.migrations) -> ExperienceShell<LabPresenter> {
        let presenter = LabPresenter(storage: storage, migrations: migrations)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.currentCore = { [weak shell] in shell?.engine.core }
        presenter.restoreGraph = { [weak shell] graph in
            guard let shell else { return false }
            return restore(graph, into: shell)
        }
        return shell
    }

    /// Replaces the state of `shell` by `graph` with no selection through the shell's restore path: a snapshot of
    /// `LabCore(graph:)` with the shell's current schema, seed and step index and the core's digest. Returns whether
    /// the shell accepted it (a refused restore changes nothing).
    @MainActor
    static func restore(_ graph: VisualGraph, into shell: ExperienceShell<LabPresenter>) -> Bool {
        do {
            let current = try shell.snapshot()
            let core = LabCore(graph: graph, selection: nil)
            var builder = DigestBuilder(domain: shell.id.rawValue)
            try core.writeDigest(into: &builder)
            let snapshot = try ExperienceSnapshot(experience: shell.id, schemaVersion: current.schemaVersion,
                                                  seed: current.seed, stepIndex: current.stepIndex,
                                                  digest: builder.finish(), payload: try core.snapshotPayload())
            try shell.restore(snapshot)
            return true
        } catch {
            return false
        }
    }
}
