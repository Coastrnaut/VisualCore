# Research: R02-G02-04

- **R1 A dial-independent stage.** Decision: `stageBounds(level:)` is the bounding sphere of the amplitude box
  (±amplitude per axis, grown by `pathMargin`) and every checkpoint and obstacle ball; every path of the level lies in
  it whatever the dials. The rings are laid out against it, and the camera fits the sphere around the stage and the
  rings. Rationale: the snapshot bounds move with every action, which would make the rings and the camera jump under
  the finger. Alternative rejected: rings against the snapshot bounds (handles move while turning).
- **R2 Ring layout.** Decision: four rings in a column along the authored camera's up vector, offset along its right
  vector by 1.35 R from the stage centre (R the stage radius), ring radius 0.18 R, centres 0.45 R apart, ordered
  frequencyA, frequencyB, phaseA, phaseC from top; each ring's plane faces the authored eye direction. Knob angle =
  value · 40° (frequencies) or value · 22.5° (phases), measured from the ring's up direction clockwise as seen from the
  eye. Rationale: one control per dial with the same ring metaphor as Aurora Loom; the authored view sees every ring
  face-on.
- **R3 Turn mapping.** Decision: rings are R02-F22 rotation handles dragged with `HandleDrag(.plane(normal))`; the turned
  angle is accumulated from successive plane points (so a turn past 180° is counted) and the candidate is start +
  round(angle / step), clamped 1 … 9 for frequencies and modulo 16 for phases. Rationale: the shared controls handle
  grazing angles and picking; accumulation makes full turns work for phases.
- **R4 One action per gesture.** Decision: the candidate is previewed and one `dial.set [index, value]` is sent on
  release when it differs from the start. Rationale: the allowance counts committed actions (as R02-G01-04 R2).
- **R5 Arbitration.** Decision: the state machine of R02-G01-04 R3 (idle, turning, orbiting, cancelled); handles answer
  only while the stage is `playing`. Rationale: deterministic and scriptable.
- **R6 Orbit.** Decision: `LissajousLabyrinthOrbit(azimuthOffset −40° … 40°, elevation 10° … 60°)` around the authored
  azimuth atan2(0.55, 1.0) ≈ 28.8° with the authored elevation asin(0.45 / |(0.55, 0.45, 1)|) ≈ 21.5°; the distance is the
  existing closed-form sphere fit (`distance(radius:aspect:)`), which holds for every direction because the fitted
  content is a sphere. Rationale: the 5 % margin at every orbit and aspect follows from the same formula, no bisection
  needed.
- **R7 Pending values and Apply order.** Decision: `LissajousLabyrinthPending` holds a value per dial; `actions(from:)`
  lists one action per changed dial in the order frequencyA, frequencyB, phaseA, phaseC, except that when both
  frequencies change and (a′, b) is not coprime but (a, b′) is, frequencyB goes first; when neither order keeps the
  pair coprime, the list starts with the refused action so Apply stops with the reason. Tests check that for all 100
  certified levels setting the certified solution's final dials as pending and applying wins in exactly the certified
  shortest number of actions (verified 2026-11-21: no certified solution changes a dial twice, and every level with both
  frequencies changed has a coprime order). Rationale: the lesson of R02-G01-09 (a panel-only player must be able to win).
- **R8 Selection.** Decision: the controller owns the selected dial (picked ring or a stepper); the presenter mirrors it
  for the outline and the description. Rationale: one source of truth, host-tested.
