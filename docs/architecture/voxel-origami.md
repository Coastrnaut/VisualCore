# Voxel Origami (R02-G15) — rules

Experience `r02-g15.voxel-origami` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`VoxelOrigamiCore` (feature 441, R02-G15-01). A chain of luminous cubes is joined by hinges; each hinge turns in quarter
turns and swings every cube beyond it to a new place on the cube lattice. The level is won when the cubes occupy
exactly the cells of the target solid, in any orientation the level allows and anywhere in space; a turn that would
put a cube inside another, or drag one through another, fails. Everything here is pure, exact integer logic; drawing,
controls and sound come in later features of R02-G15.

## Cubes, hinges and poses

- **Cubes.** 4 … 12; cube 0 is the root, fixed at cell (0, 0, 0) with the identity orientation; every other cube i is
  attached face to face to a lower-index parent p(i) along a rest direction d(i), one of ±x, ±y, ±z, given in the
  parent's frame. The joint is hinge i, with a quarter turn q(i) in 0 … 3 (0°, 90°, 180°, 270°) and a starting value.
- **Poses.** Computed from the root with the 24 rotation matrices of the cube (entries −1, 0, 1):
  x(i) = x(p) + O(p) · d(i) and O(i) = O(p) · R(d(i), q(i)), R being quarter turns counter-clockwise by the right-hand
  rule. A turn of hinge i therefore twists everything beyond cube i about the line from p(i) through i: cube i spins in
  place, its descendants swing, and the pair stays face to face, so the tree can never come apart.
- **Idle hinges.** A hinge with no descendant off its axis (a leaf, or a straight run along the axis) would move
  nothing and is refused (`r02-g15.action`).

## Collisions and the sweep

The turning body is cube i and its subtree; every other cube stands still. A turn first checks the end pose: a swinging
cube landing on a still cube's cell fails `collision` (the lowest such swinging cube, the still cube and the cell).
It then checks the sweep: each swinging cube's centre traces an open quarter arc of radius ρ around the axis; a still
cube in the same layer blocks when that arc passes strictly within one cell of its centre in both in-plane coordinates
(inside the open square of half-side 1 around it), which fails `sweep`. The decision is exact: the square is clipped to
the arc's 90° wedge, and the arc enters it exactly when the clipped polygon's least squared distance from the axis is
below ρ² and its greatest above ρ², every coordinate a rational number of small integers. A cube may neither pass
through nor clip a cube that does not turn with it, its parent on the axis included. A failed turn leaves the pose as it
was. (The first rule, a band around the arc inside the arc's box, let a cube orbit through its parent at ρ = 1; an
independent 1 000-step sampling of the arc found it during implementation, and the rule above agrees with that sampling
in every unambiguous case.)

## Matching and the truth metric

The target is a set of n distinct cells. The level allows the orientations `fixed` (the identity), `upright` (the 4
quarter turns about +y) or `any` (the 24 rotations; never a mirror image). The canonical form of a cell set is the
smallest sorted cell list among its allowed rotations, each translated so its smallest x, y and z are 0; its hash is the
SHA-256 of that list's text. After every accepted turn the level is won when the occupied cells' canonical form equals
the target's; otherwise a budget (1 … 40) fully spent fails `budget`. The truth metric — occupancy, the canonical hash
and the covered count (the most cubes one allowed rotation and translation of the target covers) — is reported after
every action (`VoxelOrigamiShapeReport`) and never decides on its own.

## Play, records and the puzzle contract

The play (`VoxelOrigamiPlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or failed →
result. Turns are validated in the order stage, previous fingerprint, action (`r02-g15.stage`, `r02-g15.stale`,
`r02-g15.action`: an unknown hinge, a step other than ±1, an idle hinge); every accepted turn spends one action and
appends a record with previous and next fingerprints (SHA-256 of the schema, the level fingerprint, the quarter turns,
the actions spent, the stage and the failure). Undo and redo restore exact states; undo from failed returns to playing
before the failing turn and refunds its action (recorded); a won level is final. A trace replays to the same states.
Levels are JSON schema 1 with sorted keys and a fingerprint, re-checked on decode (`r02-g15.level`,
`r02-g15.newer-schema`, `r02-g15.malformed`). `VoxelOrigamiRules` expresses the rules as an R02-F23 `PuzzleRules`
(moves: every hinge that would swing a cube, ascending, then −1, +1) for the level certification of R02-G15-02.
