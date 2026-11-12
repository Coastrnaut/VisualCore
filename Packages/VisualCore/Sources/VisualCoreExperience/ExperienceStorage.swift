// ExperienceStorage — feature 191 T-U05-003 (UA-F05; FR-U05-001 to FR-U05-005; research R1). The storage handle of
// one experience: named files in the experience's own folder and named values under its own defaults prefix, with
// a name rule that cannot leave the namespace, fixed bounds and atomic writes. Foundation only.
import Foundation

/// The bounds of one experience's storage. The saved state and its quarantined copies do not count.
public enum StorageQuota {
    /// The most bytes all files of one experience hold together, and the largest single file: 16 MiB.
    public static let maxBytes = 16 * 1024 * 1024
    /// The most files of one experience.
    public static let maxFiles = 64
    /// The most named values of one experience.
    public static let maxValues = 64
    /// The most bytes of one named value.
    public static let maxValueBytes = 4_096
    /// The longest name of a file or of a value, in characters.
    public static let maxNameLength = 128
}

/// Why a storage operation was refused. A refused operation changes nothing.
public enum StorageError: Error, Sendable, Equatable {
    /// The name is not 1 to 128 characters of `A-Z a-z 0-9 . _ -` or starts with a dot; the text is the name.
    case invalidName(String)
    /// The name belongs to the saved state (`state.json`, `quarantine-<n>.json`); the text is the name.
    case reservedName(String)
    /// A bound of `StorageQuota` would be exceeded; the text names it: `files`, `bytes` or `values`.
    case quotaExceeded(String)
    /// There is no readable file of this name; the text is the name.
    case notFound(String)
    /// The file system refused the operation; the text describes the failure.
    case writeFailed(String)
    /// The data is larger than a single file or a single value may be; the number is its size in bytes.
    case tooLarge(Int)

    /// The stable code of the error; codes never change once released.
    public var code: String {
        switch self {
        case .invalidName: "storage.invalid-name"
        case .reservedName: "storage.reserved-name"
        case .quotaExceeded: "storage.quota-exceeded"
        case .notFound: "storage.not-found"
        case .writeFailed: "storage.write-failed"
        case .tooLarge: "storage.too-large"
        }
    }
}

/// The storage handle of one experience. Every operation stays inside the folder `<root>/<id>/` and the defaults
/// prefix `exp.<id>.`; a name that is invalid or reserved is refused before anything is touched.
///
/// The type is `@unchecked Sendable` because `UserDefaults` is safe to use from any thread but is not declared
/// `Sendable`; every other stored property is a `Sendable` value.
public struct ExperienceStorage: @unchecked Sendable {
    /// The experience this handle belongs to.
    public let id: ExperienceID
    private let root: URL
    private let defaults: UserDefaults
    /// Test seam (internal): called after the temporary file is complete and before it replaces the target. When
    /// it throws, the write fails with `StorageError.writeFailed`.
    var beforeReplace: (@Sendable () throws -> Void)?
    /// Test seam (internal): when true, a write that fails because `beforeReplace` threw leaves its temporary file
    /// in the folder, as a process that ended at that moment would. When false the temporary file is removed.
    var leaveTemporaryFileOnFailure = false

    /// A handle for `id`. `root` is the folder that holds the namespace folders (`<root>/<id>/`); `defaults` holds
    /// the named values. Nothing is created on disk here; the folder is created by the first write.
    public init(id: ExperienceID, root: URL, defaults: UserDefaults) {
        self.id = id
        self.root = root
        self.defaults = defaults
    }

    /// The namespace folder of the experience, `<root>/<id>/`. Internal: an experience is never handed the
    /// location of its folder; it reaches its files through the handle only.
    var folder: URL { root.appendingPathComponent(id.storageNamespace, isDirectory: true) }

    // MARK: Names

    /// Whether `name` may name a file or a value: 1 to 128 characters, each one of the ASCII characters
    /// `A-Z a-z 0-9 . _ -`, and not starting with a dot. Separators, spaces, control characters, look-alike
    /// letters, `.` and `..` are therefore refused.
    public static func isValidName(_ name: String) -> Bool {
        let scalars = name.unicodeScalars
        guard (1...StorageQuota.maxNameLength).contains(scalars.count) else { return false }
        guard scalars.first?.value != 46 else { return false }
        return scalars.allSatisfy { scalar in
            let v = scalar.value
            return (65...90).contains(v) || (97...122).contains(v) || (48...57).contains(v)
                || v == 46 || v == 95 || v == 45
        }
    }

