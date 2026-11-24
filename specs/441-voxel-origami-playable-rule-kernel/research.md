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
- **R3 End collision, then the exact sweep.** Decision: first a swinging cube landing on a still cube's cell
  (`collision`), then a still cube in the same layer whose open square of half-side 1 the open quarter arc of a
  swinging cube's centre enters (`sweep`), decided exactly by clipping the square to the arc's wedge and comparing the
  polygon's least and greatest squared distances with ρ² in rationals. Still cubes are every cube outside the turning
  body (cube i and its subtree). Rationale: the catalog's "swept AABB collision filter" made exact; a cube may neither
  pass through nor clip a cube that does not turn with it (its parent on the axis included), while the body's own cubes
  on the axis spin in place and never block. Alternatives: a band of width 2 around the arc inside the arc's box (the
  first rule; it let a cube orbit through its parent at ρ = 1 and missed clips at the inner edge and above the box);
  continuous sampling (floating point).
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
