# Research: R02-G03-06

- **R1 Plans as pure functions.** Decision: `WaveKnotKeeperFeedbackPlan.after(old:new:)` and `refused(code:)` return
  text, kind and haptic; the presenter only routes them. Rationale: exact-text tests on the host; the iOS layer stays
  thin. Alternatives: building texts in the view (untestable on the host).
- **R2 Outcome over selection.** Decision: one plan per change; a move that ends the play plans the outcome only.
  Rationale: the shared haptic planner drops extras within its interval, so a selection before an outcome could swallow
  the outcome.
- **R3 Eased lights with fade completion.** Decision: per-element levels eased linearly toward their targets (0.15 s, or
  0.45 s under Reduce Flashing); under Reduce Flashing a started fade completes before reversing. Rationale: bounded
  brightness change rate by construction (at most one half-range crossing per 0.45 s per element), measured by
  `maxHalfRangeCrossingsPerSecond`. Feature 316's proven rule.
- **R4 Crossing marks keyed by their segments.** Decision: a crossing mark's light is keyed by its two segment indices;
  the lights remember each mark's over-strand segment and the fraction along it where it was last drawn, so a mark that
  disappears after a move fades out at that fraction of the same (moved) segment, and a mark that appears fades in at its
  drawn crossing point. Rationale: the rope's geometry jumps one lattice step per move (that is the move itself, not a
  flash), but the ember caustic highlight must not switch on or off at once. Alternatives: one global caustic level
  (dims every crossing on any change, itself a brightness change); keeping the old geometry (draws a rope that no longer
  exists).
- **R5 Sound from the knot.** Decision: a root at 110 Hz × (1 + target crossings), a partial at 110 Hz × (1 + current
  crossings), a fifth above the root, writhe-distance-shaped gains, stage colouring; 8-second loop. Rationale: the chord
  resolves to a unison exactly when the crossings match, and the recipe is a pure function, so equal states sound equal.
- **R6 Sound lifecycle.** Decision: `WaveKnotKeeperSound` mirrors `LissajousLabyrinthSound` (wanted, on screen, active;
  a player injected for tests; the recipe offered at level openings, summary changes, play ends and when turned on).
  Rationale: one proven rule for every ambient experience.
- **R7 Pulse rate.** Decision: keep the 0.5 Hz caustic pulse at half gain under Reduce Flashing (already below 3 Hz) and
  still under Reduce Motion. Rationale: already compliant; changing it would alter feature 323's renders.
