// ResultLibrary — feature 176 (A24-P04) T-A24-404 (FR-A24-402, FR-A24-403; clarifications Q2, Q3; data-model.md
// "Saved result", "Index", "ResultLibraryEntry", "Caps"; contracts/results.md; gap G-RESULTS). The saved runs of
// Graphics Benchmark Lab, one file per result in the experience's own storage (`ExperienceStorage`, whose quota is
// 16 MiB and 64 files), after Visual Programming Lab's `GraphLibrary` (A23-P04):
//
//   - `result-<n>.json`: the envelope `{"body", "kind": "a24.saved-result", "version": 1}` whose body is
//     `{order, run}`; at most 2,162,688 bytes (the run file's 2,097,152 plus 64 KiB). n is a counter, never reused
//     while the index or a higher file exists (no UUIDs, no date or clock time).
//   - `run` is the run file itself (`RunDocument.encode`, its own envelope `a24.benchmark-run`, schema 3) embedded as
//     a JSON object, not as an escaped string. On reading, the embedded object is written back to JSON and handed to
//     `RunDocument.decode`, so the run file's migrations and every `RunRefusal` apply to it unchanged.
//   - `results.json`: the envelope `{"body", "kind": "a24.result-library", "version": 1}` whose body is
//     `{next, entries: [{file, order}]}`. The result files are the truth: the list is read from them; the index keeps
//     the counter and the order of a file that became unreadable. A damaged index is rebuilt by the next change, never
//     by reading; an index of a newer version makes the library read only (opening still works), so a newer build's
//     index is never overwritten.
//   - Caps: at most 12 results; unreadable files count, as they hold storage (the person may remove them).
//   - Refusals of a file: `damaged`, `newer-version`, `too-large`, or the `RunRefusal` code of the embedded run
//     (`not-finite`, `out-of-range`, `out-of-order`, `too-many-samples`, …). Such a file is listed as unreadable with
//     its code and is never opened, rewritten or deleted automatically; only an explicit `remove(file:)` removes it.
//     Writes go through `storage.write`, which is atomic: a refused write keeps everything as it was.
//   - Messages: "The library holds 12 results.", "There is not enough space to save this result." (a storage quota
//     of bytes or files) and "This result is already saved." (the presenter's rule: the ended run it saved last,
//     compared by value).
//   - Order: each save takes the next order (the largest + 1). The list shows every file newest first by order (an
//     unreadable file takes the order the index remembers, else 0), then by number.
//
// The library is independent of the presenter: it is made with an `ExperienceStorage` and returns what was saved or
// opened. No network, no clock, no UUID, no graphics.
import Foundation
import GraphicsBenchmarkLabCore
import Observation
import VisualCoreExperience

/// What a readable saved result shows in the list: the case title, how the run ended, the frame interval p50 and p95
/// and whether the summary has a GPU distribution.
struct ResultListInfo: Equatable, Sendable {
    /// The case title ("Textured quads", "Shader ALU", "Particles").
    var caseTitle: String
    /// How the run ended.
    var state: RunState
    /// The frame interval p50 in milliseconds; nil with too few frames.
    var intervalP50: Double?
    /// The frame interval p95 in milliseconds; nil with too few frames.
    var intervalP95: Double?
    /// Whether the summary has a GPU distribution.
    var gpuTimed: Bool

    /// The list information of `run`.
    init(run: BenchmarkRun) {
        caseTitle = BenchPresenter.title(of: run.benchmarkCase.workload)
        state = run.state
        intervalP50 = run.summary.interval.p50
        intervalP95 = run.summary.interval.p95
        gpuTimed = run.summary.gpu != nil
    }
}

/// Whether a saved result can be opened, or the code of its refusal.
enum ResultLibraryState: Equatable, Sendable {
    /// The file reads as a run; what the list shows of it.
    case readable(ResultListInfo)
    /// The file was refused with this code (`damaged`, `newer-version`, `too-large`, or a run file code).
    case unreadable(String)
}

/// One saved result of the library: readable (with its list information) or unreadable (with its refusal code).
struct ResultLibraryEntry: Equatable, Identifiable, Sendable {
    /// The file in the experience's storage: `result-<n>.json`.
    var file: String
    /// The save order (larger is newer); for an unreadable file the order the index remembers, else 0.
    var order: Int
    /// Whether the file can be opened.
    var state: ResultLibraryState

