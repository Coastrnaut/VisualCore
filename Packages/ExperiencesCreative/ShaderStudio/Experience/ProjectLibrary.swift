// ProjectLibrary — feature 162 (A22-P04) T-A22-408 (FR-A22-405, FR-A22-406; SC-A22-403; clarification "What is the
// project library?"; data-model.md "Saved project", "Library index", "Caps and messages", "Order"; contracts/limits.md
// "Library"). The named projects of Shader Studio, one file per project in the experience's own storage
// (`ExperienceStorage`, whose quota is 16 MiB and 64 files), after Digital Zen Garden's `GardenLibrary`:
//
//   - `project-<n>.json`: the envelope `{"body", "kind": "a22.saved-project", "version": 1}` whose body is
//     `{name, order, project, values, textures}`; at most 131,072 bytes. n is a counter, never reused while the index
//     or a higher file exists (no UUIDs).
//   - `project` is the `ShaderProject` encoding (its own envelope `a22.shader-project`) embedded as a JSON object,
//     not as an escaped string: the file stays readable and a project of up to 65,536 bytes always fits the file
//     limit. On reading, the object is written out again with sorted keys and given to `ShaderProject.decode`, so
//     every `ShaderProjectRefusal` applies to it unchanged.
//   - `values` are the 16 normalized uniform values (0…1, `StudioCore.valueCount`) and `textures` the 2 texture
//     choices (`TextureRecipe` raw values, `StudioCore.textureCount`).
//   - `library.json`: the envelope `{"body", "kind": "a22.project-library", "version": 1}` whose body is
//     `{next, entries: [{file, name, order}]}`: the counter and the names. The project files are the truth: the list
//     is read from them, and the index keeps the counter and the name of a project whose file became unreadable. A
//     damaged index is rebuilt by the next change; an index of a newer version makes the library read only (opening
//     still works) so a newer build's index is never overwritten.
//   - Caps: at most 24 projects (unreadable files count, as they hold storage; the person can remove them); a name is
//     trimmed and 1…40 characters; names that differ only in case are the same. Saving or renaming to a name another
//     project has is refused.
//   - Refusals of a file: `damaged`, `newer-version`, `too-large` (above 131,072 bytes), `out-of-range` (values or
//     textures of the wrong count or range), or the `ShaderProjectRefusal` code of the embedded project. Such a file
//     is listed as unreadable with its code and is never opened, renamed or deleted automatically; the person may
//     remove it. Writes go through `storage.write`, which is atomic: a failed write (a quota or a file system error)
//     keeps the previous file of that name unchanged.
//   - The validator is not consulted: a project whose source `ShaderValidator` refuses is saved as text, so the
//     person's work is kept; opening it gives the same source, and the run shows its refusal again.
//   - Messages: "The library holds 24 projects.", "A name has 1 to 40 characters." and "A project is already called
//     <name>." (data-model.md), plus the sentences of `ProjectLibraryFailure.message`.
//   - Order: each save takes the next modification order (the largest + 1); a rename keeps it. The list shows the
//     readable projects newest first, then the unreadable files by number.
//
// The library is independent of the presenter: it is made with an `ExperienceStorage` and returns what was saved; the
// presenter sets the document, the values and the textures and queues a Run. No network, no clock, no UUID.
import Foundation
import Observation
import ShaderStudioCore
import VisualCoreExperience

/// One saved project of the library: readable (with its name and order) or unreadable (with its refusal code).
struct ProjectLibraryEntry: Equatable, Identifiable, Sendable {
    /// The file in the experience's storage: `project-<n>.json`.
    var file: String
    /// The project's name; for an unreadable file the name the index remembers, else the file name.
    var name: String
    /// The modification order (larger is newer); 0 for an unreadable file.
    var order: Int
    /// The refusal code of an unreadable file (`damaged`, `newer-version`, `too-large`, `not-finite` or
    /// `out-of-range`); nil when the file is readable.
    var refusal: String?

