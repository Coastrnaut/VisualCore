# Research: R02-G11-01

- **R1 Grid chamber instead of continuous segments.** Decision: walls are whole unit cells of a W × H grid (W, H
  5 … 16). Rationale: "echoes based on static convex segments" decided alike on every device; a unit square is the
  simplest convex segment, and the catalog's solver is a "grid chamber generator". Alternatives: arbitrary line segments
  with floating-point ray casting (tolerances, device-dependent rounding).
- **R2 Four cardinal rays per pulse.** Decision: rays north, east, south, west, stepping cell by cell; travel distance =
  steps to the struck wall or border. Rationale: exact on the grid, nameable in words ("east: wall at 3 cells"), and
  enough to reveal the chamber over several pulses. Alternatives: eight rays (diagonal steps through wall corners are
  ambiguous); continuous angles (floating point).
- **R3 Beacon echoes as path lengths.** Decision: each beacon answers with its breadth-first path length through open
  cells (side steps only), reported sorted and unlabelled. Rationale: "raycast wave returns with path-length delay"
  around obstacles; unlabelled echoes make the triangulation a real deduction; the catalog solver's "connected-component
  and unique beacon inference proof" can certify that the echoes from some set of pulses pin every beacon. Alternatives:
  straight-line distances (ignore walls); labelled echoes (trivial).
- **R4 Delays in whole ticks.** Decision: 24 ticks per cell of distance (12 each way at 0.008333 s). Rationale:
  "deterministic time-of-flight per beam" as an exact integer the renderer can animate; it never decides a rule.
- **R5 Win, then energy.** Decision: after each accepted action, win (every beacon located) is judged before energy
  (zero energy with a beacon hidden fails). Rationale: a claim that locates the last beacon always wins. Since hits are free and energy only falls on
  pulses and misses, win and energy never meet on one action (found while testing, 2026-11-23); the closest case, a win
  with 1 energy left after a miss, is tested.
- **R6 Tolerance and nearest beacon.** Decision: a claim at column-or-row distance ≤ tolerance of an unlocated beacon
  locates the nearest such beacon (ties: lowest row, then lowest column); a claim near only located beacons is refused
  (noop); otherwise a miss spends min(miss cost, energy). Rationale: exact, deterministic, and a repeated claim is never
  charged.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  knowledge, markers, located beacons with their claims, energy, stage, failure) and records with previous and next
  fingerprints, as feature 391.
- **R8 Undo from failed.** Decision: undo from failed returns to playing and is recorded; a won level refuses undo.
  Rationale: clarification Q4; an honest retry is recorded so replay reproduces it.
