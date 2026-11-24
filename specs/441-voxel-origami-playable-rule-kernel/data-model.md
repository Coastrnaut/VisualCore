# Data model: R02-G15-01

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiVector` | x, y, z (Int) | cells and directions; directions are the six unit vectors |
| `VoxelOrigamiRotation` | 3 × 3 integer matrix (entries −1, 0, 1) | one of the 24 rotations of the cube; composition and application exact |
| `VoxelOrigamiCube` | parent (nil for cube 0, else a lower index), direction (a unit vector in the parent's frame), start turn 0 … 3 (0 for cube 0) | cube 0 at (0, 0, 0) with the identity |
| `VoxelOrigamiOrientations` | `fixed` (1), `upright` (4 about +y), `any` (24) | never a mirror image |
| `VoxelOrigamiLevel` | id, seed, difficulty 1 … 5, cubes (4 … 12), target (n distinct cells), orientations, budget 1 … 40, tutorial, fingerprint | rest and starting poses collision-free; the starting pose does not already match; schema 1; sorted-key JSON |
| `VoxelOrigamiPose` | cells (one per cube), orientations (one per cube) | computed from the quarter turns |
| `VoxelOrigamiShapeReport` | occupancy (Bool), canonical hash, covered count, best rotation and translation | exact; never decides by itself |
| `VoxelOrigamiAction` | turn(hinge 1 … n − 1, step ±1) | spends 1 action |
| `VoxelOrigamiFailure` | collision(hinge, moving, still, cell), sweep(hinge, moving, still, cell), budget(spent) | named codes `collision`, `sweep`, `budget` |
| `VoxelOrigamiPlay` | stage, turns (quarter turn per hinge), actions spent, pose, report, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `VoxelOrigamiRecord` | schema, level seed, index, kind (turn, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `VoxelOrigamiRules.Position` | turns, actions spent, outcome (playing, won, failed) | moves: every non-leaf hinge, then −1, +1 |
