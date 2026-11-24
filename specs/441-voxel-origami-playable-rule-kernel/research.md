# Research: R02-G15-01

- **R1 Twist hinges on the parent–child line.** Decision: hinge i turns everything beyond cube i about the lattice line
  from its parent through i, in quarter turns. Rationale: a quarter turn about a line through cube centres maps the
  lattice onto itself, so "each cube occupies integer local lattice coordinates; hinge angle one of {0, 90, 180, 270}"
  holds exactly, the pair stays face to face, and all four angles are reachable. Alternatives: a hinge on a cube edge
  (the child would sit inside its parent at 270°, so one of the four angles could never be used, and half-cell
  positions appear mid-fold); free rotations (floating point).
- **R2 Orientation frames.** Decision: each cube carries one of the 24 rotation matrices; rest directions are given in
  the parent's frame. Rationale: composing frames down the tree makes a turn of an inner hinge carry every outer
  hinge's axis with it, as a real hinged chain does; matrices with entries −1, 0, 1 keep everything exact.
- **R3 End collision, then the swept band.** Decision: first a swinging cube landing on a still cube's cell
  (`collision`), then a still cube in the swept band (`sweep`): same coordinate along the axis, inside the quarter
  arc's axis-aligned box, and strictly within one cell of the arc's circle, all tested with integer squares.
  Rationale: the catalog's "swept AABB collision filter", narrowed to the band a unit cube actually passes, so a cube
  sitting on the axis (the hinge cube itself) never blocks while a cube beside the arc does; deciding in integer squares
  is exact on every device. Alternatives: the bare box (blocks every turn of a cube beside its hinge cube, because the
  box contains the axis); continuous sampling (floating point).
- **R4 Canonical form.** Decision: the smallest sorted cell list over the allowed rotations, each translated to start at
  the origin; the hash is `StableHash` of its text. Rationale: "occupied voxel set matches target up to allowed global
  rotation" becomes one equality of canonical forms; mirror images are never allowed (a physical chain cannot reflect).
- **R5 Covered count as the truth metric.** Decision: the most cubes any allowed alignment of the target covers,
  computed by trying every allowed rotation and every translation that maps some target cell onto some occupied cell.
  Rationale: exact, bounded (24 × 144 × 12 at most), and a natural "how close" measure for hints later.
- **R6 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  quarter turns, actions spent, stage, failure) and records with previous and next fingerprints, as feature 431.
- **R7 Undo from failed.** Decision: undo from failed returns to playing before the failing turn and refunds its action
  (recorded); a won level refuses undo.
- **R8 Idle hinges refused.** Decision: a hinge with no descendant off its axis (a leaf included) is refused
  (`r02-g15.action`). Rationale: turning it would change no cell, so it would spend an action for nothing and inflate the solver's state space.
