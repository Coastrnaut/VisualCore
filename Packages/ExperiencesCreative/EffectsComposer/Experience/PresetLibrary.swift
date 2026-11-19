// PresetLibrary — feature 182 (A25-P03) T-A25-302 (FR-A25-302, FR-A25-303; clarification Q2; data-model.md "Preset
// file", "Index", "Caps"; contracts/presets.md; gap G-PRESETS). The named chains of Effects Composer, one file per
// preset in the experience's own storage (`ExperienceStorage`, whose quota is 16 MiB and 64 files), after Visual
// Programming Lab's `GraphLibrary` and Graphics Benchmark Lab's `ResultLibrary`:
//
//   - `preset-<n>.json`: the envelope `{"body", "kind": "a25.preset", "version": 1}` whose body is
//     `{chain, name, order}`; at most 69,632 bytes. n is a counter, never reused while the index or a higher file
//     exists (no UUIDs).
//   - `chain` is the `ChainDocument` encoding (its own envelope `a25.effect-chain`, version 1, at most 65,536 bytes)
//     embedded as a JSON object, not as an escaped string. On reading, the embedded chain is written back with sorted
//     keys and handed to `ChainDocument.decode`, so every `ChainRefusal` of the chain file applies to it unchanged.
//   - `presets.json`: the envelope `{"body", "kind": "a25.preset-library", "version": 1}` whose body is
//     `{entries: [{file, name, order}], next}`: the counter and the names. The preset files are the truth: the list
//     is read from them, and the index keeps the counter and the name of a preset whose file became unreadable. A
//     damaged index is rebuilt only by the next change; an index of a newer version makes the library read only
//     (opening still works) so that a newer build's index is never overwritten.
//   - Caps: at most 24 presets (unreadable files count, as they hold storage; the person may remove them); a name is
//     trimmed and 1…40 characters; names that differ only in case are the same. Saving or renaming to a name another
//     preset has is refused.
//   - Refusals of a file: `damaged`, `newer-version`, `too-large` (above 69,632 bytes), or the `ChainRefusal` code of
//     the embedded chain. Such a file is listed as unreadable with its code and is never opened, renamed or deleted
//     automatically; the person may remove it. Writes go through `storage.write`, which is atomic: a failed write (a
//     quota or a file system error) keeps the previous file of that name, so a refusal changes nothing.
//   - Messages: "The library holds 24 presets.", "A name has 1 to 40 characters.", "A preset is already called
//     <name>." and "There is not enough space to save this preset." (a storage quota of bytes or files), plus the
//     sentences of `PresetLibraryFailure.message`.
//   - Order: each save takes the next modification order (the largest + 1); a rename keeps it. The list shows the
//     readable presets newest first, then the unreadable files by number.
//
// The library is independent of the presenter: it is made with an `ExperienceStorage` and returns what was saved or
// opened. No network, no clock, no UUID, no graphics.
import EffectsComposerCore
import Foundation
import Observation
import VisualCoreExperience

/// Whether a preset file can be opened, or the code of its refusal.
enum PresetLibraryState: Equatable, Sendable {
    /// The file reads as a preset.
    case readable
    /// The file was refused with this code (`damaged`, `newer-version`, `too-large` or a chain file code).
    case unreadable(String)
}

/// One preset of the library: readable (with its name and order) or unreadable (with its refusal code).
struct PresetLibraryEntry: Equatable, Identifiable, Sendable {
    /// The file in the experience's storage: `preset-<n>.json`.
    var file: String
    /// The preset's name; for an unreadable file the name the index remembers, else the file name.
    var name: String
    /// The modification order (larger is newer); 0 for an unreadable file.
    var order: Int
    /// Whether the file can be opened.
    var state: PresetLibraryState

    /// The entry's identity: its file name.
    var id: String { file }
    /// Whether the file can be opened and renamed.
    var isReadable: Bool { state == .readable }
    /// The refusal code of an unreadable file; nil when the file is readable.
    var refusal: String? {
        if case .unreadable(let code) = state { return code }
        return nil
    }
    /// The file's counter n of `preset-<n>.json` (0 if the name does not parse).
    var number: Int { PresetLibrary.number(of: file) ?? 0 }
    /// The file's name without `.json` (`preset-<n>`).
    var stem: String { file.hasSuffix(".json") ? String(file.dropLast(5)) : file }
}

