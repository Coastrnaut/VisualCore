// GardenLibrary — feature 148 (A20-P04) T-A20-402 (FR-A20-401, FR-A20-402; SC-A20-401; clarifications Q1, Q5;
// data-model.md "library.json", "garden-<n>.json", "GardenLibrary"; contracts/library.md "Library"; gap G-LIBRARY).
// The named gardens of Digital Zen Garden, one file per garden in the experience's own storage (`ExperienceStorage`,
// whose quota is 16 MiB and 64 files), as Fractal Explorer's bookmarks:
//
//   - `garden-<n>.json`: the envelope `{"body", "kind": "a20.saved-garden", "version": 1}` whose body is
//     `{name, order, document}` (the document as `GardenDocument` encodes it); at most 262,144 bytes. n is a counter,
//     never reused while the index or a higher file exists (no UUIDs).
//   - `library.json`: the envelope `{"body", "kind": "a20.garden-library", "version": 1}` whose body is
//     `{next, entries: [{file, name, order}]}`: the counter and the names of the files. The garden files are the
//     truth: the list is read from them, and the index keeps the counter and the name of a garden whose file became
//     unreadable. A damaged index is rebuilt by the next change; an index of a newer version makes the library read
//     only (opening still works) so a newer build's index is never overwritten.
//   - Caps: at most 12 gardens (unreadable files count, as they hold storage; the person can delete them); a name is
//     trimmed and 1…40 characters. Saving under an existing name (compared without regard to case) replaces that
//     garden (the controls ask the person first); renaming to a name another garden has is refused.
//   - Refusals: a damaged, newer-version or oversized file (or one whose document is refused) is listed as unreadable
//     with its code (`damaged`, `newer-version`, `too-large` or the `DocumentRefusal` code) and is never opened or
//     deleted automatically. Writes go through `storage.write`, which is atomic: a failed write (a quota or a file
//     system error) keeps the previous file of that name unchanged.
//   - Messages: "The library holds 12 gardens." and "A garden is already called <name>." (data-model.md), plus the
//     sentences of `GardenLibraryFailure.message`.
//   - Order: each save takes the next modification order (the largest + 1); a rename keeps it. The list shows the
//     readable gardens newest first, then the unreadable files by number.
//
// The presenter's library actions (save, open, rename, delete, with their announcements) are at the end of this
// file. Opening restores the saved document through the shell's restore path (clarification Q5): the undo history
// restarts and the digest equals the opened document's. No network, no clock, no Photos call.
import Foundation
import DigitalZenGardenCore
import Observation
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation

/// One saved garden of the library: readable (with its name and order) or unreadable (with its refusal code).
struct GardenLibraryEntry: Equatable, Identifiable, Sendable {
    /// The file in the experience's storage: `garden-<n>.json`.
    var file: String
    /// The garden's name; for an unreadable file the name the index remembers, else the file name.
    var name: String
    /// The modification order (larger is newer); 0 for an unreadable file.
    var order: Int
    /// The refusal code of an unreadable file (`damaged`, `newer-version`, `too-large`, or a `DocumentRefusal`
    /// code); nil when the file is readable.
    var refusal: String?

    /// The entry's identity: its file name.
    var id: String { file }
    /// Whether the file can be opened.
    var isReadable: Bool { refusal == nil }
    /// The file's counter n of `garden-<n>.json` (0 if the name does not parse).
    var number: Int { GardenLibrary.number(of: file) ?? 0 }
}

/// Why a library operation was refused; a refused operation changes nothing on disk.
enum GardenLibraryFailure: Error, Equatable, Sendable {
    /// A 13th garden: "The library holds 12 gardens."
    case full
    /// A name that is empty or longer than 40 characters after trimming.
    case invalidName
    /// Renaming to the name of another garden (the name as stored).
    case nameTaken(String)
    /// The garden's file would be larger than 262,144 bytes (its size).
    case tooLarge(Int)
    /// The saved file cannot be opened or renamed (its refusal code).
    case unreadable(String)
    /// No saved garden has this file.
    case notFound
    /// The index was written by a newer version, so the library is read only.
    case readOnly
    /// The library is not available (the experience was made without storage).
    case unavailable
    /// The storage refused the write or the removal (its `StorageError` code, or `a20.encoding`).
    case storage(String)

    /// The stable code of the failure.
    var code: String {
        switch self {
        case .full: return "a20.library-full"
        case .invalidName: return "a20.invalid-name"
        case .nameTaken: return "a20.name-taken"
        case .tooLarge: return "a20.too-large"
        case .unreadable(let code): return "a20." + code
        case .notFound: return "a20.not-found"
        case .readOnly: return "a20.read-only"
        case .unavailable: return "a20.unavailable"
        case .storage(let code): return code
        }
    }

