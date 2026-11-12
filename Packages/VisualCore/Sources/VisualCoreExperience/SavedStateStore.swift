// SavedStateStore — feature 191 T-U05-005 (UA-F05; FR-U05-012, FR-U05-013, FR-U05-015, FR-U05-030, FR-U05-032;
// research R2; data-model section 3; contract specs/191-ua-f05-session-persistence/contracts/persistence-api.md).
// The saved state of each experience: one `state.json` in the experience's namespace folder, holding the text of
// `ExperienceSnapshot.encoded()`. Reading never changes a file and never stops the process: every file gives a
// snapshot or a problem with a stable code. Writing is atomic, and a file that cannot be read is never written
// over: it is moved aside first, and at most three such copies are kept.
import Foundation

/// Why a saved state cannot be used: a stable code, and whether a newer build wrote the state.
public struct SavedStateProblem: Sendable, Equatable {
    /// The code of a state file that exists but cannot be read from the disk.
    public static let unreadableFileCode = "state.unreadable-file"
    /// The code of a state written by a newer schema version of the experience.
    public static let newerSchemaCode = "snapshot.newer-schema"

    /// The stable code: a `SnapshotError` code or `state.unreadable-file`.
    public let code: String
    /// Whether the state was written by a newer build; true exactly for the code `snapshot.newer-schema`.
    public let newer: Bool

    /// The problem of a snapshot that was refused with `error`.
    public init(error: SnapshotError) {
        self.init(failureCode: error.code)
    }

    /// The problem of a session that failed in its restore stage with this failure code.
    public init(failureCode: String) {
        self.init(code: failureCode, newer: failureCode == Self.newerSchemaCode)
    }

    /// A problem from its two parts.
    public init(code: String, newer: Bool) {
        self.code = code
        self.newer = newer
    }
}

/// What `SavedStateStore.load` found for one experience.
public enum SavedStateLoad: Sendable, Equatable {
    /// No state is stored.
    case none
    /// A complete, valid state of the experience.
    case state(ExperienceSnapshot)
    /// A state file exists but cannot be used; the file is untouched.
    case unreadable(SavedStateProblem)
}

/// The saved states of the experiences under one root folder: `<root>/<namespace>/state.json`.
///
/// `load` never creates, changes, moves or removes anything. `save` writes to a hidden temporary file in the same
/// folder and then replaces the target, so a reader sees the earlier or the new complete state, never a part.
public struct SavedStateStore: Sendable {
    /// The name of the state file inside an experience's folder.
    public static let stateFileName = "state.json"
    /// The largest number of quarantined copies kept per experience.
    public static let maxQuarantined = 3
    /// The start of the name of a quarantined copy: `quarantine-<n>.json`.
    public static let quarantinePrefix = "quarantine-"

    /// The end of the name of a quarantined copy.
    private static let quarantineSuffix = ".json"
    /// The part every hidden temporary file name contains.
    private static let temporaryMarker = ".tmp-"

    /// The folder that holds the namespace folders of the experiences.
    public let root: URL
    /// Test seam: called after the temporary file is complete and before it replaces the state file.
    var beforeReplace: (@Sendable () throws -> Void)?
    /// Test seam: when `beforeReplace` throws, leave the temporary file, as a process that ended there would.
    var leaveTemporaryFileOnFailure = false

    /// A store under `root`. Nothing is created.
    public init(root: URL) {
        self.root = root
    }

    /// The folder of everything the experience stores: `<root>/<storage namespace>`.
    public func folder(for id: ExperienceID) -> URL {
        root.appendingPathComponent(id.storageNamespace, isDirectory: true)
    }

    /// The state file of the experience.
    public func stateURL(for id: ExperienceID) -> URL {
        folder(for: id).appendingPathComponent(Self.stateFileName, isDirectory: false)
    }

    /// Reads the saved state of the experience without changing anything.
    ///
    /// `.none` without a state file. `.unreadable` when the file is larger than `ExperienceSnapshot.maxBytes` (it is
    /// then not read at all), cannot be read, is not a valid snapshot, or belongs to another experience.
    public func load(_ id: ExperienceID) -> SavedStateLoad {
        let file = stateURL(for: id)
        let manager = FileManager.default
        guard manager.fileExists(atPath: file.path) else { return .none }
        guard let attributes = try? manager.attributesOfItem(atPath: file.path),
              let size = (attributes[.size] as? NSNumber)?.intValue else {
            return .unreadable(SavedStateProblem(failureCode: SavedStateProblem.unreadableFileCode))
        }
        guard size <= ExperienceSnapshot.maxBytes else {
            return .unreadable(SavedStateProblem(error: .tooLarge(bytes: size)))
        }
        guard let data = try? Data(contentsOf: file) else {
            return .unreadable(SavedStateProblem(failureCode: SavedStateProblem.unreadableFileCode))
        }
        let snapshot: ExperienceSnapshot
        do {
            snapshot = try ExperienceSnapshot(data: data)
        } catch {
            return .unreadable(SavedStateProblem(error: error))
        }
        guard snapshot.experience == id else {
            return .unreadable(SavedStateProblem(error: .wrongExperience(found: snapshot.experience.rawValue)))
        }
        return .state(snapshot)
    }

