# Research: R02-G20-04

- **R1 Pods move between sites.** Decision: a pod drag targets the nearest site within 24 points (not another pod's), or
  removal off the floor. Rationale: catalog levels allow pods only on their sites (R02-G20-02), so a free-form drop would
  always be refused; snapping to sites makes every drop either a legal change or nothing.
- **R2 Taps place on empty sites.** Decision: a tap on an empty site places a pod in the first free slot. Rationale: the
  quickest way to start; a pod has no other choice to make, so a tap is never ambiguous.
- **R3 Vents are taps.** Decision: a tap on a vent sends the other state. Rationale: "open or close canopy vents" is a
  binary choice; one tap is one action and undoable.
- **R4 The moonlight is a vertical drag on the moon.** Decision: 40 points of vertical travel per level, up raises,
  clamped 0 … 3, with the weather previewed while dragging and committed on release when the level differs.
  Rationale: "shift moonlight intensity" reads as a continuous shift over four steps; the preview shows its effect
  before committing.
- **R5 Preview is the kernel's run.** Decision: the preview runs the previewed arrangement with the kernel's own
  `MushroomWeatherForest.run`; nothing is approximated. Rationale: what the player sees before lifting is exactly what
  the commit gives; a catalog run is cheap enough to recompute per move.
- **R6 A cycle scrubber.** Decision: a track between the floor and the gauges maps its length to cycles 0 … cycles run.
  Rationale: reading the weather over time is how the player plans; the run is fixed-step and deterministic.
- **R7 Thresholds and orbit as feature 484.** Decision: the same tap, drag, double-tap and orbit numbers and the same
  arbitration (a second finger cancels and orbits). Rationale: every round-two game feels the same.
- **R8 Picking order as drawn.** Decision: vents over pods over sites (drawn later win); the moon is behind the forest;
  the scrubber has its own band; the floor is the rest of the floor rectangle. Rationale: what the finger seems to touch
  is what is picked.
- **R9 The refit includes the moon.** Decision: at a non-authored orbit the camera fits feature 493's box extended to
  z −0.5 … 0.3 (the moon stands at z −0.5), keeping the larger of the authored and the fitting eye distance.
  Rationale: the moon must stay in view while orbiting (SC-R02G2004-004), and at orbit 0 the authored camera already
  fits, so the refit is continuous and bit-identical there. Alternatives considered: refitting the authored camera
  too (would change feature 493's frame).
