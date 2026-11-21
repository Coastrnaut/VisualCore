# Research: R02-G05-06

- **R1 Plans as pure functions.** Decision: `ColorfallCanyonsFeedbackPlan.after(old:new:)`, `picked(cell:columns:)` and
  `refused(code:)` return text, kind and haptic; the presenter only routes them. Rationale: exact-text tests on the host;
  the iOS layer stays thin. Alternatives: building texts in the view (untestable on the host).
- **R2 Outcome over selection.** Decision: one plan per change; an action that ends the play (a step that wins or fails)
  plans the outcome only. Rationale: the shared haptic planner drops extras within its interval, so a selection haptic
  before an outcome could swallow the outcome.
- **R3 Eased lights with fade completion.** Decision: per-element levels eased linearly toward their targets (0.15 s, or
  0.45 s under Reduce Flashing); under Reduce Flashing a started fade completes before reversing. Rationale: bounded
  brightness change rate by construction, measured by `maxHalfRangeCrossingsPerSecond`; features 316, 326 and 336.
- **R4 Sheets keyed by cell.** Decision: a sheet's light is keyed by its cell and holds the brightness target of
  feature 343 (0.35 + 0.65 · min(volume, 24) / 24, 0 when empty) and the last colour weights it was drawn with, so a cell
  that empties fades out in its last colour and a filling cell fades in; an emitter's light is its brightness (1 flowing,
  0.3 not). The fluid stream's brightness slot carries the eased level. Rationale: no shader or stream change.
- **R5 Win glow.** Decision: the glow shells' gain is `standardGlowGain × (1 + glow)`, clamped by the existing
  `u_glowLimit` (0.5 under Reduce Flashing). Rationale: the win is a fade of the existing glow, capped.
- **R6 Sound from the basins.** Decision: root 98 Hz; cyan 98 × 3/2, coral 98 × 5/4, yellow 98 × 2, each with gain
  base × (0.3 + 0.7 · its share of all basin mass) when that colour is in a basin; a brighter octave when won, halved
  gains when failed; a 10-second loop. Rationale: the chord shows which colours have arrived; a pure function, so equal
  basins sound equal.
- **R7 Sound lifecycle.** Decision: `ColorfallCanyonsSound` mirrors `HueCompassSound` (wanted, on screen, active; a player
  injected for tests; the recipe offered at level openings, changes of the basins or stage and when turned on).
- **R8 Band rate.** Decision: keep the flow bands at 0.5 (1 on waterfalls) cycles per second with depth 0.35, already
  below 3 per second, held still under Reduce Motion. Rationale: compliant; changing it would alter feature 343's renders.
