# Research: R02-G14-04

- **R1 Projected-target picking.** Decision: the lamp and ladder, the key-frame cards and the gear discs are projected
  through the drawn camera and picked in that order (22-point targets; a gear by its outline circle grown by 8 points,
  the front-most first). Rationale: the lamp and cards are small and lie in front of or beside the gears, so they must
  win over the large gear discs; distances in view points give every target the same touch size at every orbit.
  Alternatives: a ray against the wall plane with world tolerances (rejected: the lamp sits 0.95 in front of the wall).
- **R2 Rotary drag turns the train.** Decision: the clockwise swept angle about the dragged gear's projected centre,
  divided by one of its teeth and rounded, gives n; the handle step is direction(gear) × sign(n); |n| capped at the
  actions left; a 12-point dead zone at the centre. Rationale: every gear moves one of its own teeth per handle turn,
  so the dragged gear follows the finger tooth for tooth whichever gear is touched; the dead zone stops angle jumps.
  Alternatives: horizontal drag anywhere (rejected: no direct tie between finger and gear); sending turns while
  dragging (rejected: a drag would spend actions the player did not mean to).
- **R3 Lamp drag by fixed screen distance.** Decision: 24 points of vertical travel per rung. Rationale: a projected
  rung is about 10 points on a phone, too small to drag reliably. Alternatives: projected rung spacing (rejected).
- **R4 Run by tapping the lamp.** Decision: a lamp tap sends `machine.run`. Rationale: the lamp is what casts the
  shadows the run judges; the earlier games test where the verdict is drawn. Alternatives: a hold anywhere (rejected:
  holds are kept for irreversible commits).
- **R5 Re-seat by double tap.** Decision: the second tap of a double tap on a gear sends `gear.reseat [g, +1]`, nothing on
  the driver. Rationale: two fingers already orbit (feature 424), so a twist cannot be used; the first tap chooses the
  gear, which is harmless. Alternatives: a long press (rejected: slow and undiscoverable).
- **R6 Orbit and reset.** Decision: yaw ±25°, pitch −10° … +15°, refitted per aspect and orbit; double tap on empty
  space or "Reset view". Rationale: the wall faces the camera, so wider angles foreshorten the shadows; 424's pattern.
- **R7 Panel parity.** Decision: every certified witness replays through the panel (turn, gear, re-seat, lamp, run).
  Rationale: R2-F26's accessible control path.