    /// The entry's identity: its file name.
    var id: String { file }
    /// Whether the file can be opened and renamed.
    var isReadable: Bool { refusal == nil }
    /// The file's counter n of `project-<n>.json` (0 if the name does not parse).
    var number: Int { ProjectLibrary.number(of: file) ?? 0 }
}

/// A saved project as opened: its entry, the project, the 16 normalized values and the 2 texture choices.
struct OpenedProject: Equatable, Sendable {
    /// The library entry of the file.
    var entry: ProjectLibraryEntry
    /// The project as it was saved (its source unchanged, even one the validator refuses).
    var project: ShaderProject
    /// The normalized uniform values (0…1), `StudioCore.valueCount` entries.
    var values: [Double]
    /// The texture choices (`TextureRecipe` raw values), `StudioCore.textureCount` entries.
    var textures: [Int]
}

/// Why a library operation was refused; a refused operation changes nothing on disk.
enum ProjectLibraryFailure: Error, Equatable, Sendable {
    /// A 25th project: "The library holds 24 projects."
    case full
    /// A name that is empty or longer than 40 characters after trimming: "A name has 1 to 40 characters."
    case invalidName
    /// Saving or renaming to the name of another project (the name as stored).
    case nameTaken(String)
    /// The project's file would be larger than 131,072 bytes, or its project encoding larger than 65,536 (the size).
    case tooLarge(Int)
    /// The values or the texture choices are of the wrong count or outside their range (the field: `values` or
    /// `textures`).
    case invalidState(String)
    /// The saved file cannot be opened or renamed (its refusal code).
    case unreadable(String)
    /// No saved project has this file.
    case notFound
    /// The index was written by a newer version, so the library is read only.
    case readOnly
    /// The library is not available (the experience was made without storage).
    case unavailable
    /// The storage refused the write or the removal (its `StorageError` code, or `a22.encoding`).
    case storage(String)

    /// The stable code of the failure.
    var code: String {
        switch self {
        case .full: return "a22.library-full"
        case .invalidName: return "a22.invalid-name"
        case .nameTaken: return "a22.name-taken"
        case .tooLarge: return "a22.too-large"
        case .invalidState(let field): return "a22.invalid-" + field
        case .unreadable(let code): return "a22." + code
        case .notFound: return "a22.not-found"
        case .readOnly: return "a22.read-only"
        case .unavailable: return "a22.unavailable"
        case .storage(let code): return code
        }
    }

    /// One sentence for the person.
    var message: String {
        switch self {
        case .full:
            return ProjectLibrary.fullMessage
        case .invalidName:
            return ProjectLibrary.nameMessage
        case .nameTaken(let name):
            return ProjectLibrary.takenMessage(name)
        case .tooLarge(let bytes):
            return "The project is too large to save: \(bytes) bytes, above the limit of "
                + "\(ProjectLibrary.maxFileBytes) bytes."
        case .invalidState(let field):
            return "The project cannot be saved: its \(field) are out of range."
        case .unreadable(let code):
            return "This saved project cannot be opened (\(code))."
        case .notFound:
            return "This saved project is no longer in the library."
        case .readOnly:
            return "The library was written by a newer version, so it cannot be changed."
        case .unavailable:
            return "The library is not available."
        case .storage(let code):
            return "The library could not be changed (\(code))."
        }
    }
}

/// A JSON value of any shape, used to embed the `ShaderProject` encoding as an object in a saved project file.
enum ProjectJSONValue: Codable, Equatable, Sendable {
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
    case array([ProjectJSONValue])
    /// An object (written with sorted keys by the library's encoder).
    case object([String: ProjectJSONValue])

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
        } else if let value = try? container.decode([ProjectJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: ProjectJSONValue].self))
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

