# Data model: A01-P04

## VisualCore

| Entity | Module | Fields | Rules |
|---|---|---|---|
| `ExportAspect` | VisualCoreScenes | `id`, `title`, `width`, `height` (ratio integers); built-ins `square` 1:1, `portrait` 4:5, `landscape` 16:9, `story` 9:16 | ratio values > 0 |
| `ExportSize` | VisualCoreScenes | `width`, `height` (pixels) | both even, ≥ 2 |
| `ExportGeometry` | VisualCoreScenes | `maxEdge` (Int), `maxPixels` (Int, default 64 000 000), `hardMaxEdge` 8192 | `size(longEdge:aspect:) -> ExportSize`; long edge = min(longEdge, maxEdge, 8192); w × h ≤ maxPixels; `isCapped(longEdge:)` |
| `StillImage` | VisualCoreRendering | `width`, `height`, `rgba: [UInt8]` (top-down, 4 bytes/pixel) | `rgba.count == w × h × 4`; `pixel(x:y:)` |
| `StillImageEncoder` | VisualCoreRendering | static `pngData(_:) throws -> Data` | alpha forced opaque; sRGB tag |
| `OffscreenRenderError` | VisualCoreRendering | `.unavailable(String)`, `.invalidSize(width:height:max:)`, `.resource(String)`, `.scene(String)`, `.readback`, `.encoding` | Equatable, Sendable |

## App (Core)

| Entity | Fields | Rules |
|---|---|---|
| `ExportOptions` | `longEdge` (1080, 2048 or 4096), `aspect` (`ExportAspect`), `maxEdge` | `size` from `ExportGeometry`; `availableLongEdges` shows clamped values, deduplicated; `fileName(for name:)` → sanitized `<name>-<w>x<h>.png` (letters, digits, `-`, `_`; others → `-`; empty → `Untitled`; at most 60 characters); `formatLabel` = "Opaque · sRGB" |

## States (ExportSheet)

`idle` → `rendering` (progress, controls disabled) → `ready(url)` (share enabled) or `failed(message)` (retry
enabled) → closing the sheet removes the file and returns to `idle`.
