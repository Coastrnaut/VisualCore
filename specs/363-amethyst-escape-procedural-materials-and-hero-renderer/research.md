# Research: R02-G07-03

- **R1 Crystal layout.** Decision: nested annuli in the xz-plane, shell k from radius 0.2 + k·w to 0.2 + (k + 1)·w with
  w = 0.8 / n, each sector a bevelled wedge prism at world sector (s + offset) mod S. Rationale: one-to-one with the rules
  (shell, sector, offset, pocket), so every drawn element names a rule value. Alternatives: true 3D nested polyhedra
  (rejected for this feature: hides inner pockets from a fixed camera; depth comes from stepped heights instead).
- **R2 Cathedral silhouette.** Decision: inner shells stand taller (h_k = 0.08 + 0.06·(n − 1 − k)), so the crystal rises
  to the centre like a gem cathedral; facets are translucent with alpha 0.55 and shifting specular highlights driven by a
  time uniform. Rationale: the design's "layered amethyst gem cathedral with dancing internal facet highlights" while
  keeping every pocket visible from the 50° camera.
- **R3 Shape is the non-colour twin.** Decision: openings are rim gaps, walls are raised fins, blocked wedges are dark
  with a raised cross, the exit carries an arrow, the pearl is the only sphere. Rationale: R2-F10's rule that shape and
  luminance carry every clue independently of hue.
- **R4 Camera.** Decision: a fixed authored view from the front (+z) pitched 50° down, fitted to a bounding sphere of
  radius 1.1 for aspects 0.4 … 2.5 with a 5 % margin. Rationale: every pocket visible; orbit and layer isolation come with
  gestures in R02-G07-04.
- **R5 Reuse of R02-G06-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Chrono Constellator's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint; generated levels are cached once per process.
