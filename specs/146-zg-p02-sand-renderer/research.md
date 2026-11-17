# Research: A20-P02 (feature 146)

- **D1 Sand pipeline (clarification Q1):** CPU stamping into a 480 × 360 field, uploaded with
  `RenderTarget.upload(rgbaFloats:)`, drawn by a relief shader. Alternatives: a GPU stamp `FieldPass` per sample
  (rejected: `FieldUniform` has no arrays, so about 200,000 full-target passes for a full replay); a GPU stroke mesh
  rendered into a height target (rejected for 0.1: replacement semantics need ordered max/min blending per groove and
  no CPU equivalent to test against).
- **D2 Field size:** 480 × 360 keeps the fine rake's period at about 5.8 cells and one upload at 691,200 floats.
- **D3 Transport (Q2):** three actions with fixed value counts; the core resamples the raw points.
- **D4 Native alternative (Q3):** pattern buttons that send the same stroke actions satisfy `GestureAlternatives`.
- **D5 Preview (Q4):** a SwiftUI overlay reading the presenter's observable preview state; it takes no touches.
