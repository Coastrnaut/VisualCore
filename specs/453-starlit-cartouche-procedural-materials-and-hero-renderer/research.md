# Research: R02-G16-03

- **R1 World mapping.** Decision: w(v) = (v − m) · s, with m the centre of the bounding box of every orbit position of
  every star and s = 1.5 / (e + 1) for the box's largest extent e. Rationale: stars move between beats, so the box of
  all their orbit positions keeps every star in the frame at every beat with one fixed camera; each drawn star sits at
  its kernel position. Alternatives: the box of the current positions only (rejected: the chart would rescale and jump
  after every leg); a fixed world scale (rejected: wide charts would leave the frame).
- **R2 Motion is presentation only.** Decision: the firmament's turn, the ship's glide and the glow are floating point;
  positions, the route, the win and failures come from the kernel's play and route report only. Rationale: renderer
  purity (US2).
- **R3 Painter's order by camera distance.** Decision: with depth testing off (the shared mesh renderer's path),
  elements are drawn back to front by their centres' distance from the eye, ties by kind then index. Rationale: stars,
  trails and the ship overlap in 3D; a sorted painter's order shows the nearer element on top without a depth buffer;
  the frame checks test only points clear of elements drawn after them.
- **R4 Layered and signed-distance shading.** Decision: star spheres are generated meshes shaded in layers (core, limb,
  corona) from the normal; dashes, stripes, notches, rings and the cartouche grid are generated quads shaded by signed
  distance from per-vertex local coordinates; trail ghosts are copies with falling alpha. Rationale: a luminous look on
  the GL ES path without ray marching or textures.
- **R5 Shape is the non-colour twin.** Decision: notched star rings ((index mod 6) + 1), the ship's arrow, the beacon
  and chosen rings, solid against dashed strokes, striped hazards, rows of bars and pips. Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored three-quarter view (eye (1.2, 1.0, 2.8) looking at (0, −0.2, 0)) fitted to x
  −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: the chart reads as
  3D on a phone and the cartouche and gauges fit below it; orbit comes with the gestures in R02-G16-04.
- **R7 Reuse of R02-G15-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Voxel Origami's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's
  skipped count); the chosen destination and wait are adapter presentation state outside the digest.
- **R8 Backdrop check with specks.** Decision: the firmament's specks cover under 5 % of its pixels and the frame check
  compares the median of a 9 × 9 patch with the gradient colour at that height (within 0.06). Rationale: a single pixel
  may land on a speck; the median of a patch does not.
