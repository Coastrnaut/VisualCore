# Data model: A01-P03

## VisualCorePersistence (Foundation only, public)
- `DocumentEnvelope` holds `kind`, `schemaVersion`, `savedAt` (Date, ISO 8601) and `payload` (JSON object).
- `MigrationChain` holds `currentVersion: Int` and a step per version (`[Int: ([String: Any]) throws -> [String: Any]]`,
  as an `@Sendable` closure), and provides `migrate(_ payload:, from version:) throws -> payload at currentVersion`.
- `DocumentStore<Value: Codable & Sendable>`:
  - fields: `directory: URL`, `kind: String`, `migrations: MigrationChain`, `maxBytes` (default 256 KiB);
  - `save(_ value:, id: String) throws`: atomic; `id` matches `^[A-Za-z0-9._-]{1,128}$`;
  - `load() -> LoadReport<Value>` and `load(id:) throws(StoreProblem) -> Value`;
  - `delete(id:) throws`, `exists(id:)`.
- `LoadReport<Value>` holds `items: [(id: String, value: Value, savedAt: Date, migratedFrom: Int?)]` and
  `problems: [StoreProblem]`.
- `StoreProblem` (Error, Equatable) is one of `.corrupt(file, reason)`, `.wrongKind(file, found)`,
  `.newerVersion(file, Int)`, `.tooLarge(file, bytes)`, `.notFound(id)` or `.writeFailed(reason)`.

## GenerativeArtStudioCore
- `LibraryEntry` (Codable, schema 1) holds `id: UUID`, `name` (1…60 characters after normalization), `favorite`,
  `createdAt`, `modifiedAt` and `document: ArtDocument` (validated on load).
- `CompositionLibrary` wraps `DocumentStore<LibraryEntry>` with kind `dev.visualcore.gas.composition` and version 1:
  - `entries` (ordered), `problems`, `reload()`;
  - `save(document:, name:, id: UUID?) -> LibraryEntry` (update in place when `id` exists);
  - `duplicate(id)`, `rename(id, to:)`, `setFavorite(id, Bool)`, `delete(id)`;
  - `static normalizedName(_:)`.
