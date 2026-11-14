// GeometryLibrary — feature 043 (A05-P04) T-A05-403 (FR-A05-402, FR-A05-403, FR-A05-405; US1; data model "Library
// file"; clarifications 2, 3 and 5). The saved compositions of Infinite Geometry: one file `composition-<uuid>.json`
// per composition in the experience's own storage, following `ParticleLibrary` (entries by name, unreadable and newer
// files counted and never deleted or rewritten, the last failure as a message). Writes go through
// `ExperienceStorage.write`, which replaces a file atomically and enforces the storage quota, so a refused save leaves
// every existing file as it was.
//
// File content (format 1): `{"digest": "<hex at save time>", "document": <GeometryDocument version 1>, "format": 1,
// "id": "<uuid>", "saved": <seconds since 2001-01-01>}` with sorted keys. The `id` must match the file name. A file of
// a greater `format`, or whose document has a greater `version` than `GeometryDocument.version`, is counted in
// `newer`, refused when opened and never rewritten; any other file that does not decode is counted in `unreadable`.
// Names are cleaned by `GeometryDocument.clean` (trimmed, at most 60 characters, empty → "Untitled") and made unique
// ignoring case with the first free numeric suffix (" 2", " 3", …), on save and on rename, so neither is ever refused
// for its name and nothing is replaced silently.
import Foundation
import Observation
import VisualCoreExperience

/// One saved composition in the library (the composition itself is read only when it is opened).
struct GeometryLibraryEntry: Equatable, Identifiable, Sendable {
    /// The identifier, also part of the file name.
    var id: UUID
    /// The composition's name, unique in the library ignoring case.
    var name: String
    /// When the composition was last saved.
    var saved: Date
    /// The experience state digest at save time (hex).
    var digest: String
}

/// The library of saved compositions, sorted by name.
@MainActor
@Observable
final class GeometryLibrary {
    /// The file name prefix of a saved composition.
    static let filePrefix = "composition-"
    /// The file name extension of a saved composition.
    static let fileExtension = ".json"
    /// The format of the file written by this version; a greater format is counted in `newer` and refused.
    nonisolated static let format = 1

    /// Why a file is of a newer version than this one can read.
    private enum NewerError: Error {
        /// The file's wrapper format is newer.
        case format(Int)
        /// The document inside the file has a newer version.
        case document(Int)
    }

    /// The document's version alone, read before the document so a newer one is recognised as newer.
    private struct VersionProbe: Decodable {
        /// The document version.
        var version: Int
    }

    /// The stored form of one file.
    private struct File: Codable {
        /// The wrapper format (written as `GeometryLibrary.format`).
        var format: Int = GeometryLibrary.format
        /// The identifier; must match the file name.
        var id: UUID
        /// When the composition was saved.
        var saved: Date
        /// The state digest at save time.
        var digest: String
        /// The composition.
        var document: GeometryDocument

        init(id: UUID, saved: Date, digest: String, document: GeometryDocument) {
            self.id = id
            self.saved = saved
            self.digest = digest
            self.document = document
        }

        private enum CodingKeys: String, CodingKey { case digest, document, format, id, saved }

