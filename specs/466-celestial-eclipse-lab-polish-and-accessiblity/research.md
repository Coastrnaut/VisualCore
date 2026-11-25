# Research: R02-G17-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 446 and 456. Rationale: exact tests; the presenter only routes. The run always ends the level and
  plans only its outcome; a phase change never ends it.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain, and the
  fallback sky blends the colours of its not-won and won parts by the won level. Rationale: the programs already take
  `u_won` as 0 … 1 and a glow gain; the fallback geometry takes a won flag (`wonLevel: Bool?`, found at implement) and
  the won look moves no position, so blending the two parts' colours vertex by vertex fades it with only the presenter
  and the scene changed. Alternatives: rebuilding meshes with fractional won flags every
  frame (rejected: per-frame rebuilds; the fallback is rebuilt only when the level moves by a tenth).
- **R3 Reduce Motion and Reduce Flashing.** Decision: the scene asks `haloPulse(time:reduceMotion:)` with Reduce Motion
  or Reduce Flashing set, so the halos hold at 1 and the sky is still between actions under either. Rationale: the
  pulse is the only time input of the programs; a fade is a brightness change, governed by Reduce Flashing.
  Alternatives: keeping the pulse under Reduce Flashing (rejected: two frames of the same state would differ).
- **R4 The audition recipe.** Decision: body j's tone 220 Hz × 2^(2j / 12); a body in an eclipse of the predicted
  timeline with its fifth, one in none with a partial detuned by 3 Hz, gain 0.04 each, 0.6 s linear decay. Rationale:
  the player hears which body is chosen and hears an uninvolved one as beating; six bodies a whole tone apart stay
  distinct.
- **R5 The ambient recipe.** Decision: as feature 456 with the quarters of the target matched in order (matched over
  target count) in place of the quarters of the symbol drawn. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: an adjustable chosen body and pending phase, a summary element, system text
  styles, wrapping rows, a 520-point readable width on iPad. Rationale: as features 446 and 456.
