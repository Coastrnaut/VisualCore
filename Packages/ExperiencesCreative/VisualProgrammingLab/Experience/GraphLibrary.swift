// GraphLibrary — feature 169 (A23-P04) T-A23-403 (FR-A23-401, FR-A23-402, FR-A23-403, FR-A23-406; SC-A23-401–403;
// clarifications Q1, Q3; data-model.md "Saved graph file", "Library index", "Limits and messages",
// "GraphLibraryEntry", "GraphLibraryFailure"; contracts/library.md "Presenter"; gap G-LIBRARY). The named graphs of
// Visual Programming Lab, one file per graph in the experience's own storage (`ExperienceStorage`, whose quota is
// 16 MiB and 64 files), after Shader Studio's `ProjectLibrary` and Digital Zen Garden's `GardenLibrary`:
//
//   - `graph-<n>.json`: the envelope `{"body", "kind": "a23.saved-graph", "version": 1}` whose body is
//     `{name, order, graph}`; at most 81,920 bytes. n is a counter, never reused while the index or a higher file
//     exists (no UUIDs).
//   - `graph` is the `GraphDocument` encoding (its own envelope `a23.visual-graph`, schema 1, at most 65,536 bytes)
//     embedded as a JSON object, not as an escaped string, so the file stays readable and every graph file fits the
//     file limit. On reading, the embedded graph goes through the library's `MigrationChain` (by default
//     `GraphDocument.migrations`; a test seam takes another chain) when its version is older than
//     `GraphDocument.schemaVersion`, then through `GraphDocument.decode`, so every `GraphDocumentRefusal` applies to it
//     unchanged. A graph of the current version is handed to `GraphDocument.decode` as written.
//   - `library.json`: the envelope `{"body", "kind": "a23.graph-library", "version": 1}` whose body is
//     `{next, entries: [{file, name, order}]}`: the counter and the names. The graph files are the truth: the list is
//     read from them, and the index keeps the counter and the name of a graph whose file became unreadable. A damaged
//     index is rebuilt by the next change; an index of a newer version makes the library read only (opening still
//     works) so that a newer build's index is never overwritten (as Shader Studio's library).
//   - Caps: at most 24 graphs (unreadable files count, as they hold storage; the person may remove them); a name is
//     trimmed and 1…40 characters; names that differ only in case are the same. Saving or renaming to a name another
//     graph has is refused.
//   - Refusals of a file: `damaged`, `newer-version`, `too-large` (above 81,920 bytes), or the `GraphDocumentRefusal`
//     code of the embedded graph. Such a file is listed as unreadable with its code and is never opened, renamed or
//     deleted automatically; the person may remove it. Writes go through `storage.write`, which is atomic: a failed
//     write (a quota or a file system error) keeps the previous file of that name, so a refusal changes nothing.
//   - Messages: "The library holds 24 graphs.", "A name has 1 to 40 characters." and "A graph is already called
//     <name>." (data-model.md), plus the sentences of `GraphLibraryFailure.message`.
//   - Order: each save takes the next modification order (the largest + 1); a rename keeps it. The list shows the
//     readable graphs newest first, then the unreadable files by number.
//
// T-A23-404 (FR-A23-401, FR-A23-402; clarification Q2; Edge Case "Opening over unsaved work"): the presenter's library
// actions (`save(name:)`, `open(file:)`, `rename(file:to:)`, `remove(file:)`, `openExample(id:)`, and the replace
// confirmation `request(_:)`, `confirmReplace()`, `declineReplace()`) are the extension at the end of this file.
// Opening restores the core through the factory's `restoreGraph` (a `LabCore` snapshot with the graph and no
// selection, `shell.restore(_:)`), so the preview compiles the opened graph at the next frame.
//
// The library is independent of the presenter: it is made with an `ExperienceStorage` and returns what was saved or
// opened. No network, no clock, no UUID.
import Foundation
import Observation
import VisualCoreExperience
import VisualCorePersistence
import VisualProgrammingLabCore

/// Whether a saved graph can be opened, or the code of its refusal.
enum GraphLibraryState: Equatable, Sendable {
    /// The file reads as a graph.
    case readable
    /// The file was refused with this code (`damaged`, `newer-version`, `too-large`, `not-finite` or
    /// `out-of-range`).
    case unreadable(String)
}