        /// Reads the format and the document version first, so a newer file is refused before its document is
        /// decoded.
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            format = try c.decode(Int.self, forKey: .format)
            guard format <= GeometryLibrary.format else { throw NewerError.format(format) }
            let version = try c.decode(VersionProbe.self, forKey: .document).version
            guard version <= GeometryDocument.version else { throw NewerError.document(version) }
            id = try c.decode(UUID.self, forKey: .id)
            saved = try c.decode(Date.self, forKey: .saved)
            digest = try c.decode(String.self, forKey: .digest)
            document = try c.decode(GeometryDocument.self, forKey: .document)
            guard document.version == GeometryDocument.version else {
                throw DecodingError.dataCorruptedError(forKey: .document, in: c,
                                                       debugDescription: "unsupported document version")
            }
        }
    }

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The saved compositions, sorted by name.
    private(set) var entries: [GeometryLibraryEntry] = []
    /// Composition files that could not be read (shown as a count, never deleted).
    private(set) var unreadable = 0
    /// Composition files made by a newer version of the app (shown as a count, never deleted).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    var errorMessage: String?
    /// The clock for the saved time (a seam for tests).
    private let now: () -> Date

    /// A library over `storage`; lists the saved compositions at once.
    init(storage: ExperienceStorage, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        reload()
    }

    /// The file name of the composition `id`: `composition-<lowercased uuid>.json`.
    static func fileName(for id: UUID) -> String { filePrefix + id.uuidString.lowercased() + fileExtension }

    /// Re-reads the storage: every `composition-*.json` file that decodes and whose id matches its name becomes an
    /// entry; newer files are counted in `newer`, every other one in `unreadable`, and all are left in place.
    func reload() {
        var found: [GeometryLibraryEntry] = []
        var bad = 0, newerFound = 0
        for name in storage.list() where name.hasPrefix(Self.filePrefix) && name.hasSuffix(Self.fileExtension) {
            let file: File
            do {
                file = try read(name)
            } catch is NewerError {
                newerFound += 1
                continue
            } catch {
                bad += 1
                continue
            }
            guard Self.fileName(for: file.id) == name else {
                bad += 1
                continue
            }
            found.append(GeometryLibraryEntry(id: file.id, name: file.document.name, saved: file.saved,
                                              digest: file.digest))
        }
        entries = found.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
        newer = newerFound
        unreadable = bad
    }

    /// Saves `document` with the state `digest` as a new composition. The name is cleaned (empty → "Untitled") and a
    /// name already in the library (ignoring case) gets the next free suffix, shortened to stay within
    /// `GeometryDocument.maxNameLength`; nothing is overwritten. Returns the new entry, or nil with `errorMessage` set
    /// when the storage refuses (for example when it is full); existing files are unchanged then.
    @discardableResult
    func save(_ document: GeometryDocument, digest: String) -> GeometryLibraryEntry? {
        var document = document
        document.name = uniqueName(GeometryDocument.clean(document.name), excluding: nil)
        let file = File(id: UUID(), saved: now(), digest: digest, document: document)
        guard write(file, failure: "The composition could not be saved") else { return nil }
        return GeometryLibraryEntry(id: file.id, name: document.name, saved: file.saved, digest: digest)
    }

    /// The saved composition of `entry`, or nil with `errorMessage` set when it is gone or cannot be read (one from a
    /// newer version is refused as "made by a newer version").
    func document(for entry: GeometryLibraryEntry) -> GeometryDocument? {
        do {
            let document = try read(Self.fileName(for: entry.id)).document
            errorMessage = nil
            return document
        } catch is NewerError {
            errorMessage = "The composition was made by a newer version."
        } catch {
            errorMessage = "The composition could not be opened (\(Self.reason(error)))."
        }
        return nil
    }

    /// Renames `entry` to `name`, cleaned (empty → "Untitled") and given the next free suffix when another
    /// composition has it (ignoring case). Keeps the saved time and the digest. Returns false, with `errorMessage`
    /// set, when the file cannot be read or written.
    @discardableResult
    func rename(_ entry: GeometryLibraryEntry, to name: String) -> Bool {
        let file: File
        do {
            file = try read(Self.fileName(for: entry.id))
        } catch {
            errorMessage = "The composition could not be renamed (\(Self.reason(error)))."
            reload()
            return false
        }
        var renamed = file
        renamed.format = Self.format
        renamed.document.name = uniqueName(GeometryDocument.clean(name), excluding: entry.id)
        return write(renamed, failure: "The composition could not be renamed")
    }

    /// Deletes the file of `entry`. Returns false, with `errorMessage` set, when the storage refuses.
    @discardableResult
    func delete(_ entry: GeometryLibraryEntry) -> Bool {
        defer { reload() }
        do {
            try storage.remove(Self.fileName(for: entry.id))
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The composition could not be deleted (\(Self.reason(error)))."
            return false
        }
    }

    // MARK: Helpers

    /// `name`, or the first of `name 2`, `name 3`, … that no entry (other than `excluding`) has.
    private func uniqueName(_ name: String, excluding: UUID?) -> String {
        let taken = entries.filter { $0.id != excluding }.map(\.name)
        func free(_ candidate: String) -> Bool { !taken.contains { Self.same($0, candidate) } }
        guard !free(name) else { return name }
        var n = 2
        while true {
            let suffix = " \(n)"
            let base = String(name.prefix(GeometryDocument.maxNameLength - suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = base + suffix
            if free(candidate) { return candidate }
            n += 1
        }
    }

    /// Whether two names are the same ignoring case.
    private static func same(_ a: String, _ b: String) -> Bool { a.caseInsensitiveCompare(b) == .orderedSame }

    /// Reads and decodes the file `name`.
    private func read(_ name: String) throws -> File {
        try JSONDecoder().decode(File.self, from: try storage.read(name))
    }

    /// Writes `file` atomically; on success clears the message and reloads.
    private func write(_ file: File, failure: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try storage.write(try encoder.encode(file), to: Self.fileName(for: file.id))
        } catch {
            errorMessage = "\(failure) (\(Self.reason(error)))."
            return false
        }
        errorMessage = nil
        reload()
        return true
    }

    /// A short reason for `error`: the storage error code, or the error's description.
    private static func reason(_ error: Error) -> String {
        if let storage = error as? StorageError { return storage.code }
        return "\(error)"
    }
}
