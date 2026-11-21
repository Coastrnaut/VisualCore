# Research: R02-G04-06

- **R1 Plans as pure functions.** Decision: `HueCompassFeedbackPlan.after(old:new:)`, `picked(band:)` and
  `refused(code:)` return text, kind and haptic; the presenter only routes them. Rationale: exact-text tests on the
  host; the iOS layer stays thin. Alternatives: building texts in the view (untestable on the host).
- **R2 Outcome over selection.** Decision: one plan per change; an action that ends the play (a selection, or a probe
  that spends the last unit) plans the outcome only. Rationale: the shared haptic planner drops extras within its
  interval, so a selection haptic before an outcome could swallow the outcome.
- **R3 Eased lights with fade completion.** Decision: per-element levels eased linearly toward their targets (0.15 s, or
  0.45 s under Reduce Flashing); under Reduce Flashing a started fade completes before reversing. Rationale: bounded
  brightness change rate by construction (at most one half-range crossing per 0.45 s per element), measured by
  `maxHalfRangeCrossingsPerSecond`. Feature 316's and 326's proven rule.
- **R4 Marks keyed by bearing.** Decision: a probe mark's light is keyed by its bearing; the selection mark and the
  target ring remember the bearing they were last drawn at, so a mark that disappears (a retry, a level change) fades
  out where it was, and a new one fades in where it appears. The level scales the mark's size (0 … 1 of its radius):
  a shrinking glass mark changes the drawn brightness smoothly. Rationale: no shader or colour stream change (the scene
  has no per-vertex alpha for glass marks). Alternatives: alpha per mark (a new uniform per mark draw).
- **R5 Win glow.** Decision: the needle's glow shells' gain is `standardGain × (1 + glow)`, clamped by the existing
  `u_gainLimit` (0.5 under Reduce Flashing). Rationale: the win is a fade of the existing glow, capped.
- **R6 Sound from the clue.** Decision: root 110 Hz; a partial at 110 Hz × (1 + g / 12) for the last hue gap g (unison
  at g = 0 or no clue); a fifth above the root; gains × (1 − 0.4 · min(d, 90) / 90) for fog depth d; a brighter octave
  when won, halved gains when failed; an 8-second loop. Rationale: the chord resolves to a unison exactly when the probe
  lies in the target's band, and the recipe is a pure function, so equal clues sound equal.
- **R7 Sound lifecycle.** Decision: `HueCompassSound` mirrors `WaveKnotKeeperSound` (wanted, on screen, active; a
  player injected for tests; the recipe offered at level openings, new clues, play ends and when turned on). Rationale:
  one proven rule for every ambient experience.
- **R8 Drift rate.** Decision: keep the 0.1 Hz fog drift (already below 3 Hz), held still under Reduce Motion.
  Rationale: already compliant; changing it would alter feature 333's renders.
