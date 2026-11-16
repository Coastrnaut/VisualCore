# Research: A15-P03 (feature 112)

## D1 — Gestures
- **Decision**: the Tiny Worlds pattern (`WorldsGestures` over `GestureArbiter`): drag 0.3°/point accumulated into 15°
  turn and 10° tilt steps, pinch into 0.85 zoom steps, the pinch midpoint into 40-point pan steps, tap to pick
  (clarification Q1). Refused steps from gestures are dropped quietly.
- **Alternatives**: continuous camera (rejected: the state and buttons are step-based since A15-P02).

## D2 — Pan
- **Decision**: 0.1 × bounding radius per step along the view's right/up, ±10 steps (clarification Q2).

## D3 — Picking and occlusion
- **Decision**: line of sight through the tapped point against each atom's drawn sphere, nearest positive hit wins
  (clarification Q3); bond picking not in version 0.1.

## D4 — Labels and bond styles
- **Decision**: A14's label rule adapted (24 × 18 pt boxes, selected first, then by distance, skip overlaps, off-canvas
  none) in the host's canvas overlay; parallel sticks for double and triple bonds, a thin stick for inferred bonds,
  offset in the plane of a neighbouring bond (clarification Q4).

## D5 — State, panel and speech
- **Decision**: schema 3 (pan, selected atom), migration from 2; panel lines, description suffix and one announcement
  per action (clarification Q5).
