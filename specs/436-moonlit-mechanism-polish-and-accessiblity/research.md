# Research: R02-G14-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 416 and 426. Rationale: exact tests; the presenter only routes. A run always ends the level, so a run
  plans only its outcome; a gear drag's several turns are planned once, from the core before the first turn to the core
  after the last.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain.
  Rationale: the programs already take `u_won` as 0 … 1 and a glow gain, so only the presenter and the fallback's paper
  lift change. Alternatives: rebuilding meshes with fractional won flags every frame (rejected: per-frame rebuilds).
- **R3 Reduce Motion.** Decision: no change needed beyond keeping the fades: the programs have no time input and the
  geometry never previews a turn, so the machine is still between actions. Rationale: a fade is a brightness change,
  governed by Reduce Flashing.
- **R4 The audition recipe.** Decision: a gear's tone 220 Hz × 2^((T − 12) / 12), clamped to two octaves; the chosen gear
  and its parent at gain 0.04 each, the second detuned by 1.5 Hz per tooth of mesh error, 0.6 s linear decay; the driver
  alone. Rationale: the player hears the tooth counts and hears a misaligned mesh as beating.
- **R5 The ambient recipe.** Decision: as feature 426 with the covered quarters of the required target cells in place of
  the lit coherence quarters. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: adjustable gear and key frame, a summary element, system text styles, wrapping
  rows, a 520-point readable width on iPad. Rationale: as features 416 and 426.
