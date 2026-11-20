// ControlHistory — feature 222 (R02-F22) T-R02F22-005 (FR-R02F22-004, 006; SC-R02F22-004, 006; clarification Q4;
// research R5). A bounded undo and redo history of value snapshots: each entry holds the value before and after one
// edit, a drag is coalesced into one entry by its key, and the history has a versioned JSON stored form (schema 1,
// sorted keys) whose newer and damaged forms are refused. Effects Composer keeps its own experience-local history.
import Foundation

/// A bounded undo and redo history of edits to a value, stored as (before, after) snapshots.
///
/// Entries are kept in the order they were made; the newest ``undoCount`` entries are applied and the trailing
/// ``redoCount`` entries are undone. Recording an edit clears redo. A run of records with the same non-nil coalescing
/// key (the events of one drag) becomes one entry until ``endCoalescing()`` is called or another edit intervenes.
public struct ControlHistory<Value: Sendable & Equatable & Codable>: Sendable, Equatable, Codable {
    /// The current stored-form schema.
    public static var schema: Int { 1 }

    /// The largest allowed depth.
    public static var maxDepth: Int { 1_000 }

    /// One recorded edit.
    struct Entry: Sendable, Equatable, Codable {
        /// The label shown in menus and spoken by VoiceOver.
        var label: String
        /// The value before the edit.
        var before: Value
        /// The value after the edit.
        var after: Value
        /// The coalescing key, if any.
        var key: String?
    }

    /// The largest number of entries (applied and undone) the history keeps, 1 … ``maxDepth``.
    public let depth: Int

    /// How many of the oldest entries were dropped because the history was full.
    public private(set) var dropped: Int

    /// Every entry, oldest first; the trailing ``undone`` entries are on the redo side.
    private(set) var entries: [Entry]

    /// How many trailing entries are undone.
    private(set) var undone: Int

    /// Whether the newest applied entry still takes merges from records with its key.
    private(set) var open: Bool

    /// Whether there is an edit to undo.
    public var canUndo: Bool { undoCount > 0 }

    /// Whether there is an undone edit to redo.
    public var canRedo: Bool { undone > 0 }

    /// The number of edits that can be undone.
    public var undoCount: Int { entries.count - undone }

    /// The number of edits that can be redone.
    public var redoCount: Int { undone }

    /// The label of the edit the next ``undo()`` reverts, for menus and VoiceOver; nil when there is none.
    public var undoLabel: String? { canUndo ? entries[undoCount - 1].label : nil }

    /// The label of the edit the next ``redo()`` reapplies, for menus and VoiceOver; nil when there is none.
    public var redoLabel: String? { canRedo ? entries[undoCount].label : nil }

    /// Creates an empty history.
    ///
    /// - Parameter depth: the largest number of entries kept, 1 … 1,000 (default 100).
    /// - Throws: `.historyDepth` for a depth outside 1 … ``maxDepth``.
    public init(depth: Int = 100) throws(SpatialControlError) {
        guard depth >= 1, depth <= Self.maxDepth else { throw .historyDepth }
        self.depth = depth
        self.dropped = 0
        self.entries = []
        self.undone = 0
        self.open = false
    }

    /// Records one edit.
    ///
    /// An edit with `before == after` is ignored. When `key` is non-nil, equals the newest entry's key and that entry
    /// is still open, the edit merges into it: the entry keeps its first `before` and label and takes the new `after`;
    /// a merge that brings the entry back to its own `before` removes it. Otherwise a new entry is appended. Anything
    /// recorded or merged clears redo; past ``depth`` the oldest entry is dropped and counted in ``dropped``.
    ///
    /// - Parameters:
    ///   - label: the label of the edit, for menus and VoiceOver.
    ///   - before: the value before this edit.
    ///   - after: the value after this edit.
    ///   - key: the coalescing key (for example a handle id during one drag), or nil for a standalone edit.
    public mutating func record(_ label: String, before: Value, after: Value, coalescing key: String? = nil) {
        guard before != after else { return }
        if let key, open, undone == 0, let last = entries.last, last.key == key {
            entries[entries.count - 1].after = after
            if entries[entries.count - 1].before == entries[entries.count - 1].after {
                entries.removeLast()
                open = false
            }
            return
        }
        if undone > 0 {
            entries.removeLast(undone)
            undone = 0
        }
        entries.append(Entry(label: label, before: before, after: after, key: key))
        open = key != nil
        if entries.count > depth {
            let excess: Int = entries.count - depth
            entries.removeFirst(excess)
            dropped += excess
        }
    }

