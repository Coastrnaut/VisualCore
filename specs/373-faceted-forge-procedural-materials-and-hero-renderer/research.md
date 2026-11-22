# Research: R02-G08-03

- **R1 World mapping.** Decision: subtract the crystal's corner centroid and divide by R, the largest centroid-to-corner
  distance, so every level's crystal fits the unit sphere whatever its shape (cube, box, cut cube, octahedron). Pieces
  are drawn from their exact faces in the kernel's corner order. Rationale: one camera fits every level; each drawn
  face names a kernel face. Alternatives: a fixed scale of 1/6 (rejected: small boxes and octahedra would look tiny).
- **R2 Opening like a blossom.** Decision: each piece moves along the direction from the crystal's centroid to its own
  centroid by 0.12 (0.2 when won), eased over 0.4 s of presentation time. Rationale: the design's "incandescent mineral
  interiors opening like a geometric blossom"; cut faces become visible because pieces separate. A piece whose centroid
  coincides with the crystal's (to 1e-9) does not move. Alternatives: an exploded view along cut normals (rejected: a
  piece cut several times has no single normal).
- **R3 Cut face classification.** Decision: a face is a cut face when its plane (direction, sign, depth) is not one of
  the crystal's half-spaces. Rationale: exact and cheap from the kernel's face planes; matches "SDF cuts reveal
  incandescent interiors". Cut faces carry a lattice (a pattern, not only colour).
- **R4 Shape is the non-colour twin.** Decision: cut faces have a lattice, original faces are plain glass, the preview
  plane has a dashed rim, a sliver piece carries a cross, the cut mark is a row of bars. Rationale: R2-F10's rule.
- **R5 Camera.** Decision: a fixed authored view from the front (+z) pitched 30° down, fitted to a bounding sphere of
  radius 1.45 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: the opened crystal (radius ≤ 1.2) and the mark fit;
  orbit comes with gestures in R02-G08-04.
- **R6 Reuse of R02-G07-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Amethyst Escape's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; generated levels are cached once per process.
