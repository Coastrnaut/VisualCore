# Research: Fractal Explorer — Phase 03 Navigation and bookmarks

## R1 — Size-independent framing (G-FRAMING)

- **Decision**: `PlaneFraming { center: Vec2, span: Double }` where span is the plane length across the canvas's
  shorter side. `init(_ viewport:)` reads span = unitsPerPoint × min(size); `viewport(size:)` returns
  `PlaneViewport(center:, unitsPerPoint: span / min(size), size:)`. Validation: non-finite center → (0, 0);
  non-finite or non-positive span → the default 1. Codable.
- **Rationale**: the explorer's default views are defined by the shorter-side width; this keeps the center bit-exact
  and pixels square on any shape. Generic for A16, A22 and any 2D plane app.
- **Alternatives**: store unitsPerPoint (shape-dependent, fails US2 AC2); store a rectangle (distorts on aspect
  change).

## R2 — Generic named library (G-LIBRARY)

- **Decision**: `NamedLibrary<Payload: Codable & Sendable & Equatable>` with `Entry { id: UUID, name, favorite,
  createdAt, modifiedAt, payload }`, `init(directory:kind:schemaVersion:migrations:validate:)`, `reload()`,
  `entry(_:)`, `save(_:name:id:now:)`, `rename`, `setFavorite`, `duplicate(_:now:)`, `delete`, `entries`,
  `problems`, `normalizedName`, `maxNameLength` 60. Ordering as A01.
- **Rationale**: the A01 pattern is product-neutral; A03 needs the same; later apps (Shader Studio, Effects Composer,
  Tiny Worlds) also save named documents.
- **Alternatives**: copy A01's code into A03 (duplication, rejected by the owner rule); change A01 now (out of scope,
  raises regression risk mid-phase).

## R3 — Precision mode content

- **Decision**: `PrecisionMode { format: "gpu-float32", mantissaBits: Int, level: "reliable" | "nearLimit" |
  "beyondLimit" }` stored as strings and ints; level comes from `PrecisionAdvisor.assess` at save time.
- **Rationale**: says honestly what the saved view needed and had; avoids encoding enum internals.

## R4 — Go to parsing

- **Decision**: trim; accept "." and the current locale's decimal separator; accept a leading "−" (U+2212) as minus;
  `Double` parsing; ranges |x|, |y| ≤ 4, zoom in (0, 1e15]. Errors: "Enter a number", "Use a value between −4 and 4",
  "Zoom must be above 0 and at most 1e15".
- **Rationale**: matches the spoken description's minus sign and typical sources.

## R5 — GPU aspect fixture

- **Decision**: render the default Mandelbrot at 64×32 and 32×64 offscreen with the framing-derived viewport and
  compare escape classes against `FractalMath` at the same pixel centers (≥ 99%, boundary-only).
- **Rationale**: distortion would move classes away from the CPU reference, so agreement proves square pixels and the
  kept center in the shader path.