/// One saved graph of the library: readable (with its name and order) or unreadable (with its refusal code).
struct GraphLibraryEntry: Equatable, Identifiable, Sendable {
    /// The file in the experience's storage: `graph-<n>.json`.
    var file: String
    /// The graph's name; for an unreadable file the name the index remembers, else the file name.
    var name: String
    /// The modification order (larger is newer); 0 for an unreadable file.
    var order: Int
    /// Whether the file can be opened.
    var state: GraphLibraryState

    /// The entry's identity: its file name.
    var id: String { file }
    /// Whether the file can be opened and renamed.
    var isReadable: Bool { state == .readable }
    /// The refusal code of an unreadable file; nil when the file is readable.
    var refusal: String? {
        if case .unreadable(let code) = state { return code }
        return nil
    }
    /// The file's counter n of `graph-<n>.json` (0 if the name does not parse).
    var number: Int { GraphLibrary.number(of: file) ?? 0 }
    /// The file's name without `.json` (`graph-<n>`), used in the accessibility identifiers.
    var stem: String { file.hasSuffix(".json") ? String(file.dropLast(5)) : file }
}

/// A saved graph as opened: its entry and the graph.
struct OpenedGraph: Equatable, Sendable {
    /// The library entry of the file.
    var entry: GraphLibraryEntry
    /// The graph as it was saved (migrated when it was of an older version).
    var graph: VisualGraph
}

/// Why a library operation was refused; a refused operation changes nothing on disk.
enum GraphLibraryFailure: Error, Equatable, Sendable {
    /// A 25th graph: "The library holds 24 graphs."
    case full
    /// A name that is empty or longer than 40 characters after trimming: "A name has 1 to 40 characters."
    case badName
    /// Saving or renaming to the name of another graph (the name as stored).
    case taken(String)
    /// The saved file cannot be opened or renamed (its refusal code).
    case unreadable(String)
    /// No saved graph has this file (or no example has this identifier).
    case missing
    /// The storage refused the write or the removal.
    case storage(StorageError)
    /// The library is not available (the experience was made without storage).
    case unavailable
    /// The index was written by a newer version, so the library is read only (opening still works).
    case readOnly
    /// The graph itself cannot be written (its `GraphDocumentRefusal` code); no edit of the core makes such a graph.
    case graph(String)

    /// The stable code of the failure.
    var code: String {
        switch self {
        case .full: return "a23.library-full"
        case .badName: return "a23.invalid-name"
        case .taken: return "a23.name-taken"
        case .unreadable(let code): return "a23." + code
        case .missing: return "a23.not-found"
        case .storage(let error): return error.code
        case .unavailable: return "a23.unavailable"
        case .readOnly: return "a23.read-only"
        case .graph(let code): return "a23.graph-" + code
        }
    }

    /// One sentence for the person.
    var message: String {
        switch self {
        case .full: return GraphLibrary.fullMessage
        case .badName: return GraphLibrary.nameMessage
        case .taken(let name): return GraphLibrary.takenMessage(name)
        case .unreadable(let code): return "This saved graph cannot be opened (\(code))."
        case .missing: return "This saved graph is no longer in the library."
        case .storage(let error): return "The library could not be changed (\(error.code))."
        case .unavailable: return "The library is not available."
        case .readOnly: return "The library was written by a newer version, so it cannot be changed."
        case .graph(let code): return "This graph cannot be saved (\(code))."
        }
    }
}

/// A JSON value of any shape, used to embed the `GraphDocument` encoding as an object in a saved graph file.
enum GraphJSONValue: Codable, Equatable, Sendable {
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
    case array([GraphJSONValue])
    /// An object (written with sorted keys by the library's encoder).
    case object([String: GraphJSONValue])

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
        } else if let value = try? container.decode([GraphJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: GraphJSONValue].self))
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

    /// The field `key` of an object; nil for another value or a missing field.
    subscript(key: String) -> GraphJSONValue? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }
}

