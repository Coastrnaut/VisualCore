# Research: R02-G15-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 426 and 436. Rationale: exact tests; the presenter only routes. A turn that ends the level plans only
  its outcome.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain, and the
  fallback parts' `wonLevel`. Rationale: the programs already take `u_won` as 0 … 1 and a glow gain, and the fallback a
  won level, so only the presenter and the scene change. Alternatives: rebuilding meshes with fractional won flags every
  frame (rejected: per-frame rebuilds; the fallback is rebuilt only when the level moves by a tenth).
- **R3 Reduce Motion.** Decision: no change needed beyond keeping the fades: the programs have no time input and the
  geometry never previews a turn, so the solid is still between actions. Rationale: a fade is a brightness change,
  governed by Reduce Flashing.
- **R4 The audition recipe.** Decision: hinge h's tone 220 Hz × 2^((h − 1) / 12); a turnable hinge with its fifth, a
  hinge that swings nothing with a partial detuned by 3 Hz, gain 0.04 each, 0.6 s linear decay. Rationale: the player
  hears which hinge is chosen and hears an idle hinge as beating.
- **R5 The ambient recipe.** Decision: as feature 436 with the quarters of the cubes in place (the kernel's covered count
  over the cube count) in place of the covered quarters of the required target cells. Rationale: the same tested loop
  rules and player.
- **R6 Panel accessibility.** Decision: an adjustable hinge, a summary element, system text styles, wrapping rows, a
  520-point readable width on iPad. Rationale: as features 426 and 436.