    /// Stores the snapshot as the state of its experience.
    ///
    /// Returns false and writes nothing when the stored bytes already equal the snapshot's encoded text; otherwise
    /// writes atomically and returns true. A stored file that `load` calls unreadable is quarantined first and never
    /// written over. Throws `StorageError.writeFailed` when the snapshot cannot be encoded or the write fails; the
    /// earlier state is then still complete.
    @discardableResult
    public func save(_ snapshot: ExperienceSnapshot) throws(StorageError) -> Bool {
        let text: Data
        do {
            text = try snapshot.encoded()
        } catch {
            throw .writeFailed(error.code)
        }
        let id = snapshot.experience
        let directory = folder(for: id)
        let target = stateURL(for: id)
        let manager = FileManager.default
        if manager.fileExists(atPath: target.path) {
            // The stored file is read for the comparison only when it has the size of the new text, so a
            // file above the limit is never read here.
            let size = (try? manager.attributesOfItem(atPath: target.path))?[.size] as? Int
            if size == text.count, let stored = try? Data(contentsOf: target), stored == text { return false }
            if case .unreadable = load(id) { try quarantine(id) }
        }
        let temporary = directory.appendingPathComponent(".\(Self.stateFileName)\(Self.temporaryMarker)\(UUID().uuidString)",
                                                         isDirectory: false)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try text.write(to: temporary)
        } catch {
            try? manager.removeItem(at: temporary)
            throw .writeFailed("\(error)")
        }
        if let beforeReplace {
            do {
                try beforeReplace()
            } catch {
                if !leaveTemporaryFileOnFailure { try? manager.removeItem(at: temporary) }
                throw .writeFailed("\(error)")
            }
        }
        do {
            if manager.fileExists(atPath: target.path) {
                _ = try manager.replaceItemAt(target, withItemAt: temporary)
            } else {
                try manager.moveItem(at: temporary, to: target)
            }
        } catch {
            try? manager.removeItem(at: temporary)
            throw .writeFailed("\(error)")
        }
        return true
    }

    /// Moves the state file of the experience aside as `quarantine-<n>.json` and returns that name.
    ///
    /// `n` is the highest existing number plus one, starting at 1. Afterwards the copies with the lowest numbers
    /// are removed until at most `maxQuarantined` remain. Returns nil when no state file exists. Throws
    /// `StorageError.writeFailed` when the file cannot be moved.
    @discardableResult
    public func quarantine(_ id: ExperienceID) throws(StorageError) -> String? {
        let source = stateURL(for: id)
        let manager = FileManager.default
        guard manager.fileExists(atPath: source.path) else { return nil }
        let directory = folder(for: id)
        let existing = quarantineNumbers(id)
        let highest = existing.last ?? 0
        guard highest < Int.max else { throw .writeFailed("no quarantine number is left") }
        let number = highest + 1
        let name = Self.quarantineName(number)
        do {
            try manager.moveItem(at: source, to: directory.appendingPathComponent(name, isDirectory: false))
        } catch {
            throw .writeFailed("\(error)")
        }
        let all = existing + [number]
        let surplus = all.count - Self.maxQuarantined
        if surplus > 0 {
            for old in all.prefix(surplus) {
                do {
                    try manager.removeItem(at: directory.appendingPathComponent(Self.quarantineName(old), isDirectory: false))
                } catch {
                    throw .writeFailed("\(error)")
                }
            }
        }
        return name
    }

    /// The names of the quarantined copies of the experience, by rising number.
    public func quarantined(_ id: ExperienceID) -> [String] {
        quarantineNumbers(id).map(Self.quarantineName)
    }

    /// Removes the hidden temporary files that interrupted writes left in the namespace folders.
    ///
    /// In every folder directly under the root, every regular file whose name starts with a dot and contains
    /// `.tmp-` is removed. Returns the number of files removed; 0 when the root does not exist.
    @discardableResult
    public func removeLeftovers() -> Int {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(atPath: root.path) else { return 0 }
        var removed = 0
        for folderName in folders {
            let directory = root.appendingPathComponent(folderName, isDirectory: true)
            guard Self.fileType(directory) == .typeDirectory,
                  let names = try? manager.contentsOfDirectory(atPath: directory.path) else { continue }
            for name in names where name.hasPrefix(".") && name.contains(Self.temporaryMarker) {
                let file = directory.appendingPathComponent(name, isDirectory: false)
                guard Self.fileType(file) == .typeRegular else { continue }
                if (try? manager.removeItem(at: file)) != nil { removed += 1 }
            }
        }
        return removed
    }

    /// Removes the state file of the experience and nothing else. No error when it does not exist.
    public func remove(_ id: ExperienceID) throws(StorageError) {
        let file = stateURL(for: id)
        let manager = FileManager.default
        guard manager.fileExists(atPath: file.path) else { return }
        do {
            try manager.removeItem(at: file)
        } catch {
            throw .writeFailed("\(error)")
        }
    }

    /// The numbers of the quarantined copies of the experience, rising.
    private func quarantineNumbers(_ id: ExperienceID) -> [Int] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder(for: id).path) else { return [] }
        return names.compactMap(Self.quarantineNumber).sorted()
    }

    /// The name of the quarantined copy with this number.
    private static func quarantineName(_ number: Int) -> String {
        quarantinePrefix + String(number) + quarantineSuffix
    }

    /// The number in a name of the exact form `quarantine-<n>.json` with n of 1 and above; nil for any other name.
    private static func quarantineNumber(_ name: String) -> Int? {
        guard name.hasPrefix(quarantinePrefix), name.hasSuffix(quarantineSuffix),
              name.utf8.count > quarantinePrefix.utf8.count + quarantineSuffix.utf8.count else { return nil }
        let digits = String(name.dropFirst(quarantinePrefix.count).dropLast(quarantineSuffix.count))
        guard digits.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(digits), number >= 1,
              String(number) == digits else { return nil }
        return number
    }

    /// The type of the item at `url` itself (a symbolic link is not followed); nil when it cannot be read.
    private static func fileType(_ url: URL) -> FileAttributeType? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.type] as? FileAttributeType
    }
}
