# Data Model: Fractal Explorer — Phase 03

## PlaneFraming (VisualCoreMath, Codable)

| Field | Type | Rule |
|---|---|---|
| center | Vec2 | finite, else (0, 0) |
| span | Double | finite and > 0, else 1; plane length across the shorter side |

`viewport(size:)` → `PlaneViewport` with unitsPerPoint = span / min(size.x, size.y) (PlaneViewport clamps apply).

## NamedLibrary<Payload>.Entry (VisualCorePersistence, stored payload)

| Field | Type | Rule |
|---|---|---|
| id | UUID | identity and file id |
| name | String | trimmed, ≤ 60, "Untitled" when empty |
| favorite | Bool | listed first |
| createdAt, modifiedAt | Date | whole seconds |
| payload | Payload | validated by the caller on load and save |

Ordering: favorite desc, modifiedAt desc, name (localized standard).

## Bookmark (FractalExplorerCore, payload; kind `dev.visualcore.fe.bookmark`, schema 1)

| Field | Type | Rule |
|---|---|---|
| mode | "mandelbrot" \| "julia" | FractalMode raw value |
| framing | PlaneFraming | |x|,|y| ≤ 4 for center; span finite > 0 |
| juliaSeed | Vec2 | finite |
| iterationCap | Int | 1…10,000 |
| escapeRadius | Double | ≥ 2, finite |
| paletteID | String | one of sunset, ocean, forest, neon, ember |
| precision | PrecisionMode | below |

## PrecisionMode

| Field | Type | Rule |
|---|---|---|
| format | String | "gpu-float32" |
| mantissaBits | Int | 1…64 |
| level | "reliable" \| "nearLimit" \| "beyondLimit" | at save time |

## GoToInput

real, imaginary, zoom strings → `Result<(center: Vec2, zoom: Double), GoToError>`; span = default width ÷ zoom.

## State transitions

- Open bookmark → state restored → `apply` (clamp) → note iff the span grew.
- Any later apply → note cleared.