/// The named graphs in the experience's storage (see the file header).
@MainActor
@Observable
final class GraphLibrary {
    /// The index file.
    nonisolated static let indexFile = "library.json"
    /// The envelope kind of the index.
    nonisolated static let indexKind = "a23.graph-library"
    /// The envelope kind of a saved graph.
    nonisolated static let graphKind = "a23.saved-graph"
    /// The schema version of both files.
    nonisolated static let schemaVersion = 1
    /// The most graphs the library holds (unreadable files count).
    nonisolated static let maxGraphs = 24
    /// The longest name, in characters, after trimming.
    nonisolated static let maxNameLength = 40
    /// The largest saved graph file (and index), in bytes.
    nonisolated static let maxFileBytes = 81_920
    /// The message of a 25th save.
    nonisolated static let fullMessage = "The library holds \(maxGraphs) graphs."
    /// The message of an empty or too long name.
    nonisolated static let nameMessage = "A name has 1 to \(maxNameLength) characters."

    /// The message of a save or rename to a used name: "A graph is already called <name>.".
    nonisolated static func takenMessage(_ name: String) -> String { "A graph is already called \(name)." }

    /// The body of a saved graph file.
    struct SavedGraph: Codable, Equatable, Sendable {
        /// The `GraphDocument` encoding, as a JSON object.
        var graph: GraphJSONValue
        /// The graph's name in the library.
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
            /// The graph's name.
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
    /// The migrations of an embedded graph to `GraphDocument.schemaVersion` (`GraphDocument.migrations` unless a test
    /// gives another chain).
    let migrations: MigrationChain
    /// The saved graphs: the readable ones newest first, then the unreadable ones by number.
    private(set) var entries: [GraphLibraryEntry] = []
    /// The next file counter.
    private(set) var next = 1
    /// Whether the index was written by a newer version (the library is then read only).
    private(set) var isReadOnly = false
    /// The refusal code of the index when it could not be read; nil when it was read or there is none.
    private(set) var indexProblem: String?

    /// A library over `storage` reading graphs through `migrations`; reads the index and the graph files once.
    init(storage: ExperienceStorage, migrations: MigrationChain = GraphDocument.migrations) {
        self.storage = storage
        self.migrations = migrations
        reload()
    }

    // MARK: Names and files

    /// The file of counter `n`: `graph-<n>.json`.
    nonisolated static func fileName(_ n: Int) -> String { "graph-\(n).json" }

