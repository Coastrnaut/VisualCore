// DocumentStore.swift — a folder of versioned JSON documents with atomic writes, migrations and per-file problem
// reporting (feature 014 T-A01-301; FR-A01-305–FR-A01-307, FR-A01-309; research R1–R3). Foundation only (rule R2).
import Foundation

/// A document read from the store.
public struct StoredItem<Value: Sendable>: Sendable {
    /// File id (file name without `.json`).
    public let id: String
    /// The decoded value at the current schema version.
    public let value: Value
    /// When the file was written.
    public let savedAt: Date
    /// The stored version when it was migrated on load (the file itself is not rewritten), else nil.
    public let migratedFrom: Int?
}

/// Everything a `load()` found: readable items (sorted by id) and one problem per unreadable file.
public struct LoadReport<Value: Sendable>: Sendable {
    /// Readable documents.
    public let items: [StoredItem<Value>]
    /// Unreadable files with reasons; those files are left untouched.
    public let problems: [StoreProblem]
}

/// Stores `Value`s as `<id>.json` envelopes in `directory`. Writes go to a hidden temporary file in the same folder and
/// then replace the target, so readers see either the old or the new complete file. Loading never modifies, moves or
/// deletes a document file.
public struct DocumentStore<Value: Codable & Sendable>: Sendable {
    /// Folder holding the documents (created on first use).
    public let directory: URL
    /// Kind written into and required from every envelope.
    public let kind: String
    /// Migrations up to the version this build writes.
    public let migrations: MigrationChain
    /// Largest file accepted, in bytes.
    public let maxBytes: Int
    /// Test hook: called after the temporary file is written and before it replaces the target.
    var beforeReplace: (@Sendable () throws -> Void)?

    /// A store of `kind` documents in `directory`.
    public init(directory: URL, kind: String, migrations: MigrationChain, maxBytes: Int = 256 * 1024) {
        self.directory = directory
        self.kind = kind
        self.migrations = migrations
        self.maxBytes = maxBytes
    }

    private static func isValidID(_ id: String) -> Bool {
        !id.hasPrefix(".") && id.range(of: #"^[A-Za-z0-9._-]{1,128}$"#, options: .regularExpression) != nil
    }

    private func url(_ id: String) -> URL { directory.appendingPathComponent(id + ".json") }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Writes `value` as `<id>.json` atomically, at the current schema version.
    public func save(_ value: Value, id: String, now: Date = Date()) throws(StoreProblem) {
        guard Self.isValidID(id) else { throw .invalidID(id) }
        let data: Data
        do {
            let payload = try JSONSerialization.jsonObject(with: Self.encoder().encode(value))
            let envelope: [String: Any] = ["kind": kind, "schemaVersion": migrations.currentVersion,
                                           "savedAt": ISO8601DateFormatter().string(from: now), "payload": payload]
            data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        } catch { throw .writeFailed("encoding: \(error)") }
        guard data.count <= maxBytes else { throw .writeFailed("document is \(data.count) bytes; limit \(maxBytes)") }
        let fm = FileManager.default
        let temp = directory.appendingPathComponent(".\(id).tmp-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: temp)
            try beforeReplace?()
            if fm.fileExists(atPath: url(id).path) {
                _ = try fm.replaceItemAt(url(id), withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: url(id))
            }
        } catch {
            try? fm.removeItem(at: temp)
            throw .writeFailed("\(error)")
        }
    }

    /// Whether `<id>.json` exists.
    public func exists(id: String) -> Bool { Self.isValidID(id) && FileManager.default.fileExists(atPath: url(id).path) }

    /// Deletes `<id>.json`.
    public func delete(id: String) throws(StoreProblem) {
        guard Self.isValidID(id) else { throw .invalidID(id) }
        guard exists(id: id) else { throw .notFound(id: id) }
        do { try FileManager.default.removeItem(at: url(id)) } catch { throw .writeFailed("\(error)") }
    }

    /// Reads one document.
    public func load(id: String) throws(StoreProblem) -> StoredItem<Value> {
        guard Self.isValidID(id) else { throw .invalidID(id) }
        guard exists(id: id) else { throw .notFound(id: id) }
        return try read(url(id))
    }

    /// Reads every `*.json` document; leftover temporary files from interrupted writes are removed first.
    public func load() -> LoadReport<Value> {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return LoadReport(items: [], problems: []) }
        for name in names where name.hasPrefix(".") && name.contains(".tmp-") {
            try? fm.removeItem(at: directory.appendingPathComponent(name))
        }
        var items: [StoredItem<Value>] = []
        var problems: [StoreProblem] = []
        for name in names.sorted() where name.hasSuffix(".json") && !name.hasPrefix(".") {
            do { items.append(try read(directory.appendingPathComponent(name))) } catch { problems.append(error) }
        }
        return LoadReport(items: items, problems: problems)
    }

    private func read(_ file: URL) throws(StoreProblem) -> StoredItem<Value> {
        let name = file.lastPathComponent
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        guard size <= maxBytes else { throw .tooLarge(file: name, bytes: size) }
        guard let data = try? Data(contentsOf: file),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foundKind = object["kind"] as? String, let version = object["schemaVersion"] as? Int,
              let savedText = object["savedAt"] as? String, let savedAt = ISO8601DateFormatter().date(from: savedText),
              let payload = object["payload"] as? [String: Any]
        else { throw .corrupt(file: name, reason: "not a document envelope") }
        guard foundKind == kind else { throw .wrongKind(file: name, found: foundKind) }
        guard version <= migrations.currentVersion else { throw .newerVersion(file: name, version: version) }
        do {
            let migrated = try migrations.migrate(payload, from: version)
            let value = try Self.decoder().decode(Value.self, from: JSONSerialization.data(withJSONObject: migrated))
            return StoredItem(id: String(name.dropLast(5)), value: value, savedAt: savedAt,
                              migratedFrom: version < migrations.currentVersion ? version : nil)
        } catch {
            throw .corrupt(file: name, reason: "\(error)")
        }
    }
}
