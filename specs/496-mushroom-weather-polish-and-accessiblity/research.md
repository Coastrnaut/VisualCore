# Research: R02-G20-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 476 and 486. Rationale: exact tests; the presenter only routes. The run always ends the level and
  plans only its outcome; a pod, vent or moonlight action never ends it.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as the won uniform and the glow level times the gain,
  and the fallback forest blends the colours of its not-won and won parts by the won level. Rationale: the programs
  already take the won uniform as 0 … 1 and a glow gain, and the won look moves no position, so blending the two parts'
  colours vertex by vertex fades it with only the presenter and the scene changed. Alternatives: rebuilding meshes
  with fractional won flags every frame (rejected: per-frame rebuilds; the fallback is rebuilt only when the level
  moves by a tenth).
- **R3 Reduce Motion and Reduce Flashing.** Decision: the scene passes motion 0 to the shaders under either setting, so
  droplets and motes hold their time-zero places; everything else (the mist, caps, gauges, the shown cycle) changes only
  with actions. Rationale: feature 493 already stops them under Reduce Motion; Reduce Flashing also keeps the forest
  still because moving bright droplets read as flicker. Alternatives: slowing them (rejected: still motion).
- **R4 The audition recipe.** Decision: the selected site's tone 220 Hz × 2^(n / 12), n = 2 × site index (0 … 14); a
  site that can take a pod with a fifth, one that cannot with a partial detuned by 3 Hz, gain 0.04 each, 0.6 s linear
  decay. Rationale: the player hears which site is selected (later sites higher, a whole tone apart, up to eight
  distinct steps) and hears a site that cannot take a pod as beating. Alternatives: a tone per pod slot (rejected: the
  site is what the placement decides).
- **R5 The ambient recipe.** Decision: as feature 486 with the quarters of the colonies staying in band in place of the
  stencil cells lit, and a moonlight partial at the root × 3 with gain proportional to the moonlight. Rationale: the
  same tested loop rules and player; the moonlight is the game's third control and is heard.
- **R6 Panel accessibility.** Decision: adjustable slot, site and moonlight, a toggle per vent with its value, a summary
  element, system text styles, wrapping rows, a 520-point readable width on iPad. Rationale: as features 476 and 486;
  the panel's − and + already move the selection, so the adjustables perform the same moves.
