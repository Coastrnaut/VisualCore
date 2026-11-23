# Research: R02-G11-03

- **R1 World mapping.** Decision: the chamber floor is the plane y = 0 with cell (x, y) centred at
  X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s, s = 1.8 / max(W, H), so every chamber (5 … 16 cells a side) fits the
  same box (x −1 … 1, z −1 … 1). Rationale: one camera fits every level; each drawn element names a kernel cell.
  Alternatives: a first-person view inside the temple (rejected: the board would be unreadable and the camera would
  carry meaning).
- **R2 Only the known is drawn.** Decision: the geometry is built from the knowledge and the located beacons only;
  unknown cells draw nothing but the ground and unlocated beacons are never drawn. Rationale: renderer purity (US2) and
  honesty — the picture must never solve the puzzle. Alternatives: drawing faint hidden walls (rejected: a spoiler).
- **R3 Crystallizing into wireframe.** Decision: known walls are dark blocks with sonar-mint edge strips; the walls the
  last pulse struck flare when the expanding pulse ring reaches their distance and fade over 0.5 s; rings move by
  presentation time only. Rationale: the design's "dark temples briefly crystallizing into wireframe from expanding cyan
  light" without any rule effect.
- **R4 Signed-distance shading.** Decision: tiles, rings and edge strips are generated meshes whose fragment shaders
  shade by signed distance (soft edges, line width) from per-vertex local coordinates. Rationale: the design's "SDF
  primitives" on the GL ES path without ray marching, which would cost the D3 tier.
- **R5 Shape is the non-colour twin.** Decision: walls are raised blocks, floor flat tiles, the entry a diamond, markers
  rings, beacons pillars, the gauge a row of bars. Rationale: R2-F10's rule.
- **R6 Camera.** Decision: a fixed authored view from above and in front fitted to the box x −1 … 1, z −1 … 1.1,
  y 0 … 0.8 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: everything readable on a phone; gestures in R02-G11-04.
- **R7 Reuse of R02-G10-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Backwards Aurora's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's
  skipped count).