/// The named projects in the experience's storage (see the file header).
@MainActor
@Observable
final class ProjectLibrary {
    /// The index file.
    nonisolated static let indexFile = "library.json"
    /// The envelope kind of the index.
    nonisolated static let indexKind = "a22.project-library"
    /// The envelope kind of a saved project.
    nonisolated static let projectKind = "a22.saved-project"
    /// The schema version of both files.
    nonisolated static let schemaVersion = 1
    /// The most projects the library holds (unreadable files count).
    nonisolated static let maxProjects = 24
    /// The longest name, in characters, after trimming.
    nonisolated static let maxNameLength = 40
    /// The largest saved project file (and index), in bytes.
    nonisolated static let maxFileBytes = 131_072
    /// The message of a 25th save.
    nonisolated static let fullMessage = "The library holds \(maxProjects) projects."
    /// The message of an empty or too long name.
    nonisolated static let nameMessage = "A name has 1 to \(maxNameLength) characters."

    /// The message of a save or rename to a used name: "A project is already called <name>.".
    nonisolated static func takenMessage(_ name: String) -> String { "A project is already called \(name)." }

    /// The body of a saved project file.
    struct SavedProject: Codable, Equatable, Sendable {
        /// The project's name in the library.
        var name: String
        /// The modification order.
        var order: Int
        /// The `ShaderProject` encoding, as a JSON object.
        var project: ProjectJSONValue
        /// The texture choices.
        var textures: [Int]
        /// The normalized uniform values.
        var values: [Double]
    }

    /// The body of the index file.
    struct Index: Codable, Equatable, Sendable {
        /// One indexed file.
        struct Item: Codable, Equatable, Sendable {
            /// The file name.
            var file: String
            /// The project's name.
            var name: String
            /// The modification order.
            var order: Int
        }

        /// The next file counter.
        var next: Int
        /// The indexed files.
        var entries: [Item]
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
    /// The saved projects: the readable ones newest first, then the unreadable ones by number.
    private(set) var entries: [ProjectLibraryEntry] = []
    /// The next file counter.
    private(set) var next = 1
    /// Whether the index was written by a newer version (the library is then read only).
    private(set) var isReadOnly = false
    /// The refusal code of the index when it could not be read; nil when it was read or there is none.
    private(set) var indexProblem: String?

    /// A library over `storage`; reads the index and the project files once.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    // MARK: Names and files

    /// The file of counter `n`: `project-<n>.json`.
    nonisolated static func fileName(_ n: Int) -> String { "project-\(n).json" }

    /// The counter n of a file named `project-<n>.json` (n ≥ 1, decimal digits only); nil otherwise.
    nonisolated static func number(of file: String) -> Int? {
        let head = "project-", tail = ".json"
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

    /// The readable project called `name` (trimmed; compared without regard to case); nil when there is none.
    func entry(named name: String) -> ProjectLibraryEntry? {
        guard let clean = Self.cleanName(name) else { return nil }
        return entries.first { $0.isReadable && $0.name.caseInsensitiveCompare(clean) == .orderedSame }
    }

    /// The entry of `file`; nil when there is none.
    func entry(file: String) -> ProjectLibraryEntry? { entries.first { $0.file == file } }

    /// The readable projects.
    var readable: [ProjectLibraryEntry] { entries.filter(\.isReadable) }

    // MARK: Encoding

    /// The encoder of both files: sorted keys, unescaped slashes.
    nonisolated private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Whether `values` are ``StudioCore/valueCount`` finite numbers within ``StudioCore/valueRange``.
    nonisolated static func valuesAreValid(_ values: [Double]) -> Bool {
        values.count == StudioCore.valueCount && values.allSatisfy { $0.isFinite && StudioCore.valueRange.contains($0) }
    }

    /// Whether `textures` are ``StudioCore/textureCount`` `TextureRecipe` raw values.
    nonisolated static func texturesAreValid(_ textures: [Int]) -> Bool {
        textures.count == StudioCore.textureCount && textures.allSatisfy { TextureRecipe(rawValue: $0) != nil }
    }

    /// The saved project file of `project` named `name` with `order`, `values` and `textures`: the envelope with
    /// sorted keys. Throws the project's ``ShaderProjectRefusal/tooLarge(_:)`` when its encoding is above 65,536
    /// bytes, or an encoding error.
    nonisolated static func encode(name: String, order: Int, project: ShaderProject, values: [Double],
                                   textures: [Int]) throws -> Data {
        let embedded = try JSONDecoder().decode(ProjectJSONValue.self, from: try project.encoded())
        let body = SavedProject(name: name, order: order, project: embedded, textures: textures, values: values)
        return try encoder().encode(Envelope(body: body, kind: projectKind, version: schemaVersion))
    }

    /// Reads a saved project file. Checks, in order: the size (`too-large`), the envelope and its kind (`damaged`),
    /// the version (`newer-version`), the body and its name (`damaged`), the values and textures (`out-of-range`),
    /// then the embedded project (`ShaderProject.decode`, any `ShaderProjectRefusal`).
    nonisolated static func decode(_ data: Data) -> Result<(saved: SavedProject, project: ShaderProject),
                                                           ShaderProjectRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == projectKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope<SavedProject>.self, from: data),
              let saved = envelope.body, let name = cleanName(saved.name), name == saved.name,
              saved.order >= 0 else { return .failure(.damaged) }
        guard valuesAreValid(saved.values) else { return .failure(.outOfRange("values")) }
        guard texturesAreValid(saved.textures) else { return .failure(.outOfRange("textures")) }
        guard let projectData = try? encoder().encode(saved.project) else { return .failure(.damaged) }
        do {
            return .success((saved, try ShaderProject.decode(projectData)))
        } catch {
            return .failure(error)
        }
    }

