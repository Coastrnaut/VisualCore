# Data model: A15-P02 (feature 111)

| Entity | Fields | Rules |
|---|---|---|
| `DisplayMode` | ballAndStick (0), spaceFilling (1) | atom radius factor 0.30 / 1.00 of the van der Waals radius; sticks only in ball-and-stick, radius 0.12 Å |
| `CameraSettings` | turnSteps 0…23 (15° each, wraps), tiltSteps −8…8 (10° each), zoomSteps −4…4 (×0.85 each) | default 2, 2, 0; framed distance = bounding radius × 1.25 / sin(30°) for the narrower axis; refusal `a15.camera-limit` |
| `AtomItem` | position (Å), element symbol, radius (Å) | one per atom |
| `BondHalf` | from (atom centre), to (bond midpoint), element symbol, radius 0.12 Å | two per bond (recorded or inferred), ball-and-stick only |
| `MoleculeScene` | atoms, bondHalves, centre, boundingRadius | pure; same input → same scene; at most 1,500 items |
| `MoleculeState` (schema 2) | selection 0…4, mode, camera | schema 1 → 2 with defaults; damaged or newer refused |
