# Research: R02-G04-01

- **R1 Discrete wheel for the hue rule.** Decision: 96 bearings, 24 hue bands of 4 bearings; a direction's bearing is
  the sector between two fixed integer boundary vectors (cross-product test). Rationale: hue = (atan2(y, x) + offset)/2π
  computed in floating point can differ between devices at sector edges; a constant integer table decides the same
  everywhere. Alternatives: floating `atan2` with an epsilon (not exact); 360 bearings (finer than a swipe can select).
- **R2 Two independent clue channels.** Decision: hue gap (band distance) and fog depth (density sum along the shorter
  arc). Rationale: the source's "hue differences and optical depth; luminance independently perceivable"; a player who
  cannot separate hues still has the depth channel, drawn as luminance and symbols later. Alternatives: a single
  combined score (hides which channel carries the information).
- **R3 Allowance shared by probes and the selection.** Decision: both spend one unit; a probe spending the last unit
  fails. Rationale: makes "exhausted probes" an exact, explainable failure and guarantees a selection is always possible
  before it. Alternatives: unlimited selections (guessing wins).
- **R4 Turn-only undo.** Decision: undo and redo hold turns; probes and selections are permanent. Rationale: undoing a
  probe would refund a unit while keeping its information.
