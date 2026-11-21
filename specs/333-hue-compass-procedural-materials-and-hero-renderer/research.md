# Research: R02-G04-03

- **R1 Compass layout.** Decision: the compass in the xy-plane with the kernel's bearing angle 2πb/96, the needle a
  faceted glass prism, the hue wheel as 24 arc segments, the fog as 96 translucent prisms outside the wheel. Rationale:
  one-to-one with the rules (bearing, band, fog density), so every drawn element names a rule value; the design's
  "instanced translucent prisms and analytic fog depth". Alternatives: a fog volume rendered by ray marching (rejected:
  costly on D3 and not needed to show 96 densities).
- **R2 Colour and its non-colour twin.** Decision: band h's colour is hue h/24 (saturation 0.85, value 1.0) computed by the
  same formula in the shader and in the CPU reference; each band also carries a grayscale glyph (shape h mod 4 and
  ⌊h/4⌋ + 1 marks); fog density is brightness only. Rationale: R2-F10's rule that luminance and shape carry every clue
  independently of hue.
- **R3 Hidden target.** Decision: the snapshot holds the target only after the play ends. Rationale: the renderer cannot
  leak what it never receives; a purity test compares frames of two levels differing only in the target.
- **R4 Camera.** Decision: a fixed authored view down −z tilted 35° about x, distance fitted to a bounding circle of
  radius 1.4 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: a readable wheel with visible prism depth.
- **R5 Reuse of R02-G03-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Wave Knot Keeper's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint.
