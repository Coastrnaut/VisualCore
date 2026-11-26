# Research: R02-G19-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 466 and 476. Rationale: exact tests; the presenter only routes. The play always ends the level and
  plans only its outcome; a placement or removal never ends it.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain, and the
  fallback dish blends the colours of its not-won and won parts by the won level. Rationale: the programs already take
  `u_won` as 0 … 1 and a glow gain; `dishPart(_:tier:wonLevel:camera:)` takes a won flag (`Bool?`, audited 2026-11-26)
  and the won look moves no position, so blending the two parts' colours vertex by vertex fades it with only the
  presenter and the scene changed. Alternatives: rebuilding meshes with fractional won flags every frame (rejected:
  per-frame rebuilds; the fallback is rebuilt only when the level moves by a tenth).
- **R3 Reduce Motion and Reduce Flashing.** Decision: nothing else is needed: the dish has no time input (the shown
  tick is presentation state set by actions), so two frames of the same state are identical once any fade has finished.
  Rationale: the scene's file header and its rebuild key read no time. Alternatives: adding a pulse (rejected: not in
  the design).
- **R4 The audition recipe.** Decision: the selected well's tone 220 Hz × 2^(n / 12), n = 3 × (strength − 1) (0 … 9); a
  well that can be placed with a fifth (clockwise) or a fourth (counterclockwise), one that cannot with a partial
  detuned by 3 Hz, gain 0.04 each, 0.6 s linear decay. Rationale: the player hears the strength (stronger is higher, a
  minor third apart, four distinct steps), hears the two senses as different intervals and a well that cannot be placed
  as beating. Alternatives: a tone per site (rejected: sites are read in words, and up to six sites would crowd the
  range).
- **R5 The ambient recipe.** Decision: as feature 476 with the quarters of the needed stencil cells lit (lit over the
  cells the coverage needs) in place of the targets met. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: adjustable slot, site and strength, a sense toggle with its value, a summary
  element, system text styles, wrapping rows, a 520-point readable width on iPad. Rationale: as features 466 and 476;
  the panel's − and + already move the selection, so the adjustables perform the same moves.
