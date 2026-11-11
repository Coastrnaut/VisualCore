# Contract: PlaneFraming, NamedLibrary and the bookmark UI

## VisualCoreMath.PlaneFraming (public)

- `init(center: Vec2, span: Double)`; `init(_ viewport: PlaneViewport)`; `func viewport(size: Vec2) -> PlaneViewport`;
  `center`, `span`; Codable, Sendable, Equatable.
- Tests (≥ 6): round trip bit-exact center and 1e-12 span over 100 random views × 5 sizes; portrait ↔ landscape keeps
  center and span; square pixels; invalid center/span fallbacks; Codable round trip; a viewport whose
  unitsPerPoint clamps reports the clamped span.

## VisualCorePersistence.NamedLibrary<Payload> (public)

- `struct Entry: Codable, Equatable, Sendable, Identifiable`; `init(directory:kind:schemaVersion:migrations:validate:)`;
  `static func defaultDirectory(named:) -> URL`; `static func normalizedName(_:) -> String`; `maxNameLength`;
  `entries`, `problems`; `reload()`, `entry(_:)`, `save(_:name:id:now:)`, `rename(_:to:now:)`,
  `setFavorite(_:_:)`, `duplicate(_:now:)`, `delete(_:)`.
- Tests (≥ 8): save/reload equality; names normalized; ordering; rename bumps modified; favorite; duplicate gets a new
  id and " copy"; delete; damaged and newer-version files reported and left in place; validation failure reported
  as corrupt; update in place keeps createdAt.

## App UI identifiers

`fe.bookmarks` (button), `fe.bookmarks.list`, `fe.bookmark.save`, `fe.bookmark.name` (alert field),
`fe.bookmark.row.<n>` rows (label: name, center, zoom, level), `fe.bookmark.note`, `fe.goto`, `fe.goto.real`,
`fe.goto.imaginary`, `fe.goto.zoom`, `fe.goto.go`, `fe.goto.error`.
