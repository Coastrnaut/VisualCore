# Research: R02-G06-06

- **R1 Feedback as a pure plan.** Decision: `ChronoConstellatorFeedbackPlan.after(old:new:)` derives the announcement and
  haptic from the old and new core. Rationale: exact host tests of texts and kinds; the presenter only routes. As
  features 336 and 346.
- **R2 Fades in presentation.** Decision: eased light levels per ring, node and mark, never in the state. Rationale: the
  digest stays untouched; Reduce Flashing only lengthens the fade (0.45 s) and forbids reversing mid-fade.
- **R3 Drawing the levels.** Decision: ring shade (uv.y of the field program) and node colour (glow stream) carry the
  eased levels; the win glow scales the glow gain; the collision mark's shade fades. Rationale: no shader change.
- **R4 Ambient recipe.** Decision: root 110 Hz plus one partial per star on target (just-intonation ratios by star),
  octave on a win, halved gains on a failure, a 12-second loop. Rationale: a pure function of the visible goal; synthesized.
- **R5 Panel accessibility.** Decision: system text styles, wrapping rows, an adjustable star picker, a summary element,
  a 520-point readable width on iPad. Rationale: Dynamic Type and Increase Contrast come from the system.
