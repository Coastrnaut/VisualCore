# Research: R02-G12-03

- **R1 World mapping.** Decision: islands stand on the plane y = 0 at X = (gx − 7.5) · 0.12, Z = (gy − 4.5) · 0.12 from
  their 16 × 10 drawing grid, so every level fits the same box (x −0.9 … 0.9, z −0.54 … 0.54). Rationale: one camera
  fits every level; each drawn element names a kernel island or string. Alternatives: a free-flying camera along the
  strings (rejected: the graph would be unreadable and the camera would carry meaning).
- **R2 The drawn wave is presentation only.** Decision: strings swing by Σ 0.03 · w · sin(nπu) · cos(2π n t / 1.6) of
  their resonant modes in the shown step; the bridge decision and the sample marks come from the kernel's exact swing
  E(k) only. Rationale: renderer purity (US2): floating-point motion can never decide a bridge.
- **R3 Swelling into architecture.** Decision: a string that is a bridge in the shown step gets a translucent cyan
  membrane beneath it and reached islands glow; the shown step cycles every 1.2 s so a player sees each step's bridges.
  Rationale: the design's "strings swelling into translucent glowing architecture as they find resonance".
- **R4 Signed-distance shading.** Decision: membranes, marks, rings and edge strips are generated meshes whose fragment
  shaders shade by signed distance (soft edges, line width) from per-vertex local coordinates. Rationale: the design's
  "acoustically inspired distance-field reveals" on the GL ES path without ray marching.
- **R5 Shape is the non-colour twin.** Decision: islands are prisms, the start a ring, the goal a star, bridges wide
  membranes, other strings thin lines, swings filled squares or hollow rings, steps pips, the gauge bars. Rationale:
  R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored view from above and in front fitted to x −1 … 1, z −0.7 … 1.0, y 0 … 0.2 for
  aspects 0.4 … 2.5 with a 5 % margin. Rationale: everything readable on a phone; gestures in R02-G12-04.
- **R7 Reuse of R02-G11-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Echo Cartographer's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's skipped
  count).