    /// The counter n of a file named `graph-<n>.json` (n ≥ 1, decimal digits only); nil otherwise.
    nonisolated static func number(of file: String) -> Int? {
        let head = "graph-", tail = ".json"
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

    /// The readable graph called `name` (trimmed; compared without regard to case); nil when there is none.
    func entry(named name: String) -> GraphLibraryEntry? {
        guard let clean = Self.cleanName(name) else { return nil }
        return entries.first { $0.isReadable && $0.name.caseInsensitiveCompare(clean) == .orderedSame }
    }

    /// The entry of `file`; nil when there is none.
    func entry(file: String) -> GraphLibraryEntry? { entries.first { $0.file == file } }

    /// The readable graphs.
    var readable: [GraphLibraryEntry] { entries.filter(\.isReadable) }

    // MARK: Encoding

    /// The encoder of both files: sorted keys, unescaped slashes.
    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The saved graph file of `graph` named `name` with `order`: the envelope with sorted keys. Throws the graph's
    /// `GraphDocumentRefusal` when `GraphDocument.encode` refuses it, or an encoding error.
    nonisolated static func encode(name: String, order: Int, graph: VisualGraph) throws -> Data {
        let embedded = try JSONDecoder().decode(GraphJSONValue.self, from: try GraphDocument.encode(graph))
        let body = SavedGraph(graph: embedded, name: name, order: order)
        return try encoder().encode(Envelope(body: body, kind: graphKind, version: schemaVersion))
    }

    /// Reads a saved graph file. Checks, in order: the size (`too-large`), the envelope and its kind (`damaged`), the
    /// version (`newer-version`), the body and its name (`damaged`), then the embedded graph (``readGraph(_:migrations:)``:
    /// any `GraphDocumentRefusal`).
    nonisolated static func decode(_ data: Data, migrations: MigrationChain = GraphDocument.migrations)
        -> Result<(saved: SavedGraph, graph: VisualGraph), GraphDocumentRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == graphKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion) }
        guard let envelope = try? decoder.decode(Envelope<SavedGraph>.self, from: data),
              let saved = envelope.body, let name = cleanName(saved.name), name == saved.name,
              saved.order >= 0 else { return .failure(.damaged) }
        switch readGraph(saved.graph, migrations: migrations) {
        case .success(let graph): return .success((saved: saved, graph: graph))
        case .failure(let refusal): return .failure(refusal)
        }
    }

    /// The graph of the embedded `GraphDocument` encoding `value`: of the current version, `GraphDocument.decode` as
    /// written; of an older version, its body migrated through `migrations` (a chain that ends at
    /// `GraphDocument.schemaVersion`), then `GraphDocument.decode` of the migrated envelope. Refused as `damaged` (not
    /// a graph envelope, a missing step, a step that throws or gives no JSON object, a chain ending elsewhere),
    /// `newer-version`, or any other `GraphDocumentRefusal` of the graph.
    nonisolated static func readGraph(_ value: GraphJSONValue,
                                      migrations: MigrationChain) -> Result<VisualGraph, GraphDocumentRefusal> {
        guard case .string(let kind)? = value["kind"], kind == GraphDocument.kind,
              case .int(let version)? = value["version"], let body = value["body"] else { return .failure(.damaged) }
        guard version <= GraphDocument.schemaVersion else { return .failure(.newerVersion) }
        let data: Data
        if version == GraphDocument.schemaVersion {
            guard let written = try? encoder().encode(value) else { return .failure(.damaged) }
            data = written
        } else {
            guard migrations.currentVersion == GraphDocument.schemaVersion,
                  let bodyData = try? encoder().encode(body),
                  let fields = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                return .failure(.damaged)
            }
            let migrated: [String: Any]
            do {
                migrated = try migrations.migrate(fields, from: version)
            } catch MigrationError.newerVersion(_) {
                return .failure(.newerVersion)
            } catch {
                return .failure(.damaged)
            }
            let envelope: [String: Any] = ["body": migrated, "kind": GraphDocument.kind,
                                           "version": GraphDocument.schemaVersion]
            guard JSONSerialization.isValidJSONObject(envelope),
                  let written = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]) else {
                return .failure(.damaged)
            }
            data = written
        }
        do throws(GraphDocumentRefusal) {
            return .success(try GraphDocument.decode(data))
        } catch {
            return .failure(error)
        }
    }

    /// The index file of `index`.
    nonisolated static func encode(_ index: Index) throws -> Data {
        try encoder().encode(Envelope(body: index, kind: indexKind, version: schemaVersion))
    }

    /// Reads the index file: `damaged` (not the envelope, the wrong kind or body), `newer-version` or `too-large`
    /// (above 81,920 bytes).
    nonisolated static func decodeIndex(_ data: Data) -> Result<Index, GraphDocumentRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == indexKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion) }
        guard let envelope = try? decoder.decode(Envelope<Index>.self, from: data), let index = envelope.body,
              index.next >= 1 else { return .failure(.damaged) }
        return .success(index)
    }

    // MARK: Reading and writing

    /// Reads the index and every graph file again. Nothing is written or removed.
    func reload() {
        var index = Index(entries: [], next: 1)
        isReadOnly = false
        indexProblem = nil
        if storage.exists(Self.indexFile) {
            let indexRead: Result<Index, GraphDocumentRefusal>
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
        var good: [GraphLibraryEntry] = []
        var bad: [GraphLibraryEntry] = []
        var highest = 0
        for file in storage.list() {
            guard let n = Self.number(of: file) else { continue }
            highest = max(highest, n)
            switch read(file) {
            case .success(let found):
                good.append(GraphLibraryEntry(file: file, name: found.saved.name, order: found.saved.order,
                                              state: .readable))
            case .failure(let failure):
                let code: String
                if case .unreadable(let refusal) = failure { code = refusal } else { code = "damaged" }
                bad.append(GraphLibraryEntry(file: file, name: names[file] ?? file, order: 0,
                                             state: .unreadable(code)))
            }
        }
        good.sort { $0.order != $1.order ? $0.order > $1.order : $0.number > $1.number }
        bad.sort { $0.number < $1.number }
        entries = good + bad
        next = max(index.next, highest + 1, 1)
    }

    /// Writes the index of the current entries; a failure is ignored (the graph files are the truth and the counter
    /// is recovered from them).
    private func writeIndex() {
        let items = entries.map { Index.Item(file: $0.file, name: $0.name, order: $0.order) }
        guard let data = try? Self.encode(Index(entries: items, next: next)) else { return }
        try? storage.write(data, to: Self.indexFile)
    }

    /// Writes the graph file `file`; the failure of a graph the file format refuses, an oversized file or the
    /// storage, or nil.
    private func write(name: String, order: Int, graph: VisualGraph, to file: String) -> GraphLibraryFailure? {
        let data: Data
        do {
            data = try Self.encode(name: name, order: order, graph: graph)
        } catch let refusal as GraphDocumentRefusal {
            return .graph(refusal.code)
        } catch {
            return .graph(GraphDocumentRefusal.damaged.code)
        }
        guard data.count <= Self.maxFileBytes else { return .storage(.tooLarge(data.count)) }
        do {
            try storage.write(data, to: file)
        } catch {
            return .storage(error)
        }
        return nil
    }

    /// The saved graph of `file`, or the failure of a missing or unreadable file.
    private func read(_ file: String) -> Result<(saved: SavedGraph, graph: VisualGraph), GraphLibraryFailure> {
        let data: Data
        do {
            data = try storage.read(file)
        } catch {
            return .failure(.missing)
        }
        return Self.decode(data, migrations: migrations).mapError { .unreadable($0.code) }
    }

    // MARK: Operations

    /// Saves `graph` as `name` (trimmed, 1…40 characters) in a new file, when no readable graph has that name
    /// (compared without regard to case) and the library holds fewer than 24 files. Returns the saved entry; a
    /// refusal changes nothing on disk.
    @discardableResult
    func save(name raw: String, graph: VisualGraph) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let name = Self.cleanName(raw) else { return .failure(.badName) }
        if let other = entry(named: name) { return .failure(.taken(other.name)) }
        guard entries.count < Self.maxGraphs else { return .failure(.full) }
        let order = (entries.map(\.order).max() ?? 0) + 1
        let file = Self.fileName(next)
        if let failure = write(name: name, order: order, graph: graph, to: file) { return .failure(failure) }
        next += 1
        reload()
        writeIndex()
        return entry(file: file).map { .success($0) } ?? .failure(.missing)
    }

    /// The graph of the readable file `file`, read again from it (migrated when older). An unreadable file is refused
    /// with its code (and the list is read again when the file changed since it was listed). Opening works in a
    /// read-only library.
    func open(_ file: String) -> Result<OpenedGraph, GraphLibraryFailure> {
        guard let entry = entry(file: file) else { return .failure(.missing) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        switch read(file) {
        case .success(let found):
            return .success(OpenedGraph(entry: entry, graph: found.graph))
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
    }

    /// Renames the readable graph `file` to `name` (trimmed, 1…40 characters), keeping its order and graph; refused
    /// with "A graph is already called <name>." when another graph has that name, and with the code of an
    /// unreadable file.
    @discardableResult
    func rename(_ file: String, to raw: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.missing) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        guard let name = Self.cleanName(raw) else { return .failure(.badName) }
        if let other = self.entry(named: name), other.file != file { return .failure(.taken(other.name)) }
        let found: (saved: SavedGraph, graph: VisualGraph)
        switch read(file) {
        case .success(let value):
            found = value
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
        if let failure = write(name: name, order: found.saved.order, graph: found.graph, to: file) {
            return .failure(failure)
        }
        reload()
        writeIndex()
        return self.entry(file: file).map { .success($0) } ?? .failure(.missing)
    }

    /// Removes the graph `file`, readable or not. Only this explicit call removes a file; nothing is deleted
    /// automatically.
    @discardableResult
    func remove(_ file: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.missing) }
        do {
            try storage.remove(file)
        } catch {
            reload()
            return .failure(.storage(error))
        }
        reload()
        writeIndex()
        return .success(entry)
    }
}

