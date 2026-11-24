# Research: R02-G15-03

- **R1 World mapping.** Decision: w(c) = (c − m) · s, with m the centre of the bounding box of the occupied cells and
  the target cells at the best allowed alignment, and s = 1.5 / (e + 1) for the box's largest extent e. Rationale: the
  chain and its target fit one fixed camera for every level (catalog chains of at most 10 cubes); each drawn cube sits in
  its kernel cell; the target shown where the player is closest to it. Alternatives: a fixed world scale (rejected: long
  chains would leave the frame); the target at its own coordinates (rejected: it could sit far from the chain).
- **R2 The drawn turning is presentation only.** Decision: the glow and any turning preview are floating point;
  positions, matches and the outcome come from the kernel's pose and shape report only. Rationale: renderer purity
  (US2).
- **R3 Painter's order by camera distance.** Decision: with depth testing off (the shared mesh renderer's path),
  elements are drawn back to front by their centres' distance from the eye. Rationale: cubes of a folded chain overlap
  in 3D; a sorted painter's order shows the nearer cube on top without a depth buffer; the frame checks test only points
  clear of elements drawn after them.
- **R4 Signed-distance shading.** Decision: cube edges, bevels, glyphs, dots, stripes and outlines are generated meshes
  whose fragment shaders shade by signed distance from per-vertex local coordinates (faceted lighting from the face
  normal). Rationale: crisp edges and a frosted look on the GL ES path without ray marching.
- **R5 Shape is the non-colour twin.** Decision: the inner glyph solid in a target cell and hollow outside, the dot
  count per cube, the striped chosen hinge, the wireframe target, rows of pips and bars. Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored three-quarter view (eye (1.4, 1.1, 2.6) looking at (0, −0.1, 0)) fitted to x
  −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: the solid reads as 3D
  on a phone; orbit comes with the gestures in R02-G15-04.
- **R7 Reuse of R02-G14-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Moonlit Mechanism's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the witness's
  skipped count); the chosen hinge is adapter presentation state outside the digest.
