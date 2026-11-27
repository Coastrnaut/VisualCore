# Research: R02-G21-06

- **R1 Feedback from the old and new core.** Decision: a pure plan (text, kind, haptic, trigger) from the old and new
  adapter core, as features 486 and 496. The run always ends the level and plans only its outcome; a ring, phase,
  luminosity or tilt action never ends it; a level or mode change plans "Level n, band b, <mode>." with 505's tutorial
  step text when shown (b the manifest entry's band). A world keeps its light when its report's longest lethal run is
  at most the lethal tolerance, its window at least the required window and its bloom `inside`. Rationale: exact
  tests; the presenter only routes. The trigger (the control, the bare refusal code, "hint" or "level") feeds the log.
- **R2 Lights eased by the frame clock.** Decision: glow, won and one bloom level per world ease (0.15 s; 0.45 s under
  Reduce Flashing, finishing before turning back); the first frame settles, every later change fades; the presenter
  owns the lights, so a tier change or a memory warning resets nothing. The lights follow the snapshot the scene draws
  (504's drawn snapshot, the preview applied), so the shells match the drawn worlds. Rationale: the programs already
  take `u_won` as 0 … 1 and a glow gain. Alternatives: a per-world bloom uniform (rejected: a GLSL change for 5 values).
- **R3 Shell factors in the glow mesh.** Decision: `glowPart` and `glowMesh` take optional bloom levels (nil keeps the
  0/1 factors bit for bit); the scene rebuilds the glow mesh when a bloom level crosses a 1/32 step or settles, at most
  once per drawn frame. Rationale: the factor is vertex data; 336 quads per rebuild only during a fade. Alternatives:
  rebuilding at a tenth (rejected: 0.1 steps of a shell read as small flashes under adversarial tick stepping).
- **R4 Fallback won look.** Decision: the fallback blends the colours of `systemPart(wonLevel: false)` and `(true)` by
  the won level (`blendedColours(off:on:level:)`, rebuilt at each tenth), as feature 496. Rationale: `wonLevel` changes
  colours only, so both parts share positions; level-2 has no glow shells, so the won level alone drives the look.
- **R5 Reduce Motion and Reduce Flashing.** Decision: the scene passes `motion(reduceMotion: reducedMotion ||
  reducedFlash)`, so coronas and motes hold their time-zero places under either setting; the glow cap stays
  `glowLimit(reduceFlashing:)`. Rationale: moving bright rays read as flicker; no Core or shader change. Alternatives:
  slowing them (rejected: still motion). The motes a won run adds appear with the outcome, as the band tints do.
- **R6 The audition recipe.** Decision: tone 220 Hz × 2^(n / 12), n = 2 × (7 − ring index clamped to 0 … 7); a star
  that can change (playing, and `BinaryGardensPuzzle(level:).moves(in:)` holds a ring, phase or luminosity move of it)
  with a fifth, one that cannot with a partial 3 Hz above, gain 0.04 each, 0.6 s linear decay; played on a change of
  the selected star (panel or 504's star tap) and after an accepted ring change of it, never for a preview.
  Rationale: outer rings sound lower, eight whole-tone steps; a stuck star beats.
- **R7 The ambient recipe.** Decision: as feature 496 with the quarters of the worlds keeping their light in place of
  the colonies in band, and a brightness partial at the root × 3 with the base amplitude × (i₁ + i₂) / (2 × (m − 1))
  when m > 1 and i₁ + i₂ > 0. Rationale: the same tested loop rules and player; the stars' brightness is heard.
- **R8 Panel accessibility.** Decision: adjustable star, ring, phase, luminosity, tilt and shown tick with the words of
  clarification Q5 (", locked" from the star's freedoms and T_max = 0); a summary element; a Sound toggle; system text
  styles; rows that become columns at accessibility sizes; a 520-point readable width on iPad; the refusal sentence of
  `BinaryGardensFeedbackPlan.refusalText(code:)` alone in place of "That change was refused: …". Rationale: as
  features 486 and 496; the − and + buttons already make the same moves, so the adjustables send the same actions.
- **R9 Tests that change on purpose.** Decision: `BinaryGardensRenderTests.aWonLevelBloomsEveryWorld` draws one frame
  at time 1 after the run before its time-0 checked frames (as feature 496 did in `MushroomWeatherRenderTests`); the
  identity test's refusal check passes unchanged (distinct words, prefix read); any 504 or 505 assertion of the old
  refusal line is updated in place. All are named in the tasks.