    /// Whether `name` is a file name of the saved state: `state.json`, or `quarantine-<n>.json` with decimal
    /// digits for n. Such files are written by the app only and are not offered to the experience.
    public static func isReservedName(_ name: String) -> Bool {
        // Compared without regard to case: on a volume that ignores case `State.json` is the saved state.
        let name = name.lowercased()
        if name == "state.json" { return true }
        let head = "quarantine-", tail = ".json"
        guard name.hasPrefix(head), name.hasSuffix(tail), name.utf8.count > head.utf8.count + tail.utf8.count else {
            return false
        }
        let digits = name.utf8.dropFirst(head.utf8.count).dropLast(tail.utf8.count)
        return digits.allSatisfy { (48...57).contains($0) }
    }

    /// The prefix of every defaults key of the experience: `exp.<id>.`.
    public static func defaultsPrefix(for id: ExperienceID) -> String { "exp." + id.rawValue + "." }

    // MARK: Files

    /// Stores `data` as the file `name`, replacing an earlier file of that name atomically: readers see the
    /// complete earlier content or the complete new content. Creates the folder when needed.
    ///
    /// Throws `.invalidName` or `.reservedName` for a refused name, `.tooLarge` for more than
    /// `StorageQuota.maxBytes` in one file, `.quotaExceeded("files")` when the experience would hold more than
    /// `StorageQuota.maxFiles` files, `.quotaExceeded("bytes")` when its files would hold more than
    /// `StorageQuota.maxBytes` together, and `.writeFailed` when the file system refuses. Reserved and hidden
    /// files do not count. A refused write leaves what was stored intact.
    public func write(_ data: Data, to name: String) throws(StorageError) {
        try Self.checkFileName(name)
        guard data.count <= StorageQuota.maxBytes else { throw .tooLarge(data.count) }
        let entries = entries()
        let replaced = entries.first { $0.name == name }
        guard entries.count + (replaced == nil ? 1 : 0) <= StorageQuota.maxFiles else { throw .quotaExceeded("files") }
        let total = entries.reduce(0) { $0 + $1.bytes } - (replaced?.bytes ?? 0) + data.count
        guard total <= StorageQuota.maxBytes else { throw .quotaExceeded("bytes") }

        let fm = FileManager.default
        let target = folder.appendingPathComponent(name, isDirectory: false)
        if replaced == nil, fm.fileExists(atPath: target.path) {
            throw .writeFailed("\(name) exists and is not a regular file")
        }
        let temp = folder.appendingPathComponent(".\(name).tmp-\(UUID().uuidString)", isDirectory: false)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: temp)
        } catch {
            try? fm.removeItem(at: temp)
            throw .writeFailed("\(error)")
        }
        do {
            try beforeReplace?()
        } catch {
            if !leaveTemporaryFileOnFailure { try? fm.removeItem(at: temp) }
            throw .writeFailed("\(error)")
        }
        do {
            if fm.fileExists(atPath: target.path) {
                _ = try fm.replaceItemAt(target, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: target)
            }
        } catch {
            try? fm.removeItem(at: temp)
            throw .writeFailed("\(error)")
        }
    }

    /// The content of the file `name`. Throws `.invalidName` or `.reservedName` for a refused name and
    /// `.notFound` when there is no such file; a file that exists but cannot be read is reported as `.notFound`
    /// as well.
    public func read(_ name: String) throws(StorageError) -> Data {
        try Self.checkFileName(name)
        guard fileSize(name) != nil else { throw .notFound(name) }
        do {
            return try Data(contentsOf: folder.appendingPathComponent(name, isDirectory: false))
        } catch {
            throw .notFound(name)
        }
    }

    /// Whether the file `name` exists. False for an invalid or reserved name.
    public func exists(_ name: String) -> Bool {
        guard Self.isValidName(name), !Self.isReservedName(name) else { return false }
        return fileSize(name) != nil
    }

    /// The names of the experience's files, sorted. Reserved files (the saved state and its quarantined copies),
    /// hidden files (the temporary files of atomic writes) and anything that is not a regular file with a valid
    /// name are not shown. Empty when the folder does not exist.
    public func list() -> [String] { entries().map(\.name) }

    /// Removes the file `name`. Throws `.invalidName` or `.reservedName` for a refused name, `.notFound` when
    /// there is no such file and `.writeFailed` when the file system refuses.
    public func remove(_ name: String) throws(StorageError) {
        try Self.checkFileName(name)
        guard fileSize(name) != nil else { throw .notFound(name) }
        do {
            try FileManager.default.removeItem(at: folder.appendingPathComponent(name, isDirectory: false))
        } catch {
            throw .writeFailed("\(error)")
        }
    }

    // MARK: Values

    /// Stores `data` as the value `key` under the experience's defaults prefix. The key follows the name rule of
    /// files (reserved file names are allowed as keys). Throws `.invalidName` for a refused key, `.tooLarge` for
    /// more than `StorageQuota.maxValueBytes` bytes and `.quotaExceeded("values")` for a new key when the
    /// experience already holds `StorageQuota.maxValues` values. Replacing a value is always within the bound.
    public func setValue(_ data: Data, for key: String) throws(StorageError) {
        guard Self.isValidName(key) else { throw .invalidName(key) }
        guard data.count <= StorageQuota.maxValueBytes else { throw .tooLarge(data.count) }
        let keys = valueKeys()
        guard keys.contains(key) || keys.count < StorageQuota.maxValues else { throw .quotaExceeded("values") }
        defaults.set(data, forKey: Self.defaultsPrefix(for: id) + key)
    }

    /// The value `key`, or nil when there is none, when the key is invalid or when the stored object is not data.
    public func value(for key: String) -> Data? {
        guard Self.isValidName(key) else { return nil }
        return defaults.object(forKey: Self.defaultsPrefix(for: id) + key) as? Data
    }

    /// The keys of the experience's values without the prefix, sorted.
    public func valueKeys() -> [String] {
        // `dictionaryRepresentation()` also holds keys of other domains; the prefix filter selects this experience.
        let prefix = Self.defaultsPrefix(for: id)
        return defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .sorted()
    }

    /// Removes the value `key`. Does nothing without the value or for an invalid key.
    public func removeValue(for key: String) {
        guard Self.isValidName(key) else { return }
        defaults.removeObject(forKey: Self.defaultsPrefix(for: id) + key)
    }

    /// Removes every value of the experience `id` from `defaults` and returns the removed full keys, sorted.
    @discardableResult
    public static func removeValues(of id: ExperienceID, in defaults: UserDefaults) -> [String] {
        removeKeys(withPrefix: defaultsPrefix(for: id), in: defaults)
    }

    /// Removes every value of every experience (each key that starts with `exp.`) from `defaults` and returns the
    /// removed full keys, sorted. Other keys are untouched.
    @discardableResult
    public static func removeAllValues(in defaults: UserDefaults) -> [String] {
        removeKeys(withPrefix: "exp.", in: defaults)
    }

    // MARK: Private

    private static func removeKeys(withPrefix prefix: String, in defaults: UserDefaults) -> [String] {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.sorted()
        for key in keys { defaults.removeObject(forKey: key) }
        return keys
    }

    private static func checkFileName(_ name: String) throws(StorageError) {
        guard isValidName(name) else { throw .invalidName(name) }
        guard !isReservedName(name) else { throw .reservedName(name) }
    }

    /// The size of the regular file `name` in the folder, or nil when there is none. Links are not followed.
    private func fileSize(_ name: String) -> Int? {
        let url = folder.appendingPathComponent(name, isDirectory: false)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular else { return nil }
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }

    /// The experience's own files (regular, valid name, not reserved, not hidden) with their sizes, by name.
    private func entries() -> [(name: String, bytes: Int)] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        var result: [(name: String, bytes: Int)] = []
        for name in names.sorted() where Self.isValidName(name) && !Self.isReservedName(name) {
            if let bytes = fileSize(name) { result.append((name: name, bytes: bytes)) }
        }
        return result
    }
}
