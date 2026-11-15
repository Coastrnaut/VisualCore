// ExperimentStore — feature 085 (A11-P04) T-A11-403 (FR-A11-403; SC-A11-402; clarification 3; research D3; contract
// contracts/experiments.md "Files"; edge cases "An empty slot", "Storage unavailable or full"). The four saved
// experiments of Physics Playground in the experience's own storage, one file per slot: `experiment-0.json` …
// `experiment-3.json`, each an `ExperimentDocument` (file schema 1, sorted keys).
//   - Save: the document's `encoded()` bytes written through `ExperienceStorage.write`, which replaces the file
//     atomically (a reader sees the complete old or the complete new file; a refused write leaves what was stored). A
//     refused write is reported with the storage error's code and changes nothing.
//   - Read: no file → `empty-slot`; a file that cannot be read → the storage error's code; otherwise
//     `ExperimentDocument.decode` with the bundled catalog: `damaged` (not JSON, truncated, malformed keys),
//     `newer-version` (file schema above 1) or `invalid-world` (the world does not decode or validate). Reading never
//     writes: a refused file stays byte for byte as it was.
//   - Clear: removes the slot's file; an empty slot reports `empty-slot`.
//   - Summaries: the stored name of each slot, or an empty text for an empty or refused slot.
// A slot outside 0…3 is refused with `invalid-slot` before anything is touched. Without storage (tests and previews)
// the documents' bytes are kept in memory with the same rules. The store never touches the core, so saving cannot
// change a state digest; opening goes through the presenter (`PlaygroundCore.opening`).
import Foundation
import PhysicsPlaygroundCore
import VisualCoreExperience

/// Why a slot could not be saved, read or cleared.
enum StoreRefusal: Error, Equatable, Sendable {
    /// The slot holds no saved experiment.
    case emptySlot
    /// The slot number is outside 0…3.
    case invalidSlot
    /// The file was read but refused (`damaged`, `newer-version`, `invalid-world`).
    case document(DocumentRefusal)
    /// The storage refused the operation.
    case storage(StorageError)

    /// The stable code: `empty-slot`, `invalid-slot`, the document refusal's raw value or the storage error's code.
    var code: String {
        switch self {
        case .emptySlot: "empty-slot"
        case .invalidSlot: "invalid-slot"
        case .document(let refusal): refusal.rawValue
        case .storage(let error): error.code
        }
    }
}

/// The saved experiments of Physics Playground in their storage files (see the file header).
final class ExperimentStore {
    /// The slot numbers.
    static let slots = ExperimentOrigin.validRange

    /// The storage file of `slot`: `experiment-<slot>.json`.
    static func fileName(slot: Int) -> String { "experiment-\(slot).json" }

    /// The experience's storage, or nil for documents kept in memory only.
    let storage: ExperienceStorage?
    /// The bytes of each slot when there is no storage.
    private var memory: [Int: Data] = [:]
    /// The number of files written (or slots set in memory).
    private(set) var writes = 0

    /// A store over `storage` (in memory without storage). Nothing is read or written here.
    init(storage: ExperienceStorage?) {
        self.storage = storage
    }

    /// Saves `document` to `slot`, replacing what the slot held; a refusal changes nothing.
    @discardableResult
    func save(_ document: ExperimentDocument, slot: Int) -> Result<Void, StoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        let data = document.encoded()
        guard !data.isEmpty else { return .failure(.document(.invalidWorld)) }
        if let storage {
            do {
                try storage.write(data, to: Self.fileName(slot: slot))
            } catch {
                return .failure(.storage(error))
            }
        } else {
            memory[slot] = data
        }
        writes += 1
        return .success(())
    }

    /// The bytes stored for `slot`, or the reason there are none.
    func bytes(slot: Int) -> Result<Data, StoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        guard let storage else {
            guard let data = memory[slot] else { return .failure(.emptySlot) }
            return .success(data)
        }
        do {
            return .success(try storage.read(Self.fileName(slot: slot)))
        } catch {
            if case .notFound = error { return .failure(.emptySlot) }
            return .failure(.storage(error))
        }
    }

    /// The document saved in `slot`, or the reason it is refused; nothing is written.
    func read(slot: Int) -> Result<ExperimentDocument, StoreRefusal> {
        switch bytes(slot: slot) {
        case .failure(let refusal):
            return .failure(refusal)
        case .success(let data):
            return ExperimentDocument.decode(data, catalog: PlaygroundCore.catalog).mapError { .document($0) }
        }
    }

    /// Removes the file of `slot`.
    @discardableResult
    func clear(slot: Int) -> Result<Void, StoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        guard let storage else {
            return memory.removeValue(forKey: slot) == nil ? .failure(.emptySlot) : .success(())
        }
        do {
            try storage.remove(Self.fileName(slot: slot))
            return .success(())
        } catch {
            if case .notFound = error { return .failure(.emptySlot) }
            return .failure(.storage(error))
        }
    }

    /// The stored name of each slot 0…3, or an empty text for an empty or refused slot.
    func summaries() -> [String] {
        Self.slots.map { slot in
            guard case .success(let document) = read(slot: slot) else { return "" }
            return document.name
        }
    }
}
