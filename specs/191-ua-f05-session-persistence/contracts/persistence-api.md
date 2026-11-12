# Contract: storage and saved-state API (UA-F05)

Names marked (new) are created by this feature; everything else exists and was verified in research.md.

## VisualCoreExperience (pure, Foundation only)

```swift
public enum StorageQuota {                                            // (new)
    public static let maxBytes: Int        // 16 MiB
    public static let maxFiles: Int        // 64
    public static let maxValues: Int       // 64
    public static let maxValueBytes: Int   // 4,096
    public static let maxNameLength: Int   // 128
}
public enum StorageError: Error, Sendable, Equatable {                // (new)
    case invalidName(String), reservedName(String), quotaExceeded(String)
    case notFound(String), writeFailed(String), tooLarge(Int)
    public var code: String { get }
}
public struct ExperienceStorage: @unchecked Sendable {                // (new) the handle of one experience
    public let id: ExperienceID
    public init(id: ExperienceID, root: URL, defaults: UserDefaults)
    public static func isValidName(_ name: String) -> Bool
    public static func isReservedName(_ name: String) -> Bool
    public static func defaultsPrefix(for id: ExperienceID) -> String          // "exp.<id>."
    public func write(_ data: Data, to name: String) throws(StorageError)
    public func read(_ name: String) throws(StorageError) -> Data
    public func exists(_ name: String) -> Bool
    public func list() -> [String]
    public func remove(_ name: String) throws(StorageError)
    public func setValue(_ data: Data, for key: String) throws(StorageError)
    public func value(for key: String) -> Data?
    public func valueKeys() -> [String]
    public func removeValue(for key: String)
    public static func removeValues(of id: ExperienceID, in defaults: UserDefaults) -> [String]
    public static func removeAllValues(in defaults: UserDefaults) -> [String]
}
public struct SavedStateProblem: Sendable, Equatable {                // (new)
    public let code: String
    public let newer: Bool
    public init(error: SnapshotError)
    public init(failureCode: String)
}
public enum SavedStateLoad: Sendable, Equatable {                     // (new)
    case none, state(ExperienceSnapshot), unreadable(SavedStateProblem)
}
public struct SavedStateStore: Sendable {                             // (new)
    public static let stateFileName: String          // "state.json"
    public static let maxQuarantined: Int            // 3
    public init(root: URL)
    public func load(_ id: ExperienceID) -> SavedStateLoad
    @discardableResult public func save(_ snapshot: ExperienceSnapshot) throws(StorageError) -> Bool
    @discardableResult public func quarantine(_ id: ExperienceID) throws(StorageError) -> String?
    public func quarantined(_ id: ExperienceID) -> [String]
    @discardableResult public func removeLeftovers() -> Int
    public func remove(_ id: ExperienceID) throws(StorageError)
}
public struct MigrationExample: Sendable, Equatable {                 // (new)
    public let version: Int
    public let snapshot: Data
    public let expectedDigest: String
    public init(version: Int, snapshot: Data, expectedDigest: String)
}
public enum SnapshotMigrationCheck {                                  // (new)
    public static func problems<Core: ExperienceCore>(for core: Core.Type, id: ExperienceID,
                                                      examples: [MigrationExample]) async -> [String]
}
public struct InventoryRule: Sendable, Equatable {                    // (new)
    public enum Kind: String, Sendable { case file, key }
    public init(kind: Kind, pattern: String, writer: String, system: Bool = false, origin: String? = nil)
}
public enum InventoryError: Error, Sendable, Equatable {              // (new)
    case invalidPattern(String), systemRuleWithoutOrigin(String)
}
public struct ContainerInventory: Sendable {                          // (new)
    public init(rules: [InventoryRule]) throws(InventoryError)
    public func unlisted(files: [String], keys: [String]) -> [String]
}
extension ShellPreferences {
    public static let unreadableCopyKey: String      // (new) "vc.shell.preferences.unreadable"
    public static var migratedVersions: [Int] { get } // (new) the earlier schema versions a migration exists for
}
```

## VisualCoreExperienceHost (main actor)

```swift
public struct ExperienceOpenRequest {                                 // existing
    public var refusedSnapshotFails: Bool                             // (new) default false
}
extension ExperienceSession {
    public func checkpoint()                                          // (new)
}
```

## Behaviour contracts

1. Every operation of `ExperienceStorage` stays inside `<root>/<id>/` and the prefix `exp.<id>.`; a name that is
   invalid or reserved is refused before anything is touched. Path separators, `..`, absolute paths, an empty
   name, a name of 129 characters and a leading dot are invalid names.
2. A write replaces a file atomically; an interrupted write leaves the earlier file and at most one hidden
   temporary file, which `SavedStateStore.removeLeftovers()` removes.
3. `SavedStateStore.load` never changes a file. `save` never writes over a file `load` calls unreadable: it
   quarantines it first.
4. With `refusedSnapshotFails`, a snapshot the experience refuses ends `open` with `.failed`, stage `.restore`,
   the snapshot error's code, no render host created and no sink call. Without it the behaviour of UA-F03 stays.
5. `checkpoint()` does nothing unless the session is running or suspended; it never changes the experience.
6. A sink failure never stops the session (UA-F03); the app records it.
7. Reset order: close the session (which saves), then remove folders and values.

## Tools

- `scripts/check_app_isolation.py --no-direct-storage <path> …` (new option): exit 1 with file and line when a
  source names `UserDefaults`, `FileManager`, `NSHomeDirectory`, `NSTemporaryDirectory`,
  `applicationSupportDirectory`, `documentDirectory` or `cachesDirectory`.
- `scripts/check_app_isolation.py --no-crash-on-stored-data <path> …` (new option): exit 1 with file and line
  for a forced `try`, `fatalError`, `preconditionFailure`, `precondition(`, `assertionFailure` or a forced unwrap in
  a source that reads stored data (FR-U05-071).
- `scripts/xcodebuild_app.py … --only-testing VisualCoreUITests/PersistenceUITests` issues the brief's
  `xcodebuild test -only-testing:VisualCoreUITests/PersistenceUITests` command.
