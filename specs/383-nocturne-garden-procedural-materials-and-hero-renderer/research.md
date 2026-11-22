# Research: R02-G09-03

- **R1 World mapping.** Decision: the bed stands upright as the plane z = 0 with cell size u = 2 / W, so every bed
  (16 × 12 … 32 × 24, all 4 : 3) is 2 wide and 1.5 high; row 0 is at the bottom, where the blooms' feet are.
  Rationale: one camera fits every level; each drawn quad names a kernel cell. Alternatives: a horizontal bed seen from
  above (rejected: the design's silhouettes "climb" through the mist).
- **R2 The shadow is the kernel's mask.** Decision: the shadow layer is one quad per mask cell, darkened, with a
  feathered band along boundary edges only (soft shadow approximation); no shadow is computed on the GPU. Rationale:
  renderer purity (US2) and the frame checks name exact cells. Alternatives: projected shadow volumes (rejected: the
  picture could disagree with the verdict).
- **R3 Blooms in front of the mist.** Decision: each bloom's head is its kind's outline at size·u, unstretched,
  extruded 0.04 at z = 0.35, with an L-system stem of leaf pairs below it; the shadow on the mist is the stretched cast.
  Rationale: the player sees the flower and, behind it, its longer or shorter shadow as the lantern moves; frame checks
  skip cells behind a bloom's screen box. Alternatives: drawing the flower on the plane (rejected: no depth).
- **R4 Shape is the non-colour twin.** Decision: the target is a rim, forbidden cells are hatched, leaks are crossed,
  shadows are the darkest element, the gauge is a row of bars. Rationale: R2-F10's rule.
- **R5 Camera.** Decision: a fixed authored view from +z pitched 8° down, fitted per level to the sphere around the bed
  (widened by every possible bloom head), lantern and gauge for aspects 0.4 … 2.5 with a 5 % margin. Rationale: everything readable on a phone; gestures in R02-G09-04.
- **R6 Reuse of R02-G08-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Faceted Forge's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate.
