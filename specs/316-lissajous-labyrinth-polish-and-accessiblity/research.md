# Research: R02-G02-06

- **R1 Plans as pure functions.** Decision: `LissajousLabyrinthFeedbackPlan.after(old:new:)` and `refused(code:)` return
  text, kind and haptic; the presenter only routes them. Rationale: exact-text tests on the host; the iOS layer stays thin.
  Alternatives: building texts in the view (untestable on the host).
- **R2 Outcome over selection.** Decision: one plan per change; a change that ends the play plans the outcome only.
  Rationale: the shared haptic planner drops extras within its interval, so a selection before an outcome could swallow
  the outcome.
- **R3 Eased lights with fade completion.** Decision: per-element levels eased linearly toward their targets (0.15 s, or
  0.45 s under Reduce Flashing); under Reduce Flashing a started fade completes before reversing. Rationale: bounded
  brightness change rate by construction (at most one half-range crossing per 0.45 s per element), measured by
  `maxHalfRangeCrossingsPerSecond`.
- **R4 Sound from the figure's ratio.** Decision: partials at 110 Hz × a and × b (a, b the frequencies), a fifth above the
  lower one, phase-shaped gains, stage colouring; 8-second loop. Rationale: the sound follows the same ratio as the
  figure and is a pure function, so equal states sound equal.
- **R5 Sound lifecycle.** Decision: `LissajousLabyrinthSound` mirrors Aurora Loom's `AuroraLoomSound` (wanted, on screen,
  active; a player injected for tests; the recipe offered at level openings, play ends and when turned on). Rationale: one
  proven rule for every ambient experience.
