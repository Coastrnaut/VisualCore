// NamedLibrary.swift — a generic library of named, favoritable documents on a DocumentStore (feature 028 T-A03-302;
// gap G-LIBRARY; FR-A03-302; research R2). Generalized from A01's CompositionLibrary (feature 014) so that any app
// can keep saved views, bookmarks, presets or patches with the same naming, ordering and damage-reporting rules.
import Foundation

/// The user's saved documents of one kind: names, favorites and times around a caller-validated payload, stored one
/// file per entry. Ordering: favorites first, then most recently modified, then name. Damaged, newer-version or
/// invalid files are reported in `problems` and never deleted.
public struct NamedLibrary<Payload: Codable & Sendable & Equatable>: Sendable {
    /// One saved document (the stored value of each file).
    public struct Entry: Codable, Equatable, Sendable, Identifiable {
        /// Identity (also the file id); names may repeat.
        public var id: UUID
        /// Display name (normalized: trimmed, at most `maxNameLength` characters, never empty).
        public var name: String
        /// Listed first when true.
        public var favorite: Bool
        /// When first saved (whole seconds).
        public var createdAt: Date
        /// When last saved or changed (whole seconds).
        public var modifiedAt: Date
        /// The document (validated on load and save).
        public var payload: Payload

        /// Creates an entry as stored.
        public init(id: UUID, name: String, favorite: Bool, createdAt: Date, modifiedAt: Date, payload: Payload) {
            self.id = id; self.name = name; self.favorite = favorite
            self.createdAt = createdAt; self.modifiedAt = modifiedAt; self.payload = payload
        }
    }

    /// Longest name kept.
    public static var maxNameLength: Int { 60 }

    /// The underlying store.
    public let store: DocumentStore<Entry>
    /// Returns the payload made valid, or nil when it cannot be used (the file is then reported as corrupt).
    public let validate: @Sendable (Payload) -> Payload?
    /// Entries in display order.
    public private(set) var entries: [Entry] = []
    /// Files that could not be used (left untouched), from the last `reload()`.
    public private(set) var problems: [StoreProblem] = []

    /// A library of `kind` in `directory`, at schema `migrations.currentVersion`, with a payload check.
    public init(directory: URL, kind: String, migrations: MigrationChain,
                validate: @escaping @Sendable (Payload) -> Payload? = { $0 }) {
        store = DocumentStore(directory: directory, kind: kind, migrations: migrations)
        self.validate = validate
    }

    /// `Application Support/<name>` in the app container.
    public static func defaultDirectory(named name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
    }

    /// Trims, caps at `maxNameLength` characters and replaces an empty name with "Untitled".
    public static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maxNameLength))
    }

    /// Times are stored to whole seconds (ISO 8601), so in-memory entries equal what a reload returns.
    static func stored(_ date: Date) -> Date { Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)) }

    static func ordered(_ entries: [Entry]) -> [Entry] {
        entries.sorted {
            if $0.favorite != $1.favorite { return $0.favorite }
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Re-reads the folder. Entries whose payload fails `validate` are reported as corrupt and skipped.
    public mutating func reload() {
        let report = store.load()
        var good: [Entry] = []
        var bad = report.problems
        for item in report.items {
            if let valid = validate(item.value.payload) {
                var entry = item.value
                entry.payload = valid
                good.append(entry)
            } else {
                bad.append(.corrupt(file: item.id + ".json", reason: "invalid payload"))
            }
        }
        entries = Self.ordered(good)
        problems = bad
    }

    /// The entry with `id`.
    public func entry(_ id: UUID) -> Entry? { entries.first { $0.id == id } }

    /// Saves `payload` as a new entry, or updates `id` in place (same identity and creation time, newer modification
    /// time). A missing `id` is recreated. An invalid payload throws `.corrupt` and writes nothing.
    @discardableResult
    public mutating func save(_ payload: Payload, name: String, id: UUID? = nil, now: Date = Date()) throws(StoreProblem) -> Entry {
        guard let valid = validate(payload) else { throw .corrupt(file: (id?.uuidString ?? "new") + ".json", reason: "invalid payload") }
        let now = Self.stored(now)
        let existing = id.flatMap(entry)
        let e = Entry(id: id ?? UUID(), name: Self.normalizedName(name), favorite: existing?.favorite ?? false,
                      createdAt: existing?.createdAt ?? now, modifiedAt: now, payload: valid)
        try write(e, now: now)
        return e
    }

    /// A new, independent copy named "<name> copy" (new identity, not a favorite).
    @discardableResult
    public mutating func duplicate(_ id: UUID, now: Date = Date()) throws(StoreProblem) -> Entry {
        guard let original = entry(id) else { throw .notFound(id: id.uuidString) }
        return try save(original.payload, name: original.name + " copy", now: now)
    }

    /// Renames (normalized) and updates the modification time.
    public mutating func rename(_ id: UUID, to name: String, now: Date = Date()) throws(StoreProblem) {
        guard var e = entry(id) else { throw .notFound(id: id.uuidString) }
        e.name = Self.normalizedName(name)
        e.modifiedAt = Self.stored(now)
        try write(e, now: now)
    }

    /// Marks or unmarks a favorite (the modification time is kept).
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

    private mutating func write(_ e: Entry, now: Date) throws(StoreProblem) {
        try store.save(e, id: e.id.uuidString, now: now)
        entries.removeAll { $0.id == e.id }
        entries = Self.ordered(entries + [e])
    }
}
