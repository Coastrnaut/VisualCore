# Contract: bodies, scale modes and flight (feature 105)

Actions add `scale.mode [0…1]` (0 enhanced, 1 true-relative; non-whole refused `a14.invalid-choice`). Outcome stays
`viewing-<id>`. Manifest: state schema 3; a fixture `fixture-earth-true-scale` (Earth, mode 1) with a pinned digest.

Canvas description adds the mode: "… Distances and sizes not to scale." (enhanced) or "… Distances and sizes to one
scale; small bodies marked." (true-relative). Controls: a "Scale" picker (Enhanced, True relative) with the active
mode as value and an announcement on change.

Tests: SphereNoiseTests (range, determinism, seam and pole equality), SurfaceRecipeTests (digests stable and distinct,
seam colour jump ≤ the largest neighbour jump elsewhere), RingRecordTests (audit, ordering), ScaleModeTests (true-mode
ratios within 0.1 %; enhanced equals A14-P02), FocusFlightTests (72 pairs × 31 frames × 2 modes, Reduce Motion one
frame, restart), PrecisionTests (< 0.1 px), SceneMeshesTests (two-sided ring, 400 star directions, star sphere inside the far plane in both modes),
SolarBodiesRenderTests (coloured bodies, ring visible, scale switch changes pixels, context recreation within a
pixel tolerance).