    /// The entry's identity: its file name.
    var id: String { file }
    /// The file's counter n of `result-<n>.json` (0 if the name does not parse).
    var number: Int { ResultLibrary.number(of: file) ?? 0 }
    /// Whether the file can be opened.
    var isReadable: Bool {
        if case .readable = state { return true }
        return false
    }
    /// The list information of a readable file; nil when the file is unreadable.
    var info: ResultListInfo? {
        if case .readable(let info) = state { return info }
        return nil
    }
    /// The refusal code of an unreadable file; nil when the file is readable.
    var refusal: String? {
        if case .unreadable(let code) = state { return code }
        return nil
    }
}

/// A saved result as opened: its entry and the run.
struct OpenedResult: Equatable, Sendable {
    /// The library entry of the file.
    var entry: ResultLibraryEntry
    /// The run as it was saved (migrated when its run file was of an older version).
    var run: BenchmarkRun
}

/// Why a library operation was refused; a refused operation changes nothing on disk.
enum ResultLibraryFailure: Error, Equatable, Sendable {
    /// A 13th result: "The library holds 12 results."
    case full
    /// The storage quota (bytes or files) refused the write: "There is not enough space to save this result."
    case noSpace
    /// The ended run was saved already: "This result is already saved."
    case alreadySaved
    /// There is no ended run to save.
    case noRun
    /// The saved file cannot be opened (its refusal code).
    case unreadable(String)
    /// No saved result has this file.
    case missing
    /// The storage refused the write or the removal for another reason.
    case storage(StorageError)
    /// The library is not available (the experience was made without storage).
    case unavailable
    /// The index was written by a newer version, so the library is read only (opening still works).
    case readOnly
    /// The run itself cannot be written (its `RunRefusal` code).
    case run(String)
    /// The export file could not be written.
    case exportFailed

    /// The stable code of the failure.
    var code: String {
        switch self {
        case .full: return "a24.library-full"
        case .noSpace: return "a24.no-space"
        case .alreadySaved: return "a24.already-saved"
        case .noRun: return "a24.no-run"
        case .unreadable(let code): return "a24." + code
        case .missing: return "a24.not-found"
        case .storage(let error): return error.code
        case .unavailable: return "a24.unavailable"
        case .readOnly: return "a24.read-only"
        case .run(let code): return "a24.run-" + code
        case .exportFailed: return "a24.export-failed"
        }
    }

    /// One sentence for the person.
    var message: String {
        switch self {
        case .full: return ResultLibrary.fullMessage
        case .noSpace: return ResultLibrary.noSpaceMessage
        case .alreadySaved: return ResultLibrary.alreadySavedMessage
        case .noRun: return "There is no ended run to save."
        case .unreadable(let code): return "This saved result cannot be opened (\(code))."
        case .missing: return "This saved result is no longer in the library."
        case .storage(let error): return "The library could not be changed (\(error.code))."
        case .unavailable: return "The library is not available."
        case .readOnly: return "The library was written by a newer version, so it cannot be changed."
        case .run(let code): return "This run cannot be saved (\(code))."
        case .exportFailed: return "The export file could not be written."
        }
    }
}

/// A JSON value of any shape, used to embed the run file as an object in a saved result file.
enum ResultJSONValue: Codable, Equatable, Sendable {
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
    case array([ResultJSONValue])
    /// An object (written with sorted keys by the library's encoder).
    case object([String: ResultJSONValue])

    /// Decodes any JSON value: null, then a whole number, a number, a Boolean, a string, an array, an object (numbers
    /// first, so that a 0 or 1 is never read as a Boolean).
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
        } else if let value = try? container.decode([ResultJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: ResultJSONValue].self))
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

