# Research: R02-G18-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic) from the old and new adapter
  core, as features 456 and 466. Rationale: exact tests; the presenter only routes. The play always ends the level and
  plans only its outcome; a tuning (periapsis or size) never ends it.
- **R2 Lights eased by the frame clock.** Decision: glow and won levels ease (0.15 s; 0.45 s under Reduce Flashing,
  finishing before turning back); the scene passes the won level as `u_won` and the glow level times the gain, and the
  fallback compass blends the colours of its not-won and won parts by the won level. Rationale: the programs already
  take `u_won` as 0 … 1 and a glow gain; `compassPart(_:tier:wonLevel:camera:)` takes a won flag (`Bool?`, audited
  2026-11-26) and the won look moves no position (the geometry header: a won level changes only the fallback colours of
  the gauge marks), so blending the two parts' colours vertex by vertex fades it with only the presenter and the scene
  changed. Alternatives: rebuilding meshes with fractional won flags every frame (rejected: per-frame rebuilds; the
  fallback is rebuilt only when the level moves by a tenth).
- **R3 Reduce Motion and Reduce Flashing.** Decision: the scene asks `starPulse(time:reduceMotion:)` with Reduce Motion
  or Reduce Flashing set, so the star holds at 1 and the sky is still between actions under either. Rationale: the
  pulse is the only time input of the programs; a fade is a brightness change, governed by Reduce Flashing.
  Alternatives: keeping the pulse under Reduce Flashing (rejected: two frames of the same state would differ).
- **R4 The audition recipe.** Decision: the pending orbit's tone 220 Hz × 2^(n / 12), n = (48 − a) / 4 rounded down
  (0 … 10); an orbit that can be set with a fifth (k ≤ 7) or a fourth (k ≥ 8), one that cannot with a partial detuned
  by 3 Hz, gain 0.04 each, 0.6 s linear decay. Rationale: the player hears the size (larger is lower, as a longer
  period), hears round and eccentric orbits as different intervals and an orbit that cannot be set as beating; eleven
  size steps a semitone apart stay distinct. Alternatives: a tone per direction (rejected: 24 directions would crowd two
  octaves and the direction is read in words).
- **R5 The ambient recipe.** Decision: as feature 466 with the quarters of the targets met in order (met over target
  count) in place of the eclipses matched. Rationale: the same tested loop rules and player.
- **R6 Panel accessibility.** Decision: adjustable pending eccentricity, direction and size, a summary element, system
  text styles, wrapping rows, a 520-point readable width on iPad. Rationale: as features 456 and 466; the pending orbit
  of R02-G18-04 is already moved by − and +, so the adjustables perform the same moves.
