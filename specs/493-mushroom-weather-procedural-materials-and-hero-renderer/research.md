# Research: R02-G20-03

- **R1 One fit rule per level.** Decision: cell (r, c) at ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s) with
  s = min(1.8 / C, 1.6 / R). Rationale: catalog floors range from 6 × 6 to 9 × 10 cells; one fitting rule fills the
  same box for every level, and nothing a player does changes the floor's size, so the scene never jumps.
  Alternatives: one fixed scale for the largest kernel floor (rejected: a 6 × 6 floor would fill under half the box).
- **R2 Drawn values are judged values.** Decision: the mist shows the kernel's integer humidity at the shown cycle (side
  and shade both from h/M), caps glow only when the kernel's colony is in band at that cycle, and gauge markers stand
  at the kernel's value; nothing is interpolated between cycles. Rationale: the exact weather stays exact on screen.
- **R3 Painter's order for everything.** Decision (corrected at implement, 2026-11-27): every element is drawn in a fixed
  order by kind with depth testing off, solids included, each lathe emitting its far faces first; the glow is additive
  and last. Rationale: the window surface of the shared renderer carries no depth buffer (as `DepthMeshPass` records), so
  no round-two experience depth-tests; the first draft's "depth-tested solids" could not be met, and the quads' ±1.25
  transparent fringe would clip neighbours if depth were written.
- **R4 Lathed meshes and signed-distance shading.** Decision: stalks, caps and pods are lathed from fixed profiles (16,
  10 or flat segments by tier); the cap's fragment shader adds a translucent rim light and an SDF field of moisture
  beads whose density follows h/M; rings, brackets, markers and bars are generated quads shaded by signed distance from
  per-vertex local coordinates. Rationale: "procedural lathed stalks and SDF mushroom caps" on the GL ES path without
  textures; material codes travel in uv.
- **R5 Fronds, droplets and motes are decoration.** Decision: L-system fronds (three generations, fixed rule) on blocked
  cells and the floor's edge, droplets rising from pods and a few spore motes on a fixed loop, all at the two richer
  tiers only and moved by presentation time only. Rationale: the design's "L-system miniature flora" and "deterministic
  boids" without rule meaning; level-2 drops them, so nothing a player needs is lost.
- **R6 Shape is the non-colour twin.** Decision: band rings (solid in band, dashed out), mist size as well as shade,
  vent slats open or flat, log and stone shapes, gauge brackets with markers, run bars, rows of bars, moon phase ticks.
  Rationale: R02-F10.
- **R7 Camera.** Decision: a fixed authored perspective tilted toward the floor (eye (0, −1.6, 3.0) looking at
  (0, −0.2, 0)) fitted to x −1.3 … 1.3, y −1.5 … 1.2, z 0 … 0.3 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: the stalks
  read as standing mushrooms while every cell stays visible.
- **R8 Reuse of R02-G19-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Microscopic Aurora's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint; the adapter certifies each level from its recorded candidate (the witness's skipped
  count); the shown cycle is presentation state outside the digest.
