# Research: A08-P04 (feature 064)

## 0. Verified facts (2026-11-14)

- `PinchRecognizer` (VisualCoreScenes) reports `scale` (current ÷ initial finger distance) and `state` from
  `PointerEvent`s; `PointerEvent` carries id, phase, location (points, top-left) and timestamp.
- `JourneyPresetStore` (A07) is the pattern: built-ins in code, one file per user preset, `.newer`/damaged kept and
  counted, rename and delete of built-ins refused.
- `ScopeState` is schema 2 with a migration chain in `ScopeCore`; the registry stores `schemaOneExample()`.

## 1. Decisions

- **D1 Capture = frozen window with metadata** (spec assumption): matches the catalog fixture; image export stays a later
  idea (contract row M13 notes it).
- **D2 Zoom by doublings (clarification 2):** one timebase step per factor 2 keeps zoom discrete and testable; the
  spectrum view ignores pinch.
- **D3 Precision rules (clarification 3):** time rounded to the sample period and three significant digits; frequency
  whole hertz with a resolution mark; level two decimals of full scale and 0.1 dB; "at or beyond full scale" at |x| ≥ 1.
- **D4 Preset content (clarification 4):** settings without source, freeze or cursors, so a preset never switches on the
  microphone or carries a measurement.
