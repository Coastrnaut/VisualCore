# Contract: Phase 03 API and UI

```swift
// VisualCorePersistence
public struct DocumentEnvelope: Sendable { public let kind: String; public let schemaVersion: Int; public let savedAt: Date }
public struct MigrationChain: Sendable {
  public init(currentVersion: Int, steps: [Int: @Sendable ([String: Any]) throws -> [String: Any]] = [:])
  public let currentVersion: Int
  public func migrate(_ payload: [String: Any], from version: Int) throws -> [String: Any]
}
public enum StoreProblem: Error, Equatable, Sendable { case corrupt(file: String, reason: String), wrongKind(file: String, found: String),
  newerVersion(file: String, version: Int), tooLarge(file: String, bytes: Int), notFound(id: String), writeFailed(String) }
public struct StoredItem<Value: Sendable>: Sendable { public let id: String; public let value: Value; public let savedAt: Date; public let migratedFrom: Int? }
public struct LoadReport<Value: Sendable>: Sendable { public let items: [StoredItem<Value>]; public let problems: [StoreProblem] }
public struct DocumentStore<Value: Codable & Sendable>: Sendable {
  public init(directory: URL, kind: String, migrations: MigrationChain, maxBytes: Int = 256 * 1024)
  public func save(_ value: Value, id: String) throws(StoreProblem)
  public func load() -> LoadReport<Value>; public func load(id: String) throws(StoreProblem) -> StoredItem<Value>
  public func delete(id: String) throws(StoreProblem); public func exists(id: String) -> Bool
}
```

App UI identifiers (as shipped):
- `gas.library.open` (gallery toolbar), `gas.library`, rows `gas.library.row.<uuid>`, `gas.library.problems`,
  `gas.library.empty`;
- per-row star `gas.library.favorite.<uuid>` and actions menu `gas.library.more.<uuid>`;
- menu items `gas.library.duplicate`, `gas.library.rename` and `gas.library.delete`;
- the rename alert `gas.library.renameField`/`gas.library.renameConfirm`;
- the delete alert `gas.library.confirmDelete`/`gas.library.cancelDelete`. An alert was used instead of a
  confirmation dialog because it presents the same way, with an explicit Cancel, on every iOS 26/27 device.
- Scene: `gas.save` (toolbar; label "Save", or "Save changes" when editing a saved entry), the name alert
  `gas.save.name`/`gas.save.confirm`, and the failure alert `gas.save.error`.

SwiftUI alert text fields and buttons are found through `app.alerts`, since identifiers are not always exposed there.