/// What opening replaces the open graph with: a saved file or an example.
enum LabOpenTarget: Equatable, Sendable {
    /// The saved graph of this file.
    case file(String)
    /// The example with this identifier (``LabExample/id``).
    case example(String)
}

/// The presenter's library actions (T-A23-404; contracts/library.md "Presenter").
extension LabPresenter {
    /// The fingerprint text of `graph`; nil when it cannot be computed (no edit makes such a graph).
    nonisolated static func fingerprintText(_ graph: VisualGraph) -> String? {
        try? GraphDocument.fingerprint(of: graph).hex
    }

    /// Whether opening another graph must ask first: the open graph differs, by its fingerprint, from the graph last
    /// saved, opened or started from (at first the starter graph).
    var needsReplaceConfirmation: Bool {
        Self.fingerprintText(state.graph) != baseline
    }

    /// Saves the open graph as `name` and shows "Saved <name>." or the refusal; the saved graph becomes the one
    /// opening compares with.
    @discardableResult
    func save(name: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let graph = state.graph
        let result = library.save(name: name, graph: graph)
        switch result {
        case .success(let entry):
            baseline = Self.fingerprintText(graph)
            report("Saved \(entry.name).")
        case .failure(let failure):
            report(failure.message)
        }
        return result
    }

    /// Opens the saved graph `file` without asking: its graph replaces the open one through the shell's restore path
    /// (no selection) and "Opened <name>." is shown, or the refusal; a refused restore changes nothing.
    @discardableResult
    func open(file: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        switch library.open(file) {
        case .success(let opened):
            guard replace(with: opened.graph) else { return refuse(.unreadable("restore-refused")) }
            report("Opened \(opened.entry.name).")
            return .success(opened.entry)
        case .failure(let failure):
            return refuse(failure)
        }
    }

