# Contract: public API of VisualCoreExperience (UA-F01)

Module `VisualCoreExperience` in `Packages/VisualCore`; imports Foundation only. Every symbol below is `public`,
documented with `///`, `Sendable` and, unless noted, `Equatable`. Names are final once the API baseline records
them.

| Symbol | Shape | Requirement |
|---|---|---|
| `ExperienceInfo.version` | `"1.0.0-rc.1"` | module convention |
| `ExperienceCode` | struct, `Hashable`, `Comparable`, `CustomStringConvertible`; `init(_ text: String) throws(ExperienceIDError)`; `text`; `isOriginal`; `round: Int?`; `number: Int`; `integrationGate: String` | FR-U01-001, FR-U01-005 |
| `ExperienceID` | struct, `Hashable`, `Comparable`, `RawRepresentable` (`rawValue: String`), `Codable` as a string, `CustomStringConvertible`; `init(_ text: String) throws(ExperienceIDError)`; `init?(rawValue:)`; `code`; `slug`; `storageNamespace`; `accessibilityPrefix`; `evidenceName`; `integrationGate` | FR-U01-001, FR-U01-002, FR-U01-005 |
| `ExperienceIDError` | enum: `malformed(text: String, reason: String)` | FR-U01-002 |
| `ExperienceTier` | enum `free`, `premium`; `String` raw values | FR-U01-010 |
| `ExperienceKind` | enum `creative`, `game` | FR-U01-020 |
| `ExperienceCategory` | enum `create`, `audio`, `play`, `learn`, `ambient`, `tools`, `puzzle`; `CaseIterable` in launcher order | FR-U01-020 |
| `ExperienceContent` | struct: `levels: Int`, `catalogSHA256: String` | FR-U01-033, FR-U01-034 |
| `ExperienceDescriptor` | struct with `id`, `title`, `summary`, `kind`, `tier`, `category`, `family`, `tags`, `order`, `palette`, `tileSeed: UInt32`, `capabilities`, `qualityTiers`, `content: ExperienceContent?`, `isAvailable`; `code` is `id.code` | FR-U01-010, FR-U01-020, FR-U01-021 |
| `CatalogError` | enum of data-model.md section 8, `Error` | FR-U01-030 to FR-U01-035 |
| `CatalogManifest` | struct: `schemaVersion`, `catalogSHA256`, `experiences` (catalog order); `static let supportedSchema = 1`, `maxBytes = 1_048_576`, `maxEntries = 400`; `init(data: Data, categories: CategoryList? = nil) throws(CatalogError)`; `experience(_ id: ExperienceID) -> ExperienceDescriptor?`; `experience(code:)`; `experiences(in: ExperienceCategory)`; `available`; `families(in:)`; `search(_ text: String) -> [ExperienceDescriptor]`; `registryReport(registered: [ExperienceID]) -> RegistryReport` | FR-U01-003, FR-U01-011 to FR-U01-013, FR-U01-023, FR-U01-024, FR-U01-030 to FR-U01-036, FR-U01-050, FR-U01-051 |
| `CategoryList` | struct: `categories: [Entry]` with `id: ExperienceCategory`, `title: String`; `init(data: Data) throws(CatalogError)`; `title(of:)` | FR-U01-022 |
| `CatalogSearch.fold(_:)` | `static func fold(_ text: String) -> String` | FR-U01-023, FR-U01-024 |
| `RegistryReport` | struct: `missingRegistrations`, `unexpectedRegistrations`, `duplicates` (each `[ExperienceID]`, sorted), `isMatch` | FR-U01-050 |
| `SourceMoveMap` | struct: `moves: [Move]` with `from`, `to`, `gate`, `commit`; `init(data: Data) throws(CatalogError)` | FR-U01-046 |

Public symbols added while building, each needed outside the module:

| Symbol | Why it is public |
|---|---|
| `CatalogManifest.launchCodes` | the 100 launch codes in catalog order; the app shell and its tests compare against the rule instead of copying it |
| `ExperienceDescriptor.tag(forFamily:)` | the one definition of the tag form; the launcher groups puzzles by family with it |
| `ExperienceID.maxSlugLength`, `SourceMoveMap.maxMoves` | the limits as values, for callers that validate before building data |
| `RegistryReport.init(missingRegistrations:unexpectedRegistrations:duplicates:)`, `SourceMoveMap.Move.init(from:to:gate:commit:)`, `ExperienceContent.init(levels:catalogSHA256:)` | value types that tests of other modules construct for comparison |

`ExperienceDescriptor` has no public initializer: a descriptor only comes out of a validated manifest.

Behavior that the tests pin:

- `ExperienceID(text).rawValue == text` for every valid text; an invalid text throws `malformed` with a reason.
- `CatalogManifest(data:)` either returns a fully validated value or throws exactly one `CatalogError`; the order
  of checks is the one of data-model.md section 3, so a file with several defects reports the first.
- No function reads the clock, the locale, the file system or the network.
- `search("")` returns all entries in catalog order; `search` is a pure function of the manifest and the text.