    /// One sentence for the person.
    var message: String {
        switch self {
        case .full:
            return GardenLibrary.fullMessage
        case .invalidName:
            return "A garden name has 1 to \(GardenLibrary.maxNameLength) characters."
        case .nameTaken(let name):
            return GardenLibrary.takenMessage(name)
        case .tooLarge(let bytes):
            return "The garden is too large to save: \(bytes) bytes, above the limit of "
                + "\(GardenLibrary.maxFileBytes) bytes."
        case .unreadable(let code):
            return "This saved garden cannot be opened (\(code))."
        case .notFound:
            return "This saved garden is no longer in the library."
        case .readOnly:
            return "The library was written by a newer version, so it cannot be changed."
        case .unavailable:
            return "The library is not available."
        case .storage(let code):
            return "The library could not be changed (\(code))."
        }
    }
}

/// The named gardens in the experience's storage (see the file header).
@MainActor
@Observable
final class GardenLibrary {
    /// The index file.
    nonisolated static let indexFile = "library.json"
    /// The envelope kind of the index.
    nonisolated static let indexKind = "a20.garden-library"
    /// The envelope kind of a saved garden.
    nonisolated static let gardenKind = "a20.saved-garden"
    /// The schema version of both files.
    nonisolated static let schemaVersion = 1
    /// The most gardens the library holds.
    nonisolated static let maxGardens = 12
    /// The longest name, in characters, after trimming.
    nonisolated static let maxNameLength = 40
    /// The largest saved garden file, in bytes.
    nonisolated static let maxFileBytes = 262_144
    /// The message of a 13th save.
    nonisolated static let fullMessage = "The library holds \(maxGardens) gardens."

    /// The message of a rename to a used name: "A garden is already called <name>.".
    nonisolated static func takenMessage(_ name: String) -> String { "A garden is already called \(name)." }

    /// The body of a saved garden file.
    struct SavedGarden: Codable, Equatable, Sendable {
        /// The garden's name.
        var name: String
        /// The modification order.
        var order: Int
        /// The garden.
        var document: GardenDocument
    }

    /// The body of the index file.
    struct Index: Codable, Equatable, Sendable {
        /// One indexed file.
        struct Item: Codable, Equatable, Sendable {
            /// The file name.
            var file: String
            /// The garden's name.
            var name: String
            /// The modification order.
            var order: Int
        }

        /// The next file counter.
        var next: Int
        /// The indexed files.
        var entries: [Item]
    }

    private struct Envelope<Body: Codable>: Codable {
        var kind: String
        var version: Int
        var body: Body?
    }

    private struct Header: Decodable {
        var kind: String
        var version: Int
    }

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The saved gardens: the readable ones newest first, then the unreadable ones by number.
    private(set) var entries: [GardenLibraryEntry] = []
    /// The next file counter.
    private(set) var next = 1
    /// Whether the index was written by a newer version (the library is then read only).
    private(set) var isReadOnly = false
    /// The refusal code of the index when it could not be read; nil when it was read or there is none.
    private(set) var indexProblem: String?

    /// A library over `storage`; reads the index and the garden files once.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    // MARK: Names and files

    /// The file of counter `n`: `garden-<n>.json`.
    nonisolated static func fileName(_ n: Int) -> String { "garden-\(n).json" }

    /// The counter n of a file named `garden-<n>.json` (n ≥ 1, decimal digits only); nil otherwise.
    nonisolated static func number(of file: String) -> Int? {
        let head = "garden-", tail = ".json"
        guard file.hasPrefix(head), file.hasSuffix(tail), file.count > head.count + tail.count else { return nil }
        let digits = file.dropFirst(head.count).dropLast(tail.count)
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(digits), n >= 1 else { return nil }
        return n
    }

