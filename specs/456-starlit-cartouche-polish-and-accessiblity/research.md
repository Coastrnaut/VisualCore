# Research: R02-G16-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 426 and 436. Rationale: exact tests; the presenter only routes. A leg that ends the level plans only
  its outcome.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain, and the
  fallback parts' `wonLevel`. Rationale: the programs already take `u_won` as 0 … 1 and a glow gain, and the fallback a
  won level, so only the presenter and the scene change. Alternatives: rebuilding meshes with fractional won flags every
  frame (rejected: per-frame rebuilds; the fallback is rebuilt only when the level moves by a tenth).
- **R3 Reduce Motion.** Decision: no change needed beyond keeping the fades: the programs have no time input and the
  firmament's turn and the ship's glide stop under Reduce Motion, so the chart is still between actions. Rationale: a
  fade is a brightness change, governed by Reduce Flashing.
- **R4 The audition recipe.** Decision: star j's tone 220 Hz × 2^(j / 12); a reachable star with its fifth, an
  unreachable one with a partial detuned by 3 Hz, gain 0.04 each, 0.6 s linear decay. Rationale: the player hears which
  star is chosen and hears an unreachable one as beating.
- **R5 The ambient recipe.** Decision: as feature 446 with the quarters of the symbol drawn (strokes drawn over symbol
  strokes) in place of the quarters of the strokes drawn. Rationale: the same tested loop
  rules and player.
- **R6 Panel accessibility.** Decision: an adjustable destination and wait, a summary element, system text styles,
  wrapping rows, a 520-point readable width on iPad. Rationale: as features 426 and 436.
