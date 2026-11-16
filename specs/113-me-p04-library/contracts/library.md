# Contract: Molecular Explorer recent list and settings (feature 113)

```swift
public struct RecentMolecules: Equatable, Sendable {
    public static let schemaVersion = 1, cap = 8, maxBytes = 2_048, fileName = "recent.json"
    public private(set) var ids: [String]
    public mutating func record(_ id: String)            // to the front, unique, capped
    public func encoded() -> Data
    public static func decode(_ data: Data, known: Set<String>) -> Result<RecentMolecules, DocumentRefusal>
}
public enum LabelMode: String, Codable, CaseIterable, Sendable { case all, selected, none }
public struct MoleculeSettings: Equatable, Sendable {
    public static let schemaVersion = 1, maxBytes = 1_024, fileName = "settings.json"
    public var labels: LabelMode
    public func encoded() -> Data
    public static func decode(_ data: Data) -> Result<MoleculeSettings, DocumentRefusal>
}
public enum DocumentRefusal: String, Error, Sendable { case damaged, oversized, newerVersion = "newer-version", outOfRange = "out-of-range" }
```

Out-of-range means: more than 8 ids, a duplicate, an id that is empty, longer than 32 characters or not lowercase
letters, digits and hyphens, an unknown label mode, or a schema version below 1. `LabelMode.selected` with no atom
selected shows no label.


Experience: `RecentStore`, `SettingsStore` over `ExperienceStorage?`; controls identifiers `library-<id>`, `recent`,
`labels`.
