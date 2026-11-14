# Contract: A08-P02 public API (VisualCore) and experience actions

## VisualCoreAudioDSP (new)

- `public struct ColumnRange: Sendable, Equatable { public let min: Float; public let max: Float }`
- `public enum MinMaxDecimator { public static let maxColumns = 8_192; public static func reduce(_ samples: [Float], columns: Int) -> [ColumnRange] }`

## VisualCoreScenes (additive)

- `Primitive.polyline([Vec2], width: Double)`; `public static let maxPolylinePoints = 8_192`.

## VisualCoreRendering (behaviour)

- `PrimitiveRenderer` draws `.polyline` as one quad per non-zero segment within the same triangle batch.

## Experience actions (`a08.oscilloscope-studio`)

A08-P01's eight actions + `display.select [0…1]` (0 waveform, 1 XY). Snapshot schema 2 (migration from 1).
