# Research: R02-G07-06

- **R1 Feedback as a pure plan.** Decision: `AmethystEscapeFeedbackPlan.after(old:new:)` derives the announcement and
  haptic from the old and new core. Rationale: exact host tests of texts and kinds; the presenter only routes. As
  features 346 and 356.
- **R2 Fades in presentation.** Decision: eased light levels for the pearl glow, the exit glow and the failed wedge,
  never in the state. Rationale: the digest stays untouched; Reduce Flashing only lengthens the fade (0.45 s) and forbids
  reversing mid-fade.
- **R3 Drawing the levels.** Decision: the failed wedge's amber shade (uv.y of the crystal program) and the glow weights
  (uv.x of the glow stream) carry the eased levels. Rationale: no shader change.
- **R4 Ambient recipe.** Decision: root 98 Hz plus one partial per shell the pearl has passed (just-intonation ratios),
  octave on a win, halved gains on a failure, a 12-second loop. Rationale: a pure function of the pearl's progress
  outward; synthesized.
- **R5 Multi-sector drags.** Decision: one announcement and one selection haptic after the drag's last turn, describing
  the whole turn. Rationale: a burst of per-sector announcements would be dropped by the rate limit anyway and confuses
  VoiceOver.
- **R6 Panel accessibility.** Decision: system text styles, wrapping rows, an adjustable shell picker, a summary element,
  a 520-point readable width on iPad. Rationale: Dynamic Type and Increase Contrast come from the system.