/// The saved results in the experience's storage (see the file header).
@MainActor
@Observable
final class ResultLibrary {
    /// The index file.
    nonisolated static let indexFile = "results.json"
    /// The envelope kind of the index.
    nonisolated static let indexKind = "a24.result-library"
    /// The envelope kind of a saved result.
    nonisolated static let resultKind = "a24.saved-result"
    /// The schema version of both files.
    nonisolated static let schemaVersion = 1
    /// The most results the library holds (unreadable files count).
    nonisolated static let maxResults = 12
    /// The largest saved result file (and index), in bytes: the run file's cap plus 64 KiB.
    nonisolated static let maxFileBytes = 2_162_688
    /// The message of a 13th save.
    nonisolated static let fullMessage = "The library holds \(maxResults) results."
    /// The message of a save the storage quota refused.
    nonisolated static let noSpaceMessage = "There is not enough space to save this result."
    /// The message of a second save of the same ended run.
    nonisolated static let alreadySavedMessage = "This result is already saved."

    /// The body of a saved result file.
    struct SavedResult: Codable, Equatable, Sendable {
        /// The save order.
        var order: Int
        /// The run file (`RunDocument.encode`), as a JSON object.
        var run: ResultJSONValue
    }

    /// The body of the index file.
    struct Index: Codable, Equatable, Sendable {
        /// One indexed file.
        struct Item: Codable, Equatable, Sendable {
            /// The file name.
            var file: String
            /// The save order.
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
    /// The saved results, newest first by order, then by number.
    private(set) var entries: [ResultLibraryEntry] = []
    /// The next file counter.
    private(set) var next = 1
    /// Whether the index was written by a newer version (the library is then read only).
    private(set) var isReadOnly = false
    /// The refusal code of the index when it could not be read; nil when it was read or there is none.
    private(set) var indexProblem: String?

    /// A library over `storage`; reads the index and the result files once.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    // MARK: Names and files

    /// The file of counter `n`: `result-<n>.json`.
    nonisolated static func fileName(_ n: Int) -> String { "result-\(n).json" }

    /// The counter n of a file named `result-<n>.json` (n ≥ 1, decimal digits only); nil otherwise.
    nonisolated static func number(of file: String) -> Int? {
        let head = "result-", tail = ".json"
        guard file.hasPrefix(head), file.hasSuffix(tail), file.count > head.count + tail.count else { return nil }
        let digits = file.dropFirst(head.count).dropLast(tail.count)
        for character in digits where !(character.isASCII && character.isNumber) { return nil }
        guard let n = Int(digits), n >= 1 else { return nil }
        return n
    }

    /// The entry of `file`; nil when there is none.
    func entry(file: String) -> ResultLibraryEntry? {
        for entry in entries where entry.file == file { return entry }
        return nil
    }

    // MARK: Encoding

    /// The encoder of both files: sorted keys, unescaped slashes.
    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The saved result file of `run` with `order`: the envelope with sorted keys and the run file embedded. Throws
    /// the run's `RunRefusal` when `RunDocument.encode` refuses it, or an encoding error.
    nonisolated static func encode(order: Int, run: BenchmarkRun) throws -> Data {
        let embedded = try JSONDecoder().decode(ResultJSONValue.self, from: try RunDocument.encode(run))
        let body = SavedResult(order: order, run: embedded)
        return try encoder().encode(Envelope(body: body, kind: resultKind, version: schemaVersion))
    }

