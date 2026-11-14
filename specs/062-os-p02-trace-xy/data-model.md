# Data Model: A08-P02

- **MinMaxDecimator** (VisualCoreAudioDSP): `static func reduce(_ samples: [Float], columns: Int) -> [ColumnRange]`;
  `ColumnRange(min: Float, max: Float)`; columns clamped to 1…`maxColumns` (8,192); non-finite samples skipped (a column
  of only non-finite samples is omitted); count ≤ columns → one range per finite sample.
- **Primitive.polyline(points: [Vec2], width: Double)** (VisualCoreScenes): `maxPolylinePoints = 8,192`; `bounded` keeps
  finite points (first 8,192) and |width| finite; `contains` = distance to any segment ≤ width / 2.
- **ScopeTrace** (OscilloscopeStudioCore): `waveformPoints(_ columns: [ColumnRange], in rect:) -> [Vec2]` (zig-zag),
  `xyPoints(left:right:gain:in square:) -> [Vec2]` (clamped ±1).
- **ScopeState** (schema 2): A08-P01's fields + `display` ∈ {waveform, xy}; schema 1 migrates with `waveform`.
