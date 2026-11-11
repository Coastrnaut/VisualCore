// CompositionLibrary.swift — saved compositions with names, favorites and times on a VisualCore DocumentStore
// (feature 014 T-A01-303; FR-A01-301–FR-A01-307; data model specs/014-gas-p03-save-restore/data-model.md).
import Foundation
import VisualCorePersistence

/// One saved composition (stored payload, schema 1).
public struct LibraryEntry: Codable, Equatable, Sendable, Identifiable {
    /// Identity (also the file id); names may repeat.
    public var id: UUID
    /// Display name (normalized: trimmed, ≤ 60 characters, never empty).
    public var name: String
    /// Listed first when true.
    public var favorite: Bool
    /// When first saved.
    public var createdAt: Date
    /// When last saved or changed.
    public var modifiedAt: Date
    /// The composition (validated on load).
    public var document: ArtDocument
}

/// The user's saved compositions. Ordering: favorites first, then most recently modified, then name.
public struct CompositionLibrary: Sendable {
    /// Envelope kind of composition files.
    public static let kind = "dev.visualcore.gas.composition"
    /// Stored schema version of `LibraryEntry`.
    public static let schemaVersion = 1
    /// Longest name kept.
    public static let maxNameLength = 60

    /// The underlying VisualCore store.
    public let store: DocumentStore<LibraryEntry>
    /// Entries in display order.
    public private(set) var entries: [LibraryEntry] = []
    /// Files that could not be read (left untouched), from the last `reload()`.
    public private(set) var problems: [StoreProblem] = []

    /// A library in `directory` (the app passes `Application Support/Compositions`).
    public init(directory: URL) {
        store = DocumentStore(directory: directory, kind: Self.kind,
                              migrations: MigrationChain(currentVersion: Self.schemaVersion))
    }

    /// The default directory: `Application Support/Compositions` in the app container.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Compositions", isDirectory: true)
    }

    /// Trims, caps at 60 characters and replaces empty names with "Untitled".
    public static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maxNameLength))
    }

    /// Times are stored with whole-second precision (ISO 8601); in-memory entries use the same precision so a reload
    /// equals what was saved.
    static func stored(_ date: Date) -> Date { Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)) }

    static func ordered(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        entries.sorted {
            if $0.favorite != $1.favorite { return $0.favorite }
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Re-reads the folder; entries whose composition fails validation are reported as corrupt.
    public mutating func reload() {
        let report = store.load()
        var good: [LibraryEntry] = []
        var bad = report.problems
        for item in report.items {
            if let (valid, _) = try? item.value.document.validated() {
                var entry = item.value
                entry.document = valid
                good.append(entry)
            } else {
                bad.append(.corrupt(file: item.id + ".json", reason: "invalid composition"))
            }
        }
        entries = Self.ordered(good)
        problems = bad
    }

    /// The entry with `id`.
    public func entry(_ id: UUID) -> LibraryEntry? { entries.first { $0.id == id } }

    /// Saves `document` as a new entry, or updates `id` in place (same identity, newer `modifiedAt`). A missing `id`
    /// (e.g. deleted while open) is recreated.
    @discardableResult
    public mutating func save(document: ArtDocument, name: String, id: UUID? = nil, now: Date = Date()) throws(StoreProblem) -> LibraryEntry {
        let now = Self.stored(now)
        let validDocument = (try? document.validated().document) ?? document
        let existing = id.flatMap(entry)
        let entry = LibraryEntry(id: id ?? UUID(), name: Self.normalizedName(name), favorite: existing?.favorite ?? false,
                                 createdAt: existing?.createdAt ?? now, modifiedAt: now, document: validDocument)
        try store.save(entry, id: entry.id.uuidString, now: now)
        entries.removeAll { $0.id == entry.id }
        entries = Self.ordered(entries + [entry])
        return entry
    }

    /// A new, independent copy named "<name> copy" (new identity, not a favorite).
    @discardableResult
    public mutating func duplicate(_ id: UUID, now: Date = Date()) throws(StoreProblem) -> LibraryEntry {
        guard let original = entry(id) else { throw .notFound(id: id.uuidString) }
        var document = original.document
        document.id = UUID()
        return try save(document: document, name: Self.normalizedName(original.name + " copy"), now: now)
    }

    /// Renames (normalized) and bumps `modifiedAt`.
    public mutating func rename(_ id: UUID, to name: String, now: Date = Date()) throws(StoreProblem) {
        guard var e = entry(id) else { throw .notFound(id: id.uuidString) }
        e.name = Self.normalizedName(name)
        e.modifiedAt = Self.stored(now)
        try write(e, now: now)
    }

    /// Marks or unmarks a favorite.
    public mutating func setFavorite(_ id: UUID, _ favorite: Bool) throws(StoreProblem) {
        guard var e = entry(id) else { throw .notFound(id: id.uuidString) }
        e.favorite = favorite
        try write(e, now: Date())
    }

    /// Deletes the entry's file.
    public mutating func delete(_ id: UUID) throws(StoreProblem) {
        try store.delete(id: id.uuidString)
        entries.removeAll { $0.id == id }
    }

    private mutating func write(_ e: LibraryEntry, now: Date) throws(StoreProblem) {
        try store.save(e, id: e.id.uuidString, now: now)
        entries.removeAll { $0.id == e.id }
        entries = Self.ordered(entries + [e])
    }
}
