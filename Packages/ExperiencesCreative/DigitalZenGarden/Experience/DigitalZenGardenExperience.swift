// DigitalZenGardenExperience — feature 146 (A20-P02) T-A20-204 (FR-A20-201, FR-A20-206; clarification Q5). The public
// face of the framework `DigitalZenGardenExperience`: the experience's id and the factory the one app's registry calls
// (the same parameter list as Ambient Clock's, so the registry entry mirrors it). Nothing animates on its own, so Reduce
// Motion changes nothing (raking is direct) and nothing flashes, so Reduce Flashing changes nothing either. The garden
// travels in the host's saved session state (snapshot schema 1, the garden document).
//
// Feature 148 (A20-P04) T-A20-402 (FR-A20-401; clarifications Q1, Q5): `storage` holds the named gardens
// (`GardenLibrary`). The factory hands the presenter the shell's current core and a restore of a saved document
// through the shell's restore path (`restore(_:into:)`): a snapshot of the document with the shell's seed and step
// and the document's digest, so the engine checks it as any saved state, the undo history restarts and the digest
// equals the opened document's.
import Foundation
import DigitalZenGardenCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Digital Zen Garden as an experience of the one app.
public enum DigitalZenGardenExperience {
    /// The catalog id `a20.digital-zen-garden`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: GardenCore.experienceID)

    /// The experience registered as `id`; `storage` holds the named gardens (feature 148); `reduceMotion` and
    /// `reduceFlashing` change nothing (nothing animates or flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, storage: storage)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `reduceMotion`, `forceFallback`
    /// (the sand in `rgba8` even where half floats render), the library over `storage` (none without it), `still`,
    /// the shell's port, its current core and the restore of a saved document.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, forceFallback: Bool = false,
                     storage: ExperienceStorage? = nil,
                     still: GardenStill = GardenStill()) -> ExperienceShell<GardenPresenter> {
        let presenter = GardenPresenter(reduceMotion: reduceMotion, forceFallback: forceFallback, storage: storage,
                                        still: still)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.coreSource = { [weak shell] in shell?.engine.core }
        presenter.restoreDocument = { [weak shell] document in
            guard let shell else { return false }
            return restore(document, into: shell)
        }
        return shell
    }

    /// Replaces the state of `shell` by `document` through the shell's restore path: a snapshot of the document with
    /// the shell's current seed and step index and the document's digest. Returns whether the shell accepted it (a
    /// refused restore changes nothing).
    @MainActor
    static func restore(_ document: GardenDocument, into shell: ExperienceShell<GardenPresenter>) -> Bool {
        do {
            let current = try shell.snapshot()
            let core = GardenCore(document: document)
            var builder = DigestBuilder(domain: shell.id.rawValue)
            try core.writeDigest(into: &builder)
            let snapshot = try ExperienceSnapshot(experience: shell.id, schemaVersion: current.schemaVersion,
                                                  seed: current.seed, stepIndex: current.stepIndex,
                                                  digest: builder.finish(), payload: try document.encoded())
            try shell.restore(snapshot)
            return true
        } catch {
            return false
        }
    }
}
