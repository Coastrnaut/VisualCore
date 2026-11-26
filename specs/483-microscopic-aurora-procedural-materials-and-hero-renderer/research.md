# Research: R02-G19-03

- **R1 Fixed dish scale.** Decision: world = (dish units − 3072) × s with s = 0.9 / 2816, y flipped so up is up, so an
  enclosure of 11 cells (every catalog level) has its rim at radius 0.9. Rationale: the dish is the frame of reference;
  placing wells must not rescale it. Alternatives: a box fitted to the swarm (rejected: the dish would jump after every
  placement); a scale per enclosure radius (rejected: every catalog level has radius 11, and levels with a smaller
  radius simply show a smaller rim at the same scale).
- **R2 Drawn positions are judged positions.** Decision: swimmers stand, and ribbons pass, exactly at the kernel's
  integer positions of the shown and earlier ticks; nothing is interpolated between ticks. Rationale: "deterministic
  ribbon trails" with exactness kept; the fixed-step swim already gives 120 … 160 positions per swimmer.
- **R3 Painter's order by kind.** Decision: with depth testing off: backdrop, field, fronds, rim, stencil, lit cells,
  sites, wells, ribbons, swimmers, gauges, bars, then the additive glow. Rationale: the dish is planar seen from above;
  Apsides' and Celestial's lesson argues for a fixed order by kind over distance sorting.
- **R4 Capsules and signed-distance shading.** Decision: swimmers are tapered capsules (a two-radius stadium) oriented
  along their velocity, shaded with a core and rim light; outlines, rings, spirals, arrows, gauge tracks and marks are
  generated quads shaded by signed distance from per-vertex local coordinates; ribbons have an emissive core fading to
  the tail. Rationale: a bioluminescent look on the GL ES path without textures; material codes travel in uv.
- **R5 Fronds are decoration.** Decision: L-system fronds (three generations, angle and length from a fixed rule) at the
  rim on the two richer tiers only. Rationale: the design's "L-system miniature flora" without any rule meaning; level-2
  drops them, so nothing a player needs is lost.
- **R6 Shape is the non-colour twin.** Decision: stencil outlines, filled lit cells, site rings, well spirals (turns =
  strength, arrow = sense), filled and hollow gauge marks with requirement ticks, rows of bars. Rationale: R02-F10.
- **R7 Camera.** Decision: a fixed authored view straight down the z axis (eye (0, −0.15, 3.4) looking at
  (0, −0.15, 0)) fitted to x −1.0 … 1.0, y −1.35 … 1.0 for aspects 0.4 … 2.5 with a 5 % margin.
- **R8 Reuse of R02-G18-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Apsides Workshop's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level from its recorded candidate (the witness's skipped count);
  the shown tick is presentation state outside the digest.