    /// `raw` trimmed of white space and new lines when it then has 1…40 characters; nil otherwise.
    nonisolated static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...maxNameLength).contains(trimmed.count) else { return nil }
        return trimmed
    }

    /// The readable garden called `name` (trimmed; compared without regard to case); nil when there is none.
    func entry(named name: String) -> GardenLibraryEntry? {
        guard let clean = Self.cleanName(name) else { return nil }
        return entries.first { $0.isReadable && $0.name.caseInsensitiveCompare(clean) == .orderedSame }
    }

    /// The entry of `file`; nil when there is none.
    func entry(file: String) -> GardenLibraryEntry? { entries.first { $0.file == file } }

    /// The readable gardens.
    var readable: [GardenLibraryEntry] { entries.filter(\.isReadable) }

    // MARK: Files

    /// The saved garden file of `garden`: sorted keys, unescaped slashes. Throws when a number is not finite.
    nonisolated static func encode(_ garden: SavedGarden) throws -> Data {
        try encoder().encode(Envelope(kind: gardenKind, version: schemaVersion, body: garden))
    }

    /// Reads a saved garden file. Checks, in order: the size (`too-large`), the envelope and its kind (`damaged`),
    /// the version (`newer-version`), the body and its name (`damaged`), then the document (`validate()`).
    nonisolated static func decode(_ data: Data) -> Result<SavedGarden, DocumentRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == gardenKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope<SavedGarden>.self, from: data),
              let garden = envelope.body, let name = cleanName(garden.name), name == garden.name,
              garden.order >= 0 else { return .failure(.damaged) }
        if let refusal = garden.document.validate() { return .failure(refusal) }
        return .success(garden)
    }

    /// The index file of `index`.
    nonisolated static func encode(_ index: Index) throws -> Data {
        try encoder().encode(Envelope(kind: indexKind, version: schemaVersion, body: index))
    }

    /// Reads the index file: `damaged` (not the envelope, the wrong kind or body), `newer-version` or `too-large`
    /// (above 262,144 bytes).
    nonisolated static func decodeIndex(_ data: Data) -> Result<Index, DocumentRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == indexKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope<Index>.self, from: data), let index = envelope.body,
              index.next >= 1 else { return .failure(.damaged) }
        return .success(index)
    }

    nonisolated private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Reads the index and every garden file again.
    func reload() {
        var index = Index(next: 1, entries: [])
        isReadOnly = false
        indexProblem = nil
        if storage.exists(Self.indexFile) {
            let read: Result<Index, DocumentRefusal>
            do {
                read = Self.decodeIndex(try storage.read(Self.indexFile))
            } catch {
                read = .failure(.damaged)
            }
            switch read {
            case .success(let found):
                index = found
            case .failure(let refusal):
                indexProblem = refusal.code
                if case .newerVersion = refusal { isReadOnly = true }
            }
        }
        let names = Dictionary(index.entries.map { ($0.file, $0.name) }, uniquingKeysWith: { first, _ in first })
        var good: [GardenLibraryEntry] = []
        var bad: [GardenLibraryEntry] = []
        var highest = 0
        for file in storage.list() {
            guard let n = Self.number(of: file) else { continue }
            highest = max(highest, n)
            let decoded: Result<SavedGarden, DocumentRefusal>
            do {
                decoded = Self.decode(try storage.read(file))
            } catch {
                decoded = .failure(.damaged)
            }
            switch decoded {
            case .success(let garden):
                good.append(GardenLibraryEntry(file: file, name: garden.name, order: garden.order, refusal: nil))
            case .failure(let refusal):
                bad.append(GardenLibraryEntry(file: file, name: names[file] ?? file, order: 0, refusal: refusal.code))
            }
        }
        good.sort { $0.order != $1.order ? $0.order > $1.order : $0.number > $1.number }
        bad.sort { $0.number < $1.number }
        entries = good + bad
        next = max(index.next, highest + 1, 1)
    }

    /// Writes the index of the current entries; a failure is ignored (the garden files are the truth and the counter
    /// is recovered from them).
    private func writeIndex() {
        let items = entries.map { Index.Item(file: $0.file, name: $0.name, order: $0.order) }
        guard let data = try? Self.encode(Index(next: next, entries: items)) else { return }
        try? storage.write(data, to: Self.indexFile)
    }

    /// Writes `garden` to `file`; the failure of an oversized file or of the storage, or nil.
    private func write(_ garden: SavedGarden, to file: String) -> GardenLibraryFailure? {
        let data: Data
        do {
            data = try Self.encode(garden)
        } catch {
            return .storage("a20.encoding")
        }
        guard data.count <= Self.maxFileBytes else { return .tooLarge(data.count) }
        do {
            try storage.write(data, to: file)
        } catch {
            return .storage(error.code)
        }
        return nil
    }

    // MARK: Operations

    /// Saves `document` as `name` (trimmed, 1…40 characters): replaces the garden of that name (compared without
    /// regard to case, keeping its file and taking the new name's spelling), else writes a new file when the library
    /// holds fewer than 12 gardens. Returns the saved entry.
    @discardableResult
    func save(name raw: String, document: GardenDocument) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let name = Self.cleanName(raw) else { return .failure(.invalidName) }
        let existing = entry(named: name)
        if existing == nil, entries.count >= Self.maxGardens { return .failure(.full) }
        let order = (entries.map(\.order).max() ?? 0) + 1
        let file = existing?.file ?? Self.fileName(next)
        if let failure = write(SavedGarden(name: name, order: order, document: document), to: file) {
            return .failure(failure)
        }
        if existing == nil { next += 1 }
        reload()
        writeIndex()
        return entry(file: file).map { .success($0) } ?? .failure(.notFound)
    }

    /// The document of the readable garden `file`, read again from its file. An unreadable file is refused with its
    /// code (and the list is read again when the file changed since it was listed).
    func open(_ file: String) -> Result<(entry: GardenLibraryEntry, document: GardenDocument), GardenLibraryFailure> {
        guard let entry = entry(file: file) else { return .failure(.notFound) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        switch read(file) {
        case .success(let garden):
            return .success((entry, garden.document))
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
    }

    /// Renames the readable garden `file` to `name` (trimmed, 1…40 characters), keeping its order; refused with
    /// "A garden is already called <name>." when another garden has that name.
    @discardableResult
    func rename(_ file: String, to raw: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.notFound) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        guard let name = Self.cleanName(raw) else { return .failure(.invalidName) }
        if let other = self.entry(named: name), other.file != file { return .failure(.nameTaken(other.name)) }
        let garden: SavedGarden
        switch read(file) {
        case .success(let found):
            garden = found
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
        if let failure = write(SavedGarden(name: name, order: garden.order, document: garden.document), to: file) {
            return .failure(failure)
        }
        reload()
        writeIndex()
        return self.entry(file: file).map { .success($0) } ?? .failure(.notFound)
    }

    /// Removes the garden `file`, readable or not (only when the person asks; nothing is deleted automatically).
    @discardableResult
    func delete(_ file: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.notFound) }
        do {
            try storage.remove(file)
        } catch {
            reload()
            return .failure(.storage(error.code))
        }
        reload()
        writeIndex()
        return .success(entry)
    }

    /// The saved garden of `file`, or the failure of a missing or unreadable file.
    private func read(_ file: String) -> Result<SavedGarden, GardenLibraryFailure> {
        let data: Data
        do {
            data = try storage.read(file)
        } catch {
            return .failure(.notFound)
        }
        return Self.decode(data).mapError { .unreadable($0.code) }
    }
}

