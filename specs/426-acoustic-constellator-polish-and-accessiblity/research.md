# Research: R02-G13-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 406 and 416. Rationale: exact tests; the presenter only routes. A listen always ends the level, so a
  listen plans only its outcome.
- **R2 Lights eased in presentation time, won lift through a uniform.** Decision: glow and won levels ease (0.15 s;
  0.45 s under Reduce Flashing, finishing before turning back); the won look is scaled by a `u_wonLight` uniform.
  Rationale: the `wonLink` material and the `.wonGlow` strips switch the brightness at once, which a fade cannot reach
  without a uniform.
  Alternatives: rebuilding the mesh with fractional won flags every frame (rejected: per-frame rebuilds).
- **R3 Reduce Flashing holds the tick.** Decision: the tick preview swaps teal and silver links and turns the hands every
  0.25 s, so under Reduce Flashing tick 0 is held, the stars do not pulse and no wave shell is drawn. Rationale: those
  swaps are sudden brightness changes at 4 Hz; holding the tick removes them without fading geometry.
- **R4 The audition recipe.** Decision: a link's two stars' tones, 220 Hz × 2^(rate / 12), gain 0.04 each, the
  second detuned by 1.5 Hz per step of the phase gap at the shown tick, 0.6 s linear decay. Rationale: the player hears
  the two natural rates and hears the gap as beating, which falls silent as the stars lock; short and quiet.
- **R5 The ambient recipe.** Decision: as feature 416 with the lit quarters of the coherence gauge in place of the
  steps reached. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: adjustable star and partner, a summary element, system text styles, wrapping rows,
  a 520-point readable width on iPad. Rationale: as features 406 and 416.
