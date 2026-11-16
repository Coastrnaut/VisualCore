# Data model: A15-P03 (feature 112)

| Entity | Fields | Rules |
|---|---|---|
| `CameraSettings` (extended) | + panX, panY −10…10 (steps of 0.1 × bounding radius along view right/up) | default 0, 0; reset view zeroes them; refusal `a15.camera-limit` |
| `MoleculeState` (schema 3) | selection, mode, camera (with pan), selectedAtom (none or 0…atoms−1) | schema 2 → 3 with no selection and no pan; molecule change clears selection and resets camera and pan; mode change keeps both |
| `AtomPicker` | pick(ray origin, direction, scene) → atom index? | nearest positive hit against drawn radii; deterministic |
| `LabelLayout.Label` | atom index, symbol, point (pt) | 24 × 18 pt box 6 pt right/up of the projected centre; selected first, then by distance to the eye; no overlaps; off-canvas none |
| `BondStyle` | stick count (1, 2, 3), stick radius (0.12, 0.07, 0.06; inferred 0.06), offsets (0; ±0.09; 0, ±0.12 Å) | from order and provenance; side direction in the plane of a neighbouring bond, else perpendicular to the least-aligned axis |
