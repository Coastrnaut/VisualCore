// WorldStore — feature 091 (A12-P03) T-A12-303 (FR-A12-321, FR-A12-322, FR-A12-323; SC-A12-302–SC-A12-304;
// clarifications Q4 and Q5; research D4 and D5; data-model "WorldDocument", "Thumbnail"). The four saved worlds of Tiny
// Worlds in the experience's own storage, two files per slot (slots 0…3):
//   - `world-<slot>.json`: a `WorldDocument` (file schema 2, sorted keys, at most 64 KB);
//   - `world-<slot>.png`: the slot's thumbnail, a 160 × 120 PNG of at most 64 KB, written after the document.
// Every file is written through `ExperienceStorage.write`, which replaces it atomically: a reader sees the complete
// old or the complete new file, and a refused or interrupted write leaves what was stored byte for byte.
//   - Save: the document's `encode()` bytes (`too-large` refused before anything is written), then the thumbnail when
//     one is given and it is at most 64 KB; without one (no context to draw it) or when it is refused, the slot's old
//     picture is removed, so a slot never shows the picture of an earlier world. A refused document write is reported
//     with the storage error's code and changes nothing; a refused picture never undoes the saved document.
//   - Read: no file → `empty-slot`; a file that cannot be read → the storage error's code; otherwise
//     `WorldDocument.decode`: `too-large`, `damaged` (not JSON, truncated, malformed keys) or `newer-version`. Reading
//     never writes: a refused file stays as it was.
//   - Clear: removes both files; an empty slot reports `empty-slot`.
//   - Summaries: per slot, the stored name (empty for an empty or refused slot) and whether a picture is stored.
// A slot outside 0…3 is refused with `invalid-slot` before anything is touched. Without storage (tests and previews)
// the files are kept in memory with the same rules. The store never touches the core, so saving cannot change a state
// digest; opening goes through the presenter (`WorldsCore.openingSnapshot` and `ExperienceShell.restore`).
import Foundation
import TinyWorldsCore
import VisualCoreExperience

/// Why a slot could not be saved, read or cleared.
enum WorldStoreRefusal: Error, Equatable, Sendable {
    /// The slot holds no saved world.
    case emptySlot
    /// The slot number is outside 0…3.
    case invalidSlot
    /// The document was refused (`damaged`, `newer-version`, `too-large`).
    case document(WorldDocumentRefusal)
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

/// What one slot holds, for the slot list.
struct WorldSlotSummary: Equatable, Sendable {
    /// The stored name; empty for an empty or refused slot.
    var name: String
    /// Whether a picture is stored for the slot.
    var hasPicture: Bool
}

/// The saved worlds of Tiny Worlds in their storage files (see the file header).
final class WorldStore {
    /// The slot numbers.
    static let slots = 0...3
    /// The largest thumbnail in bytes (64 KB).
    static let maxThumbnailBytes = 65_536
    /// The thumbnail's width in pixels.
    static let thumbnailWidth = 160
    /// The thumbnail's height in pixels.
    static let thumbnailHeight = 120

    /// The document file of `slot`: `world-<slot>.json`.
    static func fileName(slot: Int) -> String { "world-\(slot).json" }
    /// The thumbnail file of `slot`: `world-<slot>.png`.
    static func pictureName(slot: Int) -> String { "world-\(slot).png" }

    /// The experience's storage, or nil for files kept in memory only.
    let storage: ExperienceStorage?
    /// The files by name when there is no storage.
    private var memory: [String: Data] = [:]
    /// The number of documents written (or set in memory).
    private(set) var writes = 0

    /// A store over `storage` (in memory without storage). Nothing is read or written here.
    init(storage: ExperienceStorage?) {
        self.storage = storage
    }

    /// Saves `document` to `slot`, replacing what the slot held, then `thumbnail` (see the file header). Returns
    /// whether a picture is stored with it; a refused document changes nothing.
    @discardableResult
    func save(_ document: WorldDocument, slot: Int, thumbnail: Data?) -> Result<Bool, WorldStoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        let data: Data
        switch document.encode() {
        case .success(let encoded): data = encoded
        case .failure(let refusal): return .failure(.document(refusal))
        }
        if let error = write(data, Self.fileName(slot: slot)) { return .failure(.storage(error)) }
        writes += 1
        if let thumbnail, !thumbnail.isEmpty, thumbnail.count <= Self.maxThumbnailBytes,
           write(thumbnail, Self.pictureName(slot: slot)) == nil {
            return .success(true)
        }
        remove(Self.pictureName(slot: slot))
        return .success(false)
    }

    /// The bytes of the file `name`, or the reason there are none.
    private func bytes(_ name: String) -> Result<Data, WorldStoreRefusal> {
        guard let storage else {
            guard let data = memory[name] else { return .failure(.emptySlot) }
            return .success(data)
        }
        do {
            return .success(try storage.read(name))
        } catch {
            if case .notFound = error { return .failure(.emptySlot) }
            return .failure(.storage(error))
        }
    }

    /// Writes `data` as `name`; nil on success, else the storage's refusal.
    private func write(_ data: Data, _ name: String) -> StorageError? {
        guard let storage else {
            memory[name] = data
            return nil
        }
        do {
            try storage.write(data, to: name)
            return nil
        } catch {
            return error
        }
    }

    /// Removes `name`; true when a file was removed.
    @discardableResult
    private func remove(_ name: String) -> Bool {
        guard let storage else { return memory.removeValue(forKey: name) != nil }
        guard storage.exists(name) else { return false }
        return (try? storage.remove(name)) != nil
    }

    /// The document bytes stored for `slot`, or the reason there are none.
    func bytes(slot: Int) -> Result<Data, WorldStoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        return bytes(Self.fileName(slot: slot))
    }

    /// The document saved in `slot`, or the reason it is refused; nothing is written.
    func read(slot: Int) -> Result<WorldDocument, WorldStoreRefusal> {
        switch bytes(slot: slot) {
        case .failure(let refusal): return .failure(refusal)
        case .success(let data): return WorldDocument.decode(data).mapError { .document($0) }
        }
    }

    /// The thumbnail stored for `slot`, or nil (no picture, a picture above 64 KB, or a slot outside 0…3).
    func thumbnail(slot: Int) -> Data? {
        guard Self.slots.contains(slot), case .success(let data) = bytes(Self.pictureName(slot: slot)),
              !data.isEmpty, data.count <= Self.maxThumbnailBytes else { return nil }
        return data
    }

    /// Removes the document and the picture of `slot`.
    @discardableResult
    func clear(slot: Int) -> Result<Void, WorldStoreRefusal> {
        guard Self.slots.contains(slot) else { return .failure(.invalidSlot) }
        let name = Self.fileName(slot: slot)
        if let storage {
            do {
                try storage.remove(name)
            } catch {
                if case .notFound = error { return .failure(.emptySlot) }
                return .failure(.storage(error))
            }
        } else if memory.removeValue(forKey: name) == nil {
            return .failure(.emptySlot)
        }
        remove(Self.pictureName(slot: slot))
        return .success(())
    }

    /// Each slot's stored name (empty for an empty or refused slot) and whether a picture is stored.
    func summaries() -> [WorldSlotSummary] {
        Self.slots.map { slot in
            let name = (try? read(slot: slot).get())?.name ?? ""
            return WorldSlotSummary(name: name, hasPicture: thumbnail(slot: slot) != nil)
        }
    }
}
