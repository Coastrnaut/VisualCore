// ParticleLibrary — feature 036 (A04-P04) T-A04-407 (FR-A04-405, FR-A04-414; US1; research D4; data model "Library
// entry"). The named scenes of Particle Universe: one file `scene-<uuid>.json` per scene in the experience's own
// storage, following the `FractalBookmarks` pattern (entries by name, unreadable files counted and never deleted, the
// last failure as a message). Writes go through `ExperienceStorage.write`, which replaces a file atomically and
// enforces the storage quota, so a refused save leaves every existing file as it was.
//
// File content (format 1 of the wrapper): `{"document": <SceneDocument version 2>, "id": "<uuid>", "saved":
// <seconds since 2001-01-01>}` with sorted keys. The scene itself is versioned by `SceneDocument` (`version` inside
// `document`); a document of another version makes the file unreadable here. The `id` must match the file name.
import Foundation
import Observation
import ParticleUniverseCore
import VisualCoreExperience

/// One saved scene in the library (the scene itself is read only when it is opened).
struct ParticleLibraryEntry: Equatable, Identifiable, Sendable {
    /// The identifier, also part of the file name.
    var id: UUID
    /// The scene's name, unique in the library ignoring case.
    var name: String
    /// When the scene was last saved.
    var saved: Date
}

/// The library of named scenes, sorted by name.
@MainActor
@Observable
final class ParticleLibrary {
    /// The file name prefix of a saved scene.
    static let filePrefix = "scene-"
    /// The file name extension of a saved scene.
    static let fileExtension = ".json"

    /// The stored form of one file.
    private struct File: Codable {
        var id: UUID
        var saved: Date
        var document: SceneDocument
    }

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The saved scenes, sorted by name.
    private(set) var entries: [ParticleLibraryEntry] = []
    /// Scene files that could not be read (shown as a count, never deleted).
    private(set) var unreadable = 0
    /// Scene files made by a newer version of the app (shown as a count, never deleted; T-A04-422, FR-A04-410).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    var errorMessage: String?
    /// The clock for the saved time (a seam for tests).
    private let now: () -> Date

    /// A library over `storage`; lists the saved scenes at once.
    init(storage: ExperienceStorage, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        reload()
    }

    /// The file name of the scene `id`: `scene-<lowercased uuid>.json`.
    static func fileName(for id: UUID) -> String { filePrefix + id.uuidString.lowercased() + fileExtension }

    /// Re-reads the storage: every `scene-*.json` file that decodes and validates becomes an entry; every other one
    /// is counted in `unreadable` and left in place.
    func reload() {
        var found: [ParticleLibraryEntry] = []
        var bad = 0, newerFound = 0
        for name in storage.list() where name.hasPrefix(Self.filePrefix) && name.hasSuffix(Self.fileExtension) {
            let file: File
            do {
                file = try read(name)
            } catch SceneError.unsupportedVersion(let version) where version > SceneDocument.version {
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
            found.append(ParticleLibraryEntry(id: file.id, name: file.document.name, saved: file.saved))
        }
        newer = newerFound
        entries = found.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
        unreadable = bad
    }

    /// Saves `document` as a new scene. A name already in the library (ignoring case) gets the next free suffix
    /// (" 2", " 3", …), shortening the name so that it stays within `SceneDocument.maxNameLength`; nothing is
    /// overwritten. Returns the new entry, or nil with `errorMessage` set when the storage refuses (for example
    /// when it is full); existing files are unchanged then.
    @discardableResult
    func save(_ document: SceneDocument) -> ParticleLibraryEntry? {
        var document = document
        document.name = uniqueName(Self.clean(document.name) ?? SceneDocument.untitledName, excluding: nil)
        let file = File(id: UUID(), saved: now(), document: document)
        guard write(file, failure: "The scene could not be saved") else { return nil }
        return ParticleLibraryEntry(id: file.id, name: document.name, saved: file.saved)
    }

    /// The saved scene of `entry`, or nil with `errorMessage` set when it is gone or cannot be read (a scene from a
    /// newer version is refused as "made by a newer version").
    func document(for entry: ParticleLibraryEntry) -> SceneDocument? {
        do {
            let document = try read(Self.fileName(for: entry.id)).document
            errorMessage = nil
            return document
        } catch SceneError.unsupportedVersion(let v) where v > SceneDocument.version {
            errorMessage = "The scene was made by a newer version."
        } catch {
            errorMessage = "The scene could not be opened (\(Self.reason(error)))."
        }
        return nil
    }

    /// Renames `entry` to `name` (trimmed, at most `SceneDocument.maxNameLength` characters). Refused, with
    /// `errorMessage` set, for an empty name or a name another scene has (ignoring case). Keeps the saved time.
    @discardableResult
    func rename(_ entry: ParticleLibraryEntry, to name: String) -> Bool {
        guard let clean = Self.clean(name) else {
            errorMessage = "A scene needs a name."
            return false
        }
        if entries.contains(where: { $0.id != entry.id && Self.same($0.name, clean) }) {
            errorMessage = "A scene named \u{201C}\(clean)\u{201D} already exists."
            return false
        }
        let file: File
        do {
            file = try read(Self.fileName(for: entry.id))
        } catch {
            errorMessage = "The scene could not be renamed (\(Self.reason(error)))."
            reload()
            return false
        }
        var renamed = file
        renamed.document.name = clean
        return write(renamed, failure: "The scene could not be renamed")
    }

    /// Deletes the file of `entry`. Returns false, with `errorMessage` set, when the storage refuses.
    @discardableResult
    func remove(_ entry: ParticleLibraryEntry) -> Bool {
        defer { reload() }
        do {
            try storage.remove(Self.fileName(for: entry.id))
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The scene could not be deleted (\(Self.reason(error)))."
            return false
        }
    }

    // MARK: Helpers

    /// `name` trimmed and cut to `SceneDocument.maxNameLength` characters; nil when empty.
    static func clean(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(SceneDocument.maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `name`, or the first of `name 2`, `name 3`, … that no entry (other than `excluding`) has.
    private func uniqueName(_ name: String, excluding: UUID?) -> String {
        let taken = entries.filter { $0.id != excluding }.map(\.name)
        func free(_ candidate: String) -> Bool { !taken.contains { Self.same($0, candidate) } }
        guard !free(name) else { return name }
        var n = 2
        while true {
            let suffix = " \(n)"
            let base = String(name.prefix(SceneDocument.maxNameLength - suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = base + suffix
            if free(candidate) { return candidate }
            n += 1
        }
    }

    private static func same(_ a: String, _ b: String) -> Bool { a.caseInsensitiveCompare(b) == .orderedSame }

    private func read(_ name: String) throws -> File {
        let data = try storage.read(name)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity",
                                                                        negativeInfinity: "-Infinity", nan: "NaN")
        // A `SceneError` thrown by `SceneDocument.init(from:)` reaches the caller unchanged.
        return try decoder.decode(File.self, from: data)
    }

    /// Validates and writes `file`; on success clears the message and reloads.
    private func write(_ file: File, failure: String) -> Bool {
        do {
            try file.document.validate()
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

    private static func reason(_ error: Error) -> String {
        if let storage = error as? StorageError { return storage.code }
        if let scene = error as? SceneError { return "\(scene)" }
        return "\(error)"
    }
}
