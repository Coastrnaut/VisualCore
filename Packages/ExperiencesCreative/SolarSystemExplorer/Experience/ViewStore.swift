// ViewStore — feature 106 (A14-P04) T-A14-408 (FR-A14-421; SC-A14-405; clarification Q5; data-model "SavedView").
// The saved view of Solar System Explorer in the experience's own storage, one file: `view.json` (`SavedView.fileName`),
// a `SavedView` document (schema 1, sorted keys, at most 4,096 bytes).
//   - Save: the view's `encoded()` bytes written through `ExperienceStorage.write`, which replaces the file atomically;
//     a refused write throws the storage error and leaves the stored file as it was.
//   - Load: no file → `.missing`; a file the storage cannot read → `.unreadable(code)`; otherwise `SavedView.decode`
//     (which checks the size first): `oversized`, `damaged`, `newer-version` or `out-of-range` → `.refused(reason)`.
//     Loading never writes, so a refused file stays byte for byte as it was.
// Without storage (tests and previews) the bytes are kept in memory with the same rules. The store sits outside the
// engine state: saving never changes a digest or a replay; restoring goes through the action `view.apply`.
import Foundation
import SolarSystemExplorerCore
import VisualCoreExperience

/// Why no saved view could be restored.
enum ViewLoadFailure: Error, Equatable, Sendable {
    /// No view was saved yet.
    case missing
    /// The stored file was refused by `SavedView.decode`.
    case refused(SavedViewRefusal)
    /// The storage could not read the file (the storage error's code).
    case unreadable(String)

    /// The words shown for the failure: "No view has been saved yet.", "The saved view could not be read
    /// (damaged)." or "The saved view could not be read (<storage code>)."
    var words: String {
        switch self {
        case .missing: return "No view has been saved yet."
        case .refused(let refusal): return "The saved view could not be read (\(refusal.rawValue))."
        case .unreadable(let code): return "The saved view could not be read (\(code))."
        }
    }
}

/// The saved view in its storage file (see the file header).
final class ViewStore {
    /// The experience's storage, or nil for a view kept in memory only.
    let storage: ExperienceStorage?
    /// The stored bytes when there is no storage.
    private var memory: Data?
    /// The number of views written (or bytes set in memory).
    private(set) var writes = 0

    /// A store over `storage` (in memory without storage). Nothing is read or written here.
    init(storage: ExperienceStorage?) {
        self.storage = storage
    }

    /// Saves `view`, replacing the stored file; throws the storage's refusal (the previous file is left as it was).
    func save(_ view: SavedView) throws(StorageError) {
        let data = view.encoded()
        if let storage {
            try storage.write(data, to: SavedView.fileName)
        } else {
            memory = data
        }
        writes += 1
    }

    /// The stored view, or why there is none (see the file header). Nothing is written.
    func load() -> Result<SavedView, ViewLoadFailure> {
        let data: Data
        if let storage {
            do {
                data = try storage.read(SavedView.fileName)
            } catch {
                if case .notFound = error { return .failure(.missing) }
                return .failure(.unreadable(error.code))
            }
        } else {
            guard let memory else { return .failure(.missing) }
            data = memory
        }
        switch SavedView.decode(data) {
        case .success(let view): return .success(view)
        case .failure(let refusal): return .failure(.refused(refusal))
        }
    }
}