/// Why a library operation was refused; a refused operation changes nothing on disk.
enum PresetLibraryFailure: Error, Equatable, Sendable {
    /// A 25th preset: "The library holds 24 presets."
    case full
    /// A name that is empty or longer than 40 characters after trimming: "A name has 1 to 40 characters."
    case badName
    /// Saving or renaming to the name of another preset (the name as stored).
    case taken(String)
    /// The preset file cannot be opened or renamed (its refusal code).
    case unreadable(String)
    /// No preset has this file.
    case missing
    /// The storage quota (bytes or files) refused the write: "There is not enough space to save this preset."
    case noSpace
    /// The storage refused the write or the removal for another reason.
    case storage(StorageError)
    /// The library is not available (the experience was made without storage).
    case unavailable
    /// The index was written by a newer version, so the library is read only (opening still works).
    case readOnly
    /// The chain itself cannot be saved (its `ChainRefusal` code); no edit of the core makes such a chain.
    case chain(String)

    /// The stable code of the failure.
    var code: String {
        switch self {
        case .full: return "a25.library-full"
        case .badName: return "a25.invalid-name"
        case .taken: return "a25.name-taken"
        case .unreadable(let code): return "a25." + code
        case .missing: return "a25.not-found"
        case .noSpace: return "a25.no-space"
        case .storage(let error): return error.code
        case .unavailable: return "a25.unavailable"
        case .readOnly: return "a25.read-only"
        case .chain(let code): return "a25.chain-" + code
        }
    }

    /// One sentence for the person.
    var message: String {
        switch self {
        case .full: return PresetLibrary.fullMessage
        case .badName: return PresetLibrary.nameMessage
        case .taken(let name): return PresetLibrary.takenMessage(name)
        case .unreadable(let code): return "This preset cannot be opened (\(code))."
        case .missing: return "This preset is no longer in the library."
        case .noSpace: return PresetLibrary.noSpaceMessage
        case .storage(let error): return "The library could not be changed (\(error.code))."
        case .unavailable: return "The library is not available."
        case .readOnly: return "The library was written by a newer version, so it cannot be changed."
        case .chain(let code): return "This chain cannot be saved (\(code))."
        }
    }
}

/// A JSON value of any shape, used to embed the `ChainDocument` encoding as an object in a preset file.
enum PresetJSONValue: Codable, Equatable, Sendable {
    /// `null`.
    case null
    /// `true` or `false`.
    case bool(Bool)
    /// A whole number that fits `Int`.
    case int(Int)
    /// Any other number.
    case double(Double)
    /// A string.
    case string(String)
    /// An array.
    case array([PresetJSONValue])
    /// An object (written with sorted keys by the library's encoder).
    case object([String: PresetJSONValue])

    /// Decodes any JSON value: null, then a whole number, a number, a Boolean, a string, an array, an object
    /// (numbers first, so that a 0 or 1 is never read as a Boolean).
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PresetJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: PresetJSONValue].self))
        }
    }

    /// Encodes the value as it was read.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// The named chains in the experience's storage (see the file header).
@MainActor
@Observable
final class PresetLibrary {
    /// The index file.
    nonisolated static let indexFile = "presets.json"
    /// The envelope kind of the index.
    nonisolated static let indexKind = "a25.preset-library"
    /// The envelope kind of a preset file.
    nonisolated static let presetKind = "a25.preset"
    /// The schema version of both files.
    nonisolated static let schemaVersion = 1
    /// The most presets the library holds (unreadable files count).
    nonisolated static let maxPresets = 24
    /// The longest name, in characters, after trimming.
    nonisolated static let maxNameLength = 40
    /// The largest preset file (and index), in bytes.
    nonisolated static let maxFileBytes = 69_632
    /// The message of a 25th save.
    nonisolated static let fullMessage = "The library holds \(maxPresets) presets."
    /// The message of an empty or too long name.
    nonisolated static let nameMessage = "A name has 1 to \(maxNameLength) characters."
    /// The message of a save the storage quota refused.
    nonisolated static let noSpaceMessage = "There is not enough space to save this preset."

    /// The message of a save or rename to a used name: "A preset is already called <name>.".
    nonisolated static func takenMessage(_ name: String) -> String { "A preset is already called \(name)." }

    /// The body of a preset file.
    struct SavedPreset: Codable, Equatable, Sendable {
        /// The `ChainDocument` encoding, as a JSON object.
        var chain: PresetJSONValue
        /// The preset's name in the library.
        var name: String
        /// The modification order.
        var order: Int
    }

    /// The body of the index file.
    struct Index: Codable, Equatable, Sendable {
        /// One indexed file.
        struct Item: Codable, Equatable, Sendable {
            /// The file name.
            var file: String
            /// The preset's name.
            var name: String
            /// The modification order.
            var order: Int
        }

        /// The indexed files.
        var entries: [Item]
        /// The next file counter.
        var next: Int
    }

    /// The envelope of both files.
    private struct Envelope<Body: Codable>: Codable {
        /// The body.
        var body: Body?
        /// The kind.
        var kind: String
        /// The schema version.
        var version: Int
    }

