# Research: R02-G17-03

- **R1 World mapping.** Decision: w(v) = (v − m) · s, with m the centre of the bounding box of every orbit position of
  every body widened by its radius in x and y, and s = 1.5 / (e + 1) for the box's largest extent e. Rationale: bodies
  move with the shown tick and the phases, so the box of all their orbit positions keeps every body in the frame with
  one fixed camera; each drawn body sits at its kernel position. Alternatives: the box of the current positions
  (rejected: the sky would rescale after every phase change); a fixed scale (rejected: wide orbits would leave the
  frame).
- **R2 The crescent drawn is the overlap judged.** Decision: a back body is darkened inside every nearer body's
  projected circle computed from the kernel's x, y and radius scaled by s (a signed circle mask in the fragment shader,
  the circles passed as per-vertex attributes), and only for the eclipses the kernel reports under way at the shown
  tick. Rationale: the camera is close to the projection axis but perspective would shift a purely visual overlap; the
  mask keeps the picture exact to the rules. Alternative: rely on sphere occlusion (rejected: painter's order without a
  depth buffer and perspective would disagree with the strict integer overlap near touching discs).
- **R3 Painter's order by camera distance.** Decision: with depth testing off (the shared mesh renderer's path),
  elements are drawn back to front by their centres' distance from the eye, ties by kind then index. Rationale: nearer
  bodies (greater z) are drawn after farther ones, as the eclipse order says.
- **R4 Layered and signed-distance shading.** Decision: body spheres shaded in layers (core, limb darkening, rim light)
  from the normal; rings, notches, frames, brackets, marks and the playhead are generated quads shaded by signed
  distance from per-vertex local coordinates; halos are thin rings with an emissive falloff. Rationale: a luminous look
  on the GL ES path without ray marching or textures.
- **R5 Shape is the non-colour twin.** Decision: notched rings ((index mod 6) + 1), square frames for fixed bodies, the
  dashed chosen ring, filled diamonds for matched events and crosses for the failing one, brackets for windows, rows of
  bars. Rationale: R02-F10's rule.
- **R6 Camera.** Decision: a fixed authored view close to the projection axis (eye (0.3, 0.2, 3.4) looking at
  (0, −0.25, 0)) fitted to x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 for aspects 0.4 … 2.5 with a 5 % margin.
  Rationale: the rules project along z, so the player sees what is judged, with a little parallax for depth; orbit
  comes with the gestures in R02-G17-04.
- **R7 Reuse of R02-G16-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Starlit Cartouche's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint; the adapter certifies each level directly from its recorded candidate (the
  witness's skipped count); the chosen body and shown tick are adapter presentation state outside the digest.
- **R8 Backdrop check with specks.** Decision: specks cover under 5 % of the backdrop and the frame check compares the
  median of a 9 × 9 patch with the gradient colour at that height (within 0.06).
