# Research: R02-G10-01

- **R1 Integer samples instead of floating-point signals.** Decision: samples are signed integers in −64 … 64 (one unit
  is 1/64 of the aurora's half-height). Rationale: "signed fixed precision" decided alike on every device; every bend
  and distance stays far inside `Int`. Alternatives: `Double` samples (tolerances, device-dependent rounding).
- **R2 Bend as the second difference.** Decision: b(k) = s(k − 1) − 2·s(k) + s(k + 1) at interior positions.
  Rationale: the discrete curvature of a sampled curve; exact; a reversal changes only the bends at positions i − 1, i,
  j and j + 1 (the bends strictly inside are carried along in reverse order), so a tear is local and nameable.
  Alternatives: first difference (slope, which a reversal negates inside the section and so does not stay local).
- **R3 Target as a reordering.** Decision: the target holds exactly the multiset of the opening heights; a level whose
  target is not a reordering is refused. Rationale: a reversal only reorders samples, so any other target is
  unreachable and could never be certified.
- **R4 Tear, then win, then budget.** Decision: judged after each accepted reversal in that order. Rationale: a tear is
  always a failure; a win on the last reversal counts. Since B ≥ L, a torn wave is never smooth, so tear and win never
  meet on one reversal (found while testing, 2026-11-22); a tearing reversal that matches every checkpoint is a tear.
- **R5 Bounds inclusive.** Decision: |b| ≤ L is smooth; |b| ≤ B survives; |b| = B + 1 tears. Rationale: the boundary
  cases of SC-R02G1001-004 are one unit either side.
- **R6 Distance as an exact fraction.** Decision: (Σ|s − t|, Σ|t|), reported unreduced, 0/1 when Σ|t| = 0, with the
  worst bend; never deciding. Rationale: the catalog's "normalized signal edit distance and continuity" with no
  rounding.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  wave, reversals spent, stage, failure) and records with previous and next fingerprints, as feature 381.
- **R8 Undo from failed.** Decision: undo from failed returns to playing and is recorded; a won level refuses undo.
  Rationale: clarification Q4; an honest retry is recorded so replay reproduces it.