    /// The index file of `index`.
    nonisolated static func encode(_ index: Index) throws -> Data {
        try encoder().encode(Envelope(body: index, kind: indexKind, version: schemaVersion))
    }

    /// Reads the index file: `damaged` (not the envelope, the wrong kind or body), `newer-version` or `too-large`
    /// (above 131,072 bytes).
    nonisolated static func decodeIndex(_ data: Data) -> Result<Index, ShaderProjectRefusal> {
        guard data.count <= maxFileBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == indexKind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope<Index>.self, from: data), let index = envelope.body,
              index.next >= 1 else { return .failure(.damaged) }
        return .success(index)
    }

    // MARK: Reading and writing

    /// Reads the index and every project file again. Nothing is written or removed.
    func reload() {
        var index = Index(next: 1, entries: [])
        isReadOnly = false
        indexProblem = nil
        if storage.exists(Self.indexFile) {
            let read: Result<Index, ShaderProjectRefusal>
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
        var good: [ProjectLibraryEntry] = []
        var bad: [ProjectLibraryEntry] = []
        var highest = 0
        for file in storage.list() {
            guard let n = Self.number(of: file) else { continue }
            highest = max(highest, n)
            let decoded: Result<(saved: SavedProject, project: ShaderProject), ShaderProjectRefusal>
            do {
                decoded = Self.decode(try storage.read(file))
            } catch {
                decoded = .failure(.damaged)
            }
            switch decoded {
            case .success(let found):
                good.append(ProjectLibraryEntry(file: file, name: found.saved.name, order: found.saved.order,
                                                refusal: nil))
            case .failure(let refusal):
                bad.append(ProjectLibraryEntry(file: file, name: names[file] ?? file, order: 0, refusal: refusal.code))
            }
        }
        good.sort { $0.order != $1.order ? $0.order > $1.order : $0.number > $1.number }
        bad.sort { $0.number < $1.number }
        entries = good + bad
        next = max(index.next, highest + 1, 1)
    }

    /// Writes the index of the current entries; a failure is ignored (the project files are the truth and the
    /// counter is recovered from them).
    private func writeIndex() {
        let items = entries.map { Index.Item(file: $0.file, name: $0.name, order: $0.order) }
        guard let data = try? Self.encode(Index(next: next, entries: items)) else { return }
        try? storage.write(data, to: Self.indexFile)
    }

    /// Writes the project file `file`; the failure of an oversized file or of the storage, or nil.
    private func write(name: String, order: Int, project: ShaderProject, values: [Double], textures: [Int],
                       to file: String) -> ProjectLibraryFailure? {
        let data: Data
        do {
            data = try Self.encode(name: name, order: order, project: project, values: values, textures: textures)
        } catch let refusal as ShaderProjectRefusal {
            if case .tooLarge(let bytes) = refusal { return .tooLarge(bytes) }
            return .storage("a22.encoding")
        } catch {
            return .storage("a22.encoding")
        }
        guard data.count <= Self.maxFileBytes else { return .tooLarge(data.count) }
        do {
            try storage.write(data, to: file)
        } catch {
            return .storage(error.code)
        }
        return nil
    }

    /// The saved project of `file`, or the failure of a missing or unreadable file.
    private func read(_ file: String) -> Result<(saved: SavedProject, project: ShaderProject),
                                                ProjectLibraryFailure> {
        let data: Data
        do {
            data = try storage.read(file)
        } catch {
            return .failure(.notFound)
        }
        return Self.decode(data).mapError { .unreadable($0.code) }
    }

    // MARK: Operations

    /// Saves `project` with its normalized `values` (16, 0…1) and `textures` (2 recipe indices) as `name` (trimmed,
    /// 1…40 characters) in a new file, when no readable project has that name (compared without regard to case) and
    /// the library holds fewer than 24 files. The source is not validated: a refused source is saved as text.
    /// Returns the saved entry; a refusal changes nothing on disk.
    @discardableResult
    func save(name raw: String, project: ShaderProject, values: [Double],
              textures: [Int]) -> Result<ProjectLibraryEntry, ProjectLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let name = Self.cleanName(raw) else { return .failure(.invalidName) }
        if let other = entry(named: name) { return .failure(.nameTaken(other.name)) }
        guard entries.count < Self.maxProjects else { return .failure(.full) }
        guard Self.valuesAreValid(values) else { return .failure(.invalidState("values")) }
        guard Self.texturesAreValid(textures) else { return .failure(.invalidState("textures")) }
        let order = (entries.map(\.order).max() ?? 0) + 1
        let file = Self.fileName(next)
        if let failure = write(name: name, order: order, project: project, values: values, textures: textures,
                               to: file) {
            return .failure(failure)
        }
        next += 1
        reload()
        writeIndex()
        return entry(file: file).map { .success($0) } ?? .failure(.notFound)
    }

    /// The project, values and textures of the readable file `file`, read again from it. An unreadable file is
    /// refused with its code (and the list is read again when the file changed since it was listed). Opening works
    /// in a read-only library.
    func open(_ file: String) -> Result<OpenedProject, ProjectLibraryFailure> {
        guard let entry = entry(file: file) else { return .failure(.notFound) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        switch read(file) {
        case .success(let found):
            return .success(OpenedProject(entry: entry, project: found.project, values: found.saved.values,
                                          textures: found.saved.textures))
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
    }

    /// Renames the readable project `file` to `name` (trimmed, 1…40 characters), keeping its order, project, values
    /// and textures; refused with "A project is already called <name>." when another project has that name, and
    /// with the code of an unreadable file.
    @discardableResult
    func rename(_ file: String, to raw: String) -> Result<ProjectLibraryEntry, ProjectLibraryFailure> {
        guard !isReadOnly else { return .failure(.readOnly) }
        guard let entry = entry(file: file) else { return .failure(.notFound) }
        if let code = entry.refusal { return .failure(.unreadable(code)) }
        guard let name = Self.cleanName(raw) else { return .failure(.invalidName) }
        if let other = self.entry(named: name), other.file != file { return .failure(.nameTaken(other.name)) }
        let found: (saved: SavedProject, project: ShaderProject)
        switch read(file) {
        case .success(let value):
            found = value
        case .failure(let failure):
            reload()
            return .failure(failure)
        }
        if let failure = write(name: name, order: found.saved.order, project: found.project,
                               values: found.saved.values, textures: found.saved.textures, to: file) {
            return .failure(failure)
        }
        reload()
        writeIndex()
        return self.entry(file: file).map { .success($0) } ?? .failure(.notFound)
    }

    /// Removes the project `file`, readable or not. Only this explicit call removes a file; nothing is deleted
    /// automatically.
    @discardableResult
    func remove(_ file: String) -> Result<ProjectLibraryEntry, ProjectLibraryFailure> {
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
}