// MARK: - The presenter's library actions

extension GardenPresenter {
    /// Saves the current garden as `name` (replacing a garden of that name; the controls ask first) and announces
    /// "Saved <name>." or the refusal.
    @discardableResult
    func saveGarden(named name: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let result = library.save(name: name, document: currentCore.document)
        switch result {
        case .success(let entry):
            openedName = entry.name
            report("Saved \(entry.name).", kind: .outcome)
        case .failure(let failure):
            report(failure.message, kind: .rejection)
        }
        return result
    }

    /// Opens the saved garden `file`: its document replaces the garden through the shell's restore path (the undo
    /// history restarts) and "Opened <name>." is announced, or the refusal.
    @discardableResult
    func openGarden(_ file: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        switch library.open(file) {
        case .success(let opened):
            cancelPointers()
            guard restoreDocument?(opened.document) == true else {
                return refuse(.unreadable("restore-refused"))
            }
            openedName = opened.entry.name
            report("Opened \(opened.entry.name).", kind: .outcome)
            return .success(opened.entry)
        case .failure(let failure):
            return refuse(failure)
        }
    }

    /// Renames the saved garden `file` to `name` and announces "Renamed <old> to <new>." or the refusal.
    @discardableResult
    func renameGarden(_ file: String, to name: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let old = library.entry(file: file)?.name ?? file
        let result = library.rename(file, to: name)
        switch result {
        case .success(let entry):
            if openedName == old { openedName = entry.name }
            report("Renamed \(old) to \(entry.name).", kind: .outcome)
        case .failure(let failure):
            report(failure.message, kind: .rejection)
        }
        return result
    }

    /// Deletes the saved garden `file` (the open garden stays as it is) and announces "Deleted <name>." or the
    /// refusal.
    @discardableResult
    func deleteGarden(_ file: String) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let result = library.delete(file)
        switch result {
        case .success(let entry):
            report("Deleted \(entry.name).", kind: .outcome)
        case .failure(let failure):
            report(failure.message, kind: .rejection)
        }
        return result
    }

    /// Reports `failure` (message and announcement) and returns it.
    private func refuse(_ failure: GardenLibraryFailure) -> Result<GardenLibraryEntry, GardenLibraryFailure> {
        report(failure.message, kind: .rejection)
        return .failure(failure)
    }

    /// Shows `text` as the library's message and announces it with `kind`.
    func report(_ text: String, kind: AnnouncementKind) {
        mirror.libraryMessage = text
        announce(text, kind: kind)
    }
}
