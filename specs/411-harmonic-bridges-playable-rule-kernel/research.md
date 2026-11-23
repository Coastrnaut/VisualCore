# Research: R02-G12-01

- **R1 Exact standing waves at sixth points.** Decision: the swing is evaluated at the five interior points of six
  equal segments, where 4 sin²(nπk/6) is 0, 1, 3 or 4 for every mode n in 1 … 5. Rationale: the law
  y(x,t) = Σ A_n sin(nπx/L) cos(ω_n t + φ_n) then gives an exact integer mean square on every device; six segments are
  enough to show nodes (modes 2, 3 and 4 have interior nodes, modes 1 and 5 none). Alternatives: finer sampling
  (irrational squared sines, floating point); a continuous envelope (device-dependent rounding).
- **R2 Time average as a sum of mean squares.** Decision: tones of one step have distinct frequencies, so the time
  average of the squared displacement is the sum of each resonating tone's mean square, weighted by its strength.
  Rationale: the "time-averaged envelope" of the catalog, exactly; phases φ_n drop out of the average.
- **R3 Rational resonance.** Decision: a string's harmonics are n · p / L; a tone F resonates mode n exactly when
  n · p = F · L with n in 1 … 5. Rationale: "discrete rational string-mode search" in whole numbers; the peg is the
  player's one control per string. Alternatives: tension and density as real numbers (floating point).
- **R4 Bridge per step, reachability over the window.** Decision: a string is a bridge in a step when every sample's
  swing reaches the threshold; a test wins when the goal is reachable in every step of the window. Rationale: "start to
  goal reachability sustained for required window" and "bridge breaks during a crossing-window step" in exact terms.
- **R5 Test, then budget.** Decision: a test is decided first (win, or failure naming the step and string); after any
  other accepted action a spent budget fails. Rationale: a test on the last action can still win.
- **R6 Broken string.** Decision: the lowest-index non-bridge string across the cut between the start's reachable set
  and the rest in the first failing step (none when no string crosses). Rationale: deterministic and honest: the named
  string is one whose bridge would extend the start's reach.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint, pegs,
  actions spent, stage, failure) and records with previous and next fingerprints, as feature 401.
- **R8 Undo from failed.** Decision: undo from failed returns to playing and is recorded; a won level refuses undo.
