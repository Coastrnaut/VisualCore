# Contract: A13-P02 gestures, glow and loops

- Gestures (priority): rotate 3 (two fingers, `RotateRecognizer`), drag 2 (`DragRecognizer`, 10 points), tap 1
  (`TapRecognizer`, 10 points, 0.3 s).
- Tap on a turnable tile: `tile.select [i]` if not selected, else `tile.turn`; elsewhere nothing, answered in words.
- Drag from a turnable tile, length ≥ 0.35 cell from touch-down: target `/` within 45° of NE or SW, else `\`; if the
  tile differs, `tile.select [i]` then `tile.turn`.
- Rotate over the selected tile: one `tile.turn` per ±45° accumulated since the last snap.
- Glow: halo width 0.30 cell, opacity 0.25; core width 0.08 cell, opacity 1; never beyond 0.15 cell from a segment.
- Lit target ring inset 0.05; selected tile outline inset 0.04.
- Spoken beam change at most once per second of frame time while VoiceOver runs.
- Loops: every branch ≤ 64 bounces; total ≤ 256 segments.
