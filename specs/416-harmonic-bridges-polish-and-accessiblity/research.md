# Research: R02-G12-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as feature 406. Rationale: exact tests; the presenter only routes. A test always ends the level, so a test plans
  only its outcome.
- **R2 Lights eased in presentation time, won lift through a uniform.** Decision: glow and won levels ease (0.15 s;
  0.45 s under Reduce Flashing, finishing before turning back); the won lift is scaled by a `u_wonLight` uniform.
  Rationale: the per-vertex won flag switches the brightness at once, which a fade cannot reach without a uniform.
  Alternatives: rebuilding the mesh with fractional won flags every frame (rejected: per-frame rebuilds).
- **R3 Reduce Flashing holds the step.** Decision: the shown step's 1.2 s cycle swaps the membranes drawn, so under
  Reduce Flashing the resting step is held, the strings rest and no wave shell is drawn. Rationale: membrane swaps are
  sudden brightness changes at 0.83 Hz; holding the step removes them without fading geometry.
- **R4 The audition recipe.** Decision: the fundamental 110 Hz × 2^((peg − 1) / 12) with one partial per resonant mode at
  the fundamental × n, gain 0.04 × w, 0.6 s linear decay; a muted pluck when no mode sounds. Rationale: the player hears
  the harmonics that make the string resonate, in pitch order of the pegs; short and quiet.
- **R5 The ambient recipe.** Decision: as feature 406 with the steps reached in place of the beacons located and the
  actions left in place of the energy. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: adjustable string and peg, a summary element, system text styles, wrapping rows,
  a 520-point readable width on iPad. Rationale: as feature 406.
