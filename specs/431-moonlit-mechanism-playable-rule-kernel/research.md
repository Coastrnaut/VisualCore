# Research: R02-G14-01

- **R1 Whole-tooth phases.** Decision: a gear's phase is a whole tooth 0 … T − 1 and the handle turns one tooth at a
  time. Rationale: "angular phases constrained by integer tooth count" decided identically on every device; the gear
  ratio appears as the different periods of the gears' phases. Alternatives: angles in degrees (floating point); a
  common angular grid (hides the tooth-count constraint).
- **R2 Alternating directions.** Decision: a gear turns +1 when its distance from the driver is even and −1 when odd.
  Rationale: meshing gears turn opposite ways; a tree train makes every gear's distance unique.
- **R3 Mesh alignment modulo the common divisor.** Decision: a pair is aligned when (phaseₚ + phase_c) mod g = a, g =
  gcd(Tₚ, T_c) ≥ 2. Rationale: a turn changes the two phases by +s and −s, so the sum is invariant (the handle never
  jams a good machine) while a re-seat of one tooth changes it (the jam the player must avoid). g ≥ 2 keeps the
  constraint meaningful. Alternatives: a fixed tooth-in-gap parity (ignores the ratio); free re-seats (no mesh
  constraint at all).
- **R4 Slot tables and an integer light shift.** Decision: each gear has, per slot, a list of wall-cell offsets covered
  by a solid blade, and the lamp shifts a gear's cells down by height · depth rows. Rationale: "projected polygons
  transformed by light matrix" in exact integers; the generator of R02-G14-02 fills the slot tables from integer
  approximations of blade polygons, so the kernel never rasterises with floating point; depth gives parallax.
  Alternatives: rasterising polygons at play time (floating point at the boundary); a per-height table (larger levels).
- **R5 Decision order.** Decision: jam first, then key frames in order, within a key frame forbidden before missing
  before stray. Rationale: a jam decides the outcome before any key frame is judged (the report still lists every key
  frame's cast and counts as the truth metric); forbidden cells hold at every key frame; one fixed reporting order.
- **R6 Truth metric as a report.** Decision: alignment errors and per-key-frame covered, missing, stray and forbidden
  counts are reported after every action, never deciding by themselves. Rationale: the catalog's "angular relation
  error and target-mask overlap per frame", exact and shown to the player.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  phases, lamp height, actions spent, stage, failure) and records with previous and next fingerprints, as feature 421.
- **R8 Undo from failed.** Decision: undo from failed returns to playing and is recorded; a won level refuses undo.
