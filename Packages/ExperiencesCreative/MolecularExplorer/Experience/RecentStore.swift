// RecentStore — feature 113 (A15-P04) T-A15-404 (FR-A15-410, FR-A15-411, FR-A15-440; SC-A15-402, SC-A15-403;
// clarifications Q1, Q3; data-model "RecentMolecules", "StoreLoad"). The recent-molecules list of Molecular Explorer in
// the experience's own storage, one file: `recent.json` (`RecentMolecules.fileName`), modelled on Solar System
// Explorer's `ViewStore`:
//   - Load, once, when the store is made: no file → `.missing`; a file the storage cannot read → `.unreadable(code)`;
//     otherwise `RecentMolecules.decode(_:known:)` with the library's molecule ids as `known` (ids outside the library
//     are dropped): `damaged`, `oversized`, `newer-version` or `out-of-range` → `.refused(reason)`. A refused or
//     unreadable file leaves the list empty and the message "Recent molecules could not be read (<reason>)." Loading
//     never writes, so a refused file stays byte for byte as it was.
//   - Record: `record(_:persist:)` moves the id to the front (unique, at most 8) in memory and, when the list changed
//     and `persist` is true, writes the list's `encoded()` bytes through `ExperienceStorage.write`, which replaces the
//     file atomically. A refused write keeps the previous file, the in-memory list still changes and the message
//     reads "Recent molecules could not be saved (<storage code>)."; a write that succeeds clears the message.
// Without storage (tests and previews) the bytes are kept in memory with the same rules. The store sits outside the
// engine state: recording never changes a digest or a replay.
import Foundation
import MolecularExplorerCore
import VisualCoreExperience

/// The result of loading one Molecular Explorer document (`recent.json` or `settings.json`). A load never writes.
enum StoreLoad<Value: Equatable>: Equatable {
    /// The document was read and accepted.
    case loaded(Value)
    /// There is no document yet (also after the app's data reset removed the experience's folder).
    case missing
    /// The document was refused by its codec, with the reason.
    case refused(DocumentRefusal)
    /// The storage could not read the document (the storage error's code).
    case unreadable(String)

    /// The reason text of a refused or unreadable load (`damaged`, `storage.invalid-name`, …); nil otherwise.
    var failureReason: String? {
        switch self {
        case .loaded, .missing: return nil
        case .refused(let refusal): return refusal.rawValue
        case .unreadable(let code): return code
        }
    }
}

/// The recent-molecules list in its storage file (see the file header).
final class RecentStore {
    /// The experience's storage, or nil for a list kept in memory only.
    let storage: ExperienceStorage?
    /// The molecule ids the list may hold (the library's); other ids are dropped when the file is read.
    let known: Set<String>
    /// What loading the file gave when the store was made.
    let loadResult: StoreLoad<RecentMolecules>
    /// The list, newest first.
    private(set) var recent: RecentMolecules
    /// Why the file could not be read or the last change could not be saved; empty otherwise.
    private(set) var message: String
    /// The stored bytes when there is no storage.
    private var memory: Data?
    /// The number of lists written (or bytes set in memory).
    private(set) var writes = 0

    /// The library's molecule ids (`water`, `methane`, `ethanol`, `benzene`, `caffeine`).
    static var libraryIDs: Set<String> { Set(MoleculeCore.library.map(\.id)) }

    /// A store over `storage` (in memory without storage) that loads the list once, with `known` as the ids it may
    /// hold (the library's by default). Nothing is written here.
    init(storage: ExperienceStorage?, known: Set<String> = RecentStore.libraryIDs) {
        self.storage = storage
        self.known = known
        let result = RecentStore.load(storage: storage, memory: nil, known: known)
        loadResult = result
        if case .loaded(let list) = result {
            recent = list
        } else {
            recent = RecentMolecules()
        }
        message = RecentStore.readWords(result)
    }

    /// The words shown for a load: "Recent molecules could not be read (<reason>)." for a refused or unreadable file,
    /// empty otherwise.
    static func readWords(_ result: StoreLoad<RecentMolecules>) -> String {
        guard let reason = result.failureReason else { return "" }
        return "Recent molecules could not be read (\(reason))."
    }

    /// The words shown for a refused write: "Recent molecules could not be saved (<storage code>)."
    static func saveWords(_ code: String) -> String {
        "Recent molecules could not be saved (\(code))."
    }

    /// The list stored in `storage` (or `memory` without storage), or why there is none. Nothing is written.
    static func load(storage: ExperienceStorage?, memory: Data?, known: Set<String>) -> StoreLoad<RecentMolecules> {
        let data: Data
        if let storage {
            do {
                data = try storage.read(RecentMolecules.fileName)
            } catch {
                if case .notFound = error { return .missing }
                return .unreadable(error.code)
            }
        } else {
            guard let memory else { return .missing }
            data = memory
        }
        switch RecentMolecules.decode(data, known: known) {
        case .success(let list): return .loaded(list)
        case .failure(let refusal): return .refused(refusal)
        }
    }

    /// Reads the stored list again, without writing (tests: what a new presenter over the same storage would see).
    func reload() -> StoreLoad<RecentMolecules> {
        Self.load(storage: storage, memory: memory, known: known)
    }

    /// Records `id` as the newest molecule (moved to the front, unique, at most 8). When the list changed and
    /// `persist` is true the list is written, replacing the file atomically; returns true when it was written. A
    /// refused write keeps the previous file and sets the message; the in-memory list changes either way.
    @discardableResult
    func record(_ id: String, persist: Bool = true) -> Bool {
        var next = recent
        next.record(id)
        guard next != recent else { return false }
        recent = next
        guard persist else { return false }
        let data = next.encoded()
        if let storage {
            do {
                try storage.write(data, to: RecentMolecules.fileName)
            } catch {
                message = Self.saveWords(error.code)
                return false
            }
        } else {
            memory = data
        }
        writes += 1
        message = ""
        return true
    }
}