    /// Renames the saved graph `file` to `name` and shows "Renamed <old> to <new>." or the refusal.
    @discardableResult
    func rename(file: String, to name: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let old = library.entry(file: file)?.name ?? file
        let result = library.rename(file, to: name)
        switch result {
        case .success(let entry): report("Renamed \(old) to \(entry.name).")
        case .failure(let failure): report(failure.message)
        }
        return result
    }

    /// Removes the saved graph `file` (the open graph stays as it is) and shows "Removed <name>." or the refusal.
    @discardableResult
    func remove(file: String) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let result = library.remove(file)
        switch result {
        case .success(let entry): report("Removed \(entry.name).")
        case .failure(let failure): report(failure.message)
        }
        return result
    }

    /// Opens the example `id` without asking, through the same restore path, and shows "Opened the example
    /// <title>."; an unknown identifier is refused as missing. Needs no storage.
    @discardableResult
    func openExample(id: String) -> Result<LabExample, GraphLibraryFailure> {
        guard let example = LabExamples.example(id) else {
            report(GraphLibraryFailure.missing.message)
            return .failure(.missing)
        }
        guard replace(with: example.graph) else {
            report(GraphLibraryFailure.unreadable("restore-refused").message)
            return .failure(.unreadable("restore-refused"))
        }
        report("Opened the example \(example.title).")
        return .success(example)
    }

    /// Opens `target` now when nothing would be lost (returns true), else keeps it as the pending replacement the
    /// controls ask about (`library-replace-confirm`) and changes nothing (returns false).
    @discardableResult
    func request(_ target: LabOpenTarget) -> Bool {
        guard needsReplaceConfirmation else {
            perform(target)
            return true
        }
        if mirror.pendingReplace != target { mirror.pendingReplace = target }
        return false
    }

    /// Opens the pending replacement (the person confirmed); nothing when there is none.
    func confirmReplace() {
        guard let target = mirror.pendingReplace else { return }
        mirror.pendingReplace = nil
        perform(target)
    }

    /// Forgets the pending replacement (the person declined): the open graph and the library are unchanged.
    func declineReplace() {
        if mirror.pendingReplace != nil { mirror.pendingReplace = nil }
    }

    /// Opens `target` without asking.
    private func perform(_ target: LabOpenTarget) {
        switch target {
        case .file(let file): _ = open(file: file)
        case .example(let id): _ = openExample(id: id)
        }
    }

    /// Replaces the open graph by `graph` through the factory's restore (no selection); on success the touches in
    /// progress are dropped, `graph` becomes the graph opening compares with and the mirror follows. The preview
    /// compiles it at the next frame (its fingerprint changed).
    private func replace(with graph: VisualGraph) -> Bool {
        cancelPointers()
        guard restoreGraph?(graph) == true else { return false }
        baseline = Self.fingerprintText(graph)
        follow(state)
        return true
    }

    /// Shows `failure`'s sentence and returns it.
    private func refuse(_ failure: GraphLibraryFailure) -> Result<GraphLibraryEntry, GraphLibraryFailure> {
        report(failure.message)
        return .failure(failure)
    }

    /// Shows `text` as the library's message (spoken by its label in the controls).
    private func report(_ text: String) {
        if mirror.libraryMessage != text { mirror.libraryMessage = text }
    }
}
