# Research: R02-G18-03

- **R1 Fixed compass scale.** Decision: world = sky units × s with s = 0.9 / 16 384, so the sky bound (64 lattice
  units) lies at radius 0.9 for every level. Rationale: the compass is the hero and the frame of reference; tuning the
  orbit must not rescale it, and every valid orbit stays inside the sky bound by the kernel's rule. Alternatives: a box
  fitted to the current orbit (rejected: the sky would jump after every tuning); a box of all reachable orbits per level
  (rejected: different scales between levels for no rule reason).
- **R2 The orbit drawn passes through the positions judged.** Decision: the orbit ribbon goes through every kernel
  position in tick order; refinement points between ticks (tiers 0 and 1) lie on the analytic ellipse at eccentric
  anomalies between the ticks' anomalies, computed in `Double` for presentation only, and the contact test stays on the
  kernel's chords. Rationale: "adaptive analytic ellipse tessellation" with exactness kept; the ribbon is smooth on rich
  tiers and exactly the chords on level-2.
- **R3 Painter's order by kind.** Decision: with depth testing off, elements are drawn backdrop, wedges, compass, ghost
  loop, orbit loop, apsis markers, planets, star, orbiter, gauges, then the additive glow. Rationale: the scene is
  essentially planar seen from above, so a fixed order by kind is exact; Celestial's lesson (distance order painted
  rings over bodies) argues against distance sorting for coplanar elements.
- **R4 Layered and signed-distance shading.** Decision: spheres shaded in layers (core, limb darkening, rim light) from
  the normal; spokes, rim, notches, brackets, markers, gauge tracks and marks are generated quads shaded by signed
  distance from per-vertex local coordinates; the orbit loop is a ribbon with an emissive core and soft edge.
  Rationale: a luminous look on the GL ES path without ray marching or textures; the shared mesh renderer binds only
  position, normal and uv, so material codes travel in uv.
- **R5 Shape is the non-colour twin.** Decision: rim notches (s + 1 per sector), target brackets, the periapsis diamond
  and apoapsis square, hatched hazard rings, filled and hollow gauge marks, rows of bars. Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored view straight down the z axis (eye (0, −0.3, 3.6) looking at (0, −0.3, 0))
  fitted to x −1.0 … 1.0, y −1.65 … 1.0 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: the rules live in the
  plane, so the player sees what is judged; depth only separates the ghost loop and the wedges visually.
- **R7 Reuse of R02-G17-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Celestial Eclipse Lab's shapes as recorded at R02-G17-03 so the shared checks apply unchanged;
  the digest is the level number and the play fingerprint; the adapter certifies each level directly from its recorded
  candidate (the witness's skipped count); the shown tick is adapter presentation state outside the digest.
- **R8 Backdrop check with specks.** Decision: specks cover under 5 % of the backdrop and the frame check compares the
  median of a 9 × 9 patch with the gradient colour at that height (within 0.06).