    /// Undoes the newest applied edit.
    ///
    /// - Returns: the value to restore (that entry's `before`), or nil when there is nothing to undo, in which case
    ///   the history is unchanged.
    public mutating func undo() -> Value? {
        guard canUndo else { return nil }
        let value: Value = entries[undoCount - 1].before
        undone += 1
        open = false
        return value
    }

    /// Redoes the oldest undone edit.
    ///
    /// - Returns: the value to apply (that entry's `after`), or nil when there is nothing to redo, in which case the
    ///   history is unchanged.
    public mutating func redo() -> Value? {
        guard canRedo else { return nil }
        let value: Value = entries[undoCount].after
        undone -= 1
        open = false
        return value
    }

    /// Closes the newest entry to merges, so the next record with the same key starts a new entry (for example a
    /// second drag of the same handle).
    public mutating func endCoalescing() {
        open = false
    }

    // MARK: - Stored form

    /// The schema-1 stored form.
    private struct StoredForm: Codable {
        var schema: Int
        var depth: Int
        var dropped: Int
        var entries: [Entry]
        var undone: Int
        var open: Bool
    }

    /// Reads only the schema, so a newer form is recognised before the rest is read.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// The history as its stored form.
    private var storedForm: StoredForm {
        StoredForm(schema: Self.schema, depth: depth, dropped: dropped, entries: entries, undone: undone, open: open)
    }

    /// Builds a history from a stored form and checks every rule.
    private init(stored: StoredForm) throws(SpatialControlError) {
        guard stored.schema <= Self.schema else { throw .newerSchema(stored.schema) }
        guard stored.schema >= 1 else { throw .malformed("schema below 1") }
        guard stored.depth >= 1, stored.depth <= Self.maxDepth else { throw .malformed("depth outside 1 … 1000") }
        guard stored.entries.count <= stored.depth else { throw .malformed("more entries than depth") }
        guard stored.dropped >= 0 else { throw .malformed("negative dropped") }
        guard stored.undone >= 0, stored.undone <= stored.entries.count else {
            throw .malformed("undone outside 0 … entries")
        }
        guard !stored.open || (stored.undone == 0 && !stored.entries.isEmpty) else {
            throw .malformed("open without an applied newest entry")
        }
        for entry in stored.entries where entry.before == entry.after {
            throw .malformed("entry without a change")
        }
        self.depth = stored.depth
        self.dropped = stored.dropped
        self.entries = stored.entries
        self.undone = stored.undone
        self.open = stored.open
    }

    /// Encodes the history as its schema-1 stored form.
    public func encode(to encoder: any Encoder) throws {
        try storedForm.encode(to: encoder)
    }

    /// Decodes a history and checks every rule of the stored form; a broken rule or a newer schema is a
    /// `DecodingError.dataCorrupted` whose description is the reason code.
    public init(from decoder: any Decoder) throws {
        let stored: StoredForm = try StoredForm(from: decoder)
        do {
            try self.init(stored: stored)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The stored form as JSON with sorted keys.
    ///
    /// Unlike the stored forms whose values are all known to be finite, `Value` is chosen by the caller and its own
    /// encoding can fail (for example a non-finite `Double`, which JSON cannot hold), so this throws.
    ///
    /// - Throws: `.malformed(description)` when `Value` cannot be encoded as JSON.
    public func encoded() throws(SpatialControlError) -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(storedForm)
        } catch {
            throw .malformed("unencodable: \(error)")
        }
    }

    /// Reads a history from its stored form and re-runs every rule.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, a depth outside 1 … ``maxDepth``, more entries than the depth,
    ///   a negative dropped count, an undone count outside the entries, an open flag without an applied newest
    ///   entry, or an entry whose before equals its after.
    public static func decode(_ data: Data) throws(SpatialControlError) -> ControlHistory {
        let decoder: JSONDecoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        let stored: StoredForm
        do {
            stored = try decoder.decode(StoredForm.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        return try ControlHistory(stored: stored)
    }
}
