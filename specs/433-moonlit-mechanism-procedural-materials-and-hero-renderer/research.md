# Research: R02-G14-03

- **R1 World mapping.** Decision: the wall is a vertical plane at z = −0.6 with cell size s = min(1.8 / W, 1.2 / H);
  cell (c, r) sits at x = (c − (W − 1)/2) · s, y = 0.65 − (r − (H − 1)/2) · s; a gear stands at z = −0.6 + 0.12 · depth
  in front of its centre cell, and the lamp moves only its shadow (down by height · depth cells). Rationale: one camera
  fits every level (centres lie in rows 2 … H − 5, rims within 3.4 cells, the lamp at most at y 1.44); each drawn shadow
  square is a kernel cast cell. Alternatives: a perspective light
  projection drawn from polygons (rejected: the drawn shadow could differ from the judged one).
- **R2 The drawn rotation is presentation only.** Decision: gears rotate by phase · 360° / T and the soft shadow edge
  fades in floating point; shadow cells, missing and stray cells and the outcome come from the kernel's run report only.
  Rationale: renderer purity (US2).
- **R3 Shadows are the kernel's cells.** Decision: the shown key frame's cast cells are drawn as ink squares with a
  feather quad at the richer tiers. Rationale: the design's "CPU polygonal 3D shadow projections, soft shadow
  approximation" with the shadow seen always the shadow judged.
- **R4 Signed-distance shading.** Decision: teeth, spokes, outlines, marks and gauges are generated meshes whose fragment
  shaders shade by signed distance (soft edges, line width) from per-vertex local coordinates. Rationale: crisp outlines
  and fresnel-like rim highlights on the GL ES path without ray marching.
- **R5 Shape is the non-colour twin.** Decision: shadow cells solid, targets outlined, missing dotted, stray hatched,
  forbidden crossed; gears carry a tooth-zero notch, the lamp a height ladder; cards, pips and bars are rows of shapes.
  Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored front view (eye (0, 0.65, 2.4) looking at (0, 0.55, −0.3)) fitted to x
  −0.95 … 0.95, y −0.45 … 1.5, z −0.6 … 0.4 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: everything readable on a
  phone; orbit comes with the gestures in R02-G14-04.
- **R7 Reuse of R02-G13-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Acoustic Constellator's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's
  skipped count); the shown key frame is adapter presentation state outside the digest.
