# Research: A20-P01 (feature 145)

- **D1 Coordinates (clarification Q1):** normalized tray coordinates with a 4:3 aspect, distances in tray widths.
  Decision: the document is screen-independent and orientation changes cannot move a stroke. Alternative: points in
  view units (rejected: a rotation or a new device would change the garden).
- **D2 Resampling (Q2):** linear resampling at 0.004 tray widths with a 512-point cap. It mirrors the rule of
  `PointerVelocityTracker` (uniform spacing, capped), applied to a stored path in tray units rather than to live
  pointers in view points. Alternatives: Catmull-Rom smoothing (rejected for 0.1: it can overshoot the finger and
  VisualCore has none for strokes); reusing `PointerVelocityTracker` on stored points (rejected: it works in view
  points with live phases and timestamps, which the document does not store).
- **D3 Rake footprint (Q3):** a cosine groove profile that replaces the height under the footprint. Replacement makes
  overlapping strokes order-dependent but deterministic, and equals what a real rake does to sand. Alternative:
  additive carving (rejected: repeated raking would dig without bound).
- **D4 History (Q4):** command lists with a 100-command bound and a checkpoint (manual risk 1). Alternative: texture
  snapshots per undo (rejected: memory per step and no CPU test).
- **D5 Reference field:** 160 × 120 `Float` cells, stamped per resampled point within the footprint's bounding box.
  The GPU target of A20-P02 must match it within a stated tolerance.
