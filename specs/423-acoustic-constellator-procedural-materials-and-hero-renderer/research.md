# Research: R02-G13-03

- **R1 World mapping.** Decision: stars float at X = (gx − 5.5) · 0.14, Z = (gy − 5.5) · 0.11, Y = 0.15 + (gz − 5.5) ·
  0.02 from their 12 × 12 × 12 drawing grid, so every level fits the same box (x −0.9 … 0.9, z −0.7 … 0.7). Rationale: one
  camera fits every level; each drawn element names a kernel star or link. Alternatives: a free-flying camera (rejected:
  the graph would be unreadable and the camera would carry meaning).
- **R2 The drawn pulse is presentation only.** Decision: stars pulse by 1 + 0.15 · cos(2π · phase / 12) and the gauge fill
  uses floating-point arithmetic; links turn teal and snap, and the outcome is shown, from the kernel's exact listen
  report only. Rationale: renderer purity (US2): floating-point motion can never decide coherence.
- **R3 Pulsing along silver filaments.** Decision: the shown tick plays the kernel's listen report of the current state,
  one tick per 0.25 s; phase hands turn, links tint teal where the gap is at most 1 and break where they snap.
  Rationale: the design's "celestial musical diagrams pulsing along silver filaments".
- **R4 Signed-distance shading.** Decision: stars, hands, filaments, guides and gauges are generated meshes whose
  fragment shaders shade by signed distance (soft edges, line width) from per-vertex local coordinates. Rationale: the
  design's "acoustically inspired distance-field reveals" on the GL ES path without ray marching.
- **R5 Shape is the non-colour twin.** Decision: stars carry phase hands, guides are dashed, links solid, snapped links
  broken, coherence, hold and moves rows of bars and pips. Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored view from above and in front fitted to x −0.9 … 0.9, z −0.7 … 1.25, y 0 … 0.3
  for aspects 0.4 … 2.5 with a 5 % margin. Rationale: everything readable on a phone; gestures in R02-G13-04.
- **R7 Reuse of R02-G12-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Harmonic Bridges's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's skipped
  count).