    /// Reads a saved result file. Checks, in order: the size (`too-large`), the envelope and its kind (`damaged`), the
    /// version (`newer-version`), the body and its order (`damaged`), then the embedded run file through
    /// `RunDocument.decode` (any `RunRefusal`).
    nonisolated static func decode(_ data: Data) -> Result<(order: Int, run: BenchmarkRun), RunRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == resultKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion) }
        guard let envelope = try? decoder.decode(Envelope<SavedResult>.self, from: data),
              let saved = envelope.body, saved.order >= 0,
              case .object = saved.run,
              let runData = try? encoder().encode(saved.run) else { return .failure(.damaged) }
        switch RunDocument.decode(runData) {
        case .success(let run): return .success((order: saved.order, run: run))
        case .failure(let refusal): return .failure(refusal)
        }
    }

    /// The index file of `index`.
    nonisolated static func encode(_ index: Index) throws -> Data {
        try encoder().encode(Envelope(body: index, kind: indexKind, version: schemaVersion))
    }

    /// Reads the index file: `damaged` (not the envelope, the wrong kind or body), `newer-version` or `too-large`.
    nonisolated static func decodeIndex(_ data: Data) -> Result<Index, RunRefusal> {
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

    /// Reads the index and every result file again. Nothing is written or removed.
    func reload() {
        var index = Index(entries: [], next: 1)
        isReadOnly = false
        indexProblem = nil
        if storage.exists(Self.indexFile) {
            let indexRead: Result<Index, RunRefusal>
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
        var orders: [String: Int] = [:]
        for item in index.entries where orders[item.file] == nil { orders[item.file] = item.order }
        var found: [ResultLibraryEntry] = []
        var highest = 0
        for file in storage.list() {
            guard let n = Self.number(of: file) else { continue }
            highest = max(highest, n)
            switch read(file) {
            case .success(let value):
                found.append(ResultLibraryEntry(file: file, order: value.order,
                                                state: .readable(ResultListInfo(run: value.run))))
            case .failure(let failure):
                let code: String
                if case .unreadable(let refusal) = failure { code = refusal } else { code = "damaged" }
                found.append(ResultLibraryEntry(file: file, order: max(orders[file] ?? 0, 0),
                                                state: .unreadable(code)))
            }
        }
        found.sort { $0.order != $1.order ? $0.order > $1.order : $0.number > $1.number }
        entries = found
        next = max(index.next, highest + 1, 1)
    }

    /// Writes the index of the current entries; a failure is ignored (the result files are the truth and the counter
    /// is recovered from them).
    private func writeIndex() {
        var items: [Index.Item] = []
        for entry in entries { items.append(Index.Item(file: entry.file, order: entry.order)) }
        guard let data = try? Self.encode(Index(entries: items, next: next)) else { return }
        try? storage.write(data, to: Self.indexFile)
    }

    /// The saved result of `file`, or the failure of a missing or unreadable file.
    private func read(_ file: String) -> Result<(order: Int, run: BenchmarkRun), ResultLibraryFailure> {
        let data: Data
        do {
            data = try storage.read(file)
        } catch {
            return .failure(.missing)
        }
        return Self.decode(data).mapError { .unreadable($0.code) }
    }

    /// The failure of a refused storage write: a quota of bytes or files is ``ResultLibraryFailure/noSpace``.
    nonisolated static func failure(of error: StorageError) -> ResultLibraryFailure {
        if case .quotaExceeded = error { return .noSpace }
        return .storage(error)
    }

    // MARK: Operations

    /// Saves `run` in a new file `result-<n>.json` with the next order, when the library holds fewer than 12 files.
    /// Returns n; a refusal changes nothing on disk.
    @discardableResult
    func save(_ run: BenchmarkRun) -> Result<Int, ResultLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard entries.count < Self.maxResults else { return .failure(.full) }
        var order = 0
        for entry in entries { order = max(order, entry.order) }
        order += 1
        let n = next
        let file = Self.fileName(n)
        let data: Data
        do {
            data = try Self.encode(order: order, run: run)
        } catch let refusal as RunRefusal {
            return .failure(.run(refusal.code))
        } catch {
            return .failure(.run(RunRefusal.damaged.code))
        }
        guard data.count <= Self.maxFileBytes else { return .failure(.run(RunRefusal.tooLarge.code)) }
        do {
            try storage.write(data, to: file)
        } catch {
            return .failure(Self.failure(of: error))
        }
        next = n + 1
        reload()
        writeIndex()
        return .success(n)
    }

    /// The run of the readable file `file`, read again from it. An unreadable file is refused with its code (and the
    /// list is read again when the file changed since it was listed). Opening works in a read-only library.
    func open(file: String) -> Result<OpenedResult, ResultLibraryFailure> {
        guard let entry = entry(file: file) else { return .failure(.missing) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        switch read(file) {
        case .success(let found):
            return .success(OpenedResult(entry: entry, run: found.run))
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
    }

    /// Removes the result `file`, readable or not. Only this explicit call removes a file.
    @discardableResult
    func remove(file: String) -> Result<ResultLibraryEntry, ResultLibraryFailure> {
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

    /// The saved results, readable and unreadable, newest first, read again from the storage.
    func list() -> [ResultLibraryEntry] {
        reload()
        return entries
    }
}