    /// The envelope's kind and version, read first.
    private struct Header: Decodable {
        /// The kind.
        var kind: String
        /// The schema version.
        var version: Int
    }

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The presets: the readable ones newest first, then the unreadable ones by number.
    private(set) var entries: [PresetLibraryEntry] = []
    /// The next file counter.
    private(set) var next = 1
    /// Whether the index was written by a newer version (the library is then read only).
    private(set) var isReadOnly = false
    /// The refusal code of the index when it could not be read; nil when it was read or there is none.
    private(set) var indexProblem: String?

    /// A library over `storage`; reads the index and the preset files once. Nothing is written.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    // MARK: Names and files

    /// The file of counter `n`: `preset-<n>.json`.
    nonisolated static func fileName(_ n: Int) -> String { "preset-\(n).json" }

    /// The counter n of a file named `preset-<n>.json` (n ≥ 1, decimal digits only); nil otherwise.
    nonisolated static func number(of file: String) -> Int? {
        let head = "preset-", tail = ".json"
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

    /// The readable preset called `name` (trimmed; compared without regard to case); nil when there is none.
    func entry(named name: String) -> PresetLibraryEntry? {
        guard let clean = Self.cleanName(name) else { return nil }
        return entries.first { $0.isReadable && $0.name.caseInsensitiveCompare(clean) == .orderedSame }
    }

    /// The entry of `file`; nil when there is none.
    func entry(file: String) -> PresetLibraryEntry? { entries.first { $0.file == file } }

    /// The readable presets.
    var readable: [PresetLibraryEntry] { entries.filter(\.isReadable) }

    // MARK: Encoding

    /// The encoder of both files: sorted keys, unescaped slashes.
    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The preset file of `chain` named `name` with `order`: the envelope with sorted keys and the chain file's
    /// object embedded. Throws an encoding error only (the chain file encoding is total).
    nonisolated static func encode(name: String, order: Int, chain: EffectChain) throws -> Data {
        let embedded = try JSONDecoder().decode(PresetJSONValue.self, from: ChainDocument.encode(chain))
        let body = SavedPreset(chain: embedded, name: name, order: order)
        return try encoder().encode(Envelope(body: body, kind: presetKind, version: schemaVersion))
    }

    /// Reads a preset file. Checks, in order: the size (`too-large`), the envelope and its kind (`damaged`), the
    /// version (`newer-version`), the body and its name (`damaged`), then the embedded chain through
    /// `ChainDocument.decode` (any `ChainRefusal`).
    nonisolated static func decode(_ data: Data) -> Result<(saved: SavedPreset, chain: EffectChain), ChainRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == presetKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion) }
        guard let envelope = try? decoder.decode(Envelope<SavedPreset>.self, from: data),
              let saved = envelope.body, let name = cleanName(saved.name), name == saved.name,
              saved.order >= 0 else { return .failure(.damaged) }
        guard case .object = saved.chain, let chainData = try? encoder().encode(saved.chain) else {
            return .failure(.damaged)
        }
        return ChainDocument.decode(chainData).map { (saved: saved, chain: $0) }
    }

    /// The index file of `index`.
    nonisolated static func encode(_ index: Index) throws -> Data {
        try encoder().encode(Envelope(body: index, kind: indexKind, version: schemaVersion))
    }

    /// Reads the index file: `damaged` (not the envelope, the wrong kind or body), `newer-version` or `too-large`
    /// (above 69,632 bytes).
    nonisolated static func decodeIndex(_ data: Data) -> Result<Index, ChainRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == indexKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion) }
        guard let envelope = try? decoder.decode(Envelope<Index>.self, from: data), let index = envelope.body,
              index.next >= 1 else { return .failure(.damaged) }
        return .success(index)
    }

    /// The failure of a refused storage write: a quota of bytes or files is ``PresetLibraryFailure/noSpace``.
    nonisolated static func failure(of error: StorageError) -> PresetLibraryFailure {
        if case .quotaExceeded = error { return .noSpace }
        return .storage(error)
    }

    // MARK: Reading and writing

    /// Reads the index and every preset file again. Nothing is written or removed.
    func reload() {
        var index = Index(entries: [], next: 1)
        isReadOnly = false
        indexProblem = nil
        if storage.exists(Self.indexFile) {
            let indexRead: Result<Index, ChainRefusal>
            do {
                indexRead = Self.decodeIndex(try storage.read(Self.indexFile))
            } catch {
                indexRead = .failure(.damaged)
            }
            switch indexRead {
            case .success(let found):
                index = found
            case .failure(let refusal):
                indexProblem = refusal.code
                if refusal == .newerVersion { isReadOnly = true }
            }
        }
        let names = Dictionary(index.entries.map { ($0.file, $0.name) }, uniquingKeysWith: { first, _ in first })
        var good: [PresetLibraryEntry] = []
        var bad: [PresetLibraryEntry] = []
        var highest = 0
        for file in storage.list() {
            guard let n = Self.number(of: file) else { continue }
            highest = max(highest, n)
            switch read(file) {
            case .success(let found):
                good.append(PresetLibraryEntry(file: file, name: found.saved.name, order: found.saved.order,
                                               state: .readable))
            case .failure(let failure):
                let code: String
                if case .unreadable(let refusal) = failure { code = refusal } else { code = "damaged" }
                bad.append(PresetLibraryEntry(file: file, name: names[file] ?? file, order: 0,
                                              state: .unreadable(code)))
            }
        }
        good.sort { $0.order != $1.order ? $0.order > $1.order : $0.number > $1.number }
        bad.sort { $0.number < $1.number }
        entries = good + bad
        next = max(index.next, highest + 1, 1)
    }

    /// Writes the index of the current entries; a failure is ignored (the preset files are the truth and the counter
    /// is recovered from them).
    private func writeIndex() {
        let items = entries.map { Index.Item(file: $0.file, name: $0.name, order: $0.order) }
        guard let data = try? Self.encode(Index(entries: items, next: next)) else { return }
        try? storage.write(data, to: Self.indexFile)
    }

    /// Writes the preset file `file`; the failure of an oversized file or the storage, or nil.
    private func write(name: String, order: Int, chain: EffectChain, to file: String) -> PresetLibraryFailure? {
        let data: Data
        do {
            data = try Self.encode(name: name, order: order, chain: chain)
        } catch {
            return .chain(ChainRefusal.damaged.code)
        }
        guard data.count <= Self.maxFileBytes else { return .storage(.tooLarge(data.count)) }
        do {
            try storage.write(data, to: file)
        } catch {
            return Self.failure(of: error)
        }
        return nil
    }

    /// The preset of `file`, or the failure of a missing or unreadable file.
    private func read(_ file: String) -> Result<(saved: SavedPreset, chain: EffectChain), PresetLibraryFailure> {
        let data: Data
        do {
            data = try storage.read(file)
        } catch {
            return .failure(.missing)
        }
        return Self.decode(data).mapError { .unreadable($0.code) }
    }

    // MARK: Operations

    /// Saves `chain` as `name` (trimmed, 1…40 characters) in a new file, when no readable preset has that name
    /// (compared without regard to case), the library holds fewer than 24 files and the chain passes
    /// `EffectChain.validate()`. Returns the saved entry; a refusal changes nothing on disk.
    @discardableResult
    func save(name raw: String, chain: EffectChain) -> Result<PresetLibraryEntry, PresetLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let name = Self.cleanName(raw) else { return .failure(.badName) }
        if let other = entry(named: name) { return .failure(.taken(other.name)) }
        guard entries.count < Self.maxPresets else { return .failure(.full) }
        do throws(ChainRefusal) {
            try chain.validate()
        } catch {
            return .failure(.chain(error.code))
        }
        let order = (entries.map(\.order).max() ?? 0) + 1
        let file = Self.fileName(next)
        if let failure = write(name: name, order: order, chain: chain, to: file) { return .failure(failure) }
        next += 1
        reload()
        writeIndex()
        return entry(file: file).map { .success($0) } ?? .failure(.missing)
    }

    /// The chain of the readable file `file`, read again from it. An unreadable file is refused with its code (and
    /// the list is read again when the file changed since it was listed). Opening writes nothing and works in a
    /// read-only library.
    func open(file: String) -> Result<EffectChain, PresetLibraryFailure> {
        guard let entry = entry(file: file) else { return .failure(.missing) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        switch read(file) {
        case .success(let found):
            return .success(found.chain)
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
    }

    /// Renames the readable preset `file` to `name` (trimmed, 1…40 characters), keeping its order and chain; refused
    /// with "A preset is already called <name>." when another preset has that name, and with the code of an
    /// unreadable file.
    @discardableResult
    func rename(file: String, to raw: String) -> Result<PresetLibraryEntry, PresetLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.missing) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        guard let name = Self.cleanName(raw) else { return .failure(.badName) }
        if let other = self.entry(named: name), other.file != file { return .failure(.taken(other.name)) }
        let found: (saved: SavedPreset, chain: EffectChain)
        switch read(file) {
        case .success(let value):
            found = value
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
        if let failure = write(name: name, order: found.saved.order, chain: found.chain, to: file) {
            return .failure(failure)
        }
        reload()
        writeIndex()
        return self.entry(file: file).map { .success($0) } ?? .failure(.missing)
    }

    /// Removes the preset `file`, readable or not. Only this explicit call removes a file; nothing is deleted
    /// automatically.
    @discardableResult
    func remove(file: String) -> Result<Void, PresetLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard entry(file: file) != nil else { return .failure(.missing) }
        do {
            try storage.remove(file)
        } catch {
            reload()
            return .failure(Self.failure(of: error))
        }
        reload()
        writeIndex()
        return .success(())
    }
}
