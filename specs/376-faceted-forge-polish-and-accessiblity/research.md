# Research: R02-G08-06

- **R1 Feedback as a pure plan.** Decision: `FacetedForgeFeedbackPlan.after(old:new:)` derives the announcement and
  haptic from the old and new core. Rationale: exact host tests of texts and kinds; the presenter only routes. As
  features 356 and 366.
- **R2 Fades in presentation.** Decision: eased light levels for the cut-face glow and the sliver mark, never in the
  state. Rationale: the digest stays untouched; Reduce Flashing only lengthens the fade (0.45 s) and forbids reversing
  mid-fade.
- **R3 Drawing the levels.** Decision: the glow gain is multiplied by the eased glow level (the `u_glow` uniform) and
  the sliver cross's shade (uv.y of the crystal program) carries the eased sliver level. Rationale: no shader change.
- **R4 Ambient recipe.** Decision: root 110 Hz plus one partial per piece beyond the first, up to four (just-intonation
  ratios), an octave on a win, halved gains on a failure, a 12-second loop. Rationale: a pure function of the crystal's
  progress toward the target; synthesized; every partial has a whole number of cycles per loop.
- **R5 Preview choices are not announced.** Decision: the pickers are adjustable elements that speak their own values;
  only state changes are announced. Rationale: announcing every depth step would flood VoiceOver.
- **R6 Panel accessibility.** Decision: system text styles, wrapping rows, adjustable piece, direction and depth
  pickers, a summary element, a 520-point readable width on iPad. Rationale: Dynamic Type and Increase Contrast come
  from the system.
