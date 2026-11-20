# Research: R02-G02-01

- **R1 Integer trigonometry.** Decision: a table of 4,096 integers, round(1,024 · sin(2πk/4,096)), stored as Swift source
  and pinned by a SHA-256 test; a test also checks every entry within one unit of `Foundation.sin`. Rationale: identical on
  every device and in every build; the source allows tolerance bands but prefers canonical quantized state. Alternatives:
  `Double` sin at run time (bitwise differences across libm versions would change verdicts at boundaries); CORDIC (more
  code for the same table).
- **R2 Lap and time.** Decision: 4,096 ticks of 1/240 s per lap; angles in 1/4,096 turns; integer frequencies.
  Rationale: with gcd(a, b) = 1 the path closes after exactly 4,096 ticks (the fundamental period), so "a complete lap" is
  exact. 1/240 s is the source's 0.004167 s; a lap lasts about 17 s, matching the "slow-motion flower".
- **R3 Swept contact.** Decision: per segment (sample n → n + 1, wrapping), exact integer closest-point test: with
  d = q − p and w = c − p, contact iff (w·d ≤ 0 ? |w|² < r² : w·d ≥ |d|² ? |c − q|² < r² : |w|²·|d|² − (w·d)² < r²·|d|²).
  Rationale: the source's "segment-swept collision tests"; exact, no division, fits Int64.
- **R4 Ordered checkpoints.** Decision: one pointer scanned over ticks; a checkpoint is visited at the first sample inside
  or on it after the previous one was visited; at most one per tick. Rationale: "visited in order" without ambiguity when
  checkpoints overlap.
- **R5 Coprime dials.** Decision: an action that makes gcd(frequencyA, frequencyB) > 1 is refused (`not-coprime`).
  Rationale: the source's "counterexample that violates coprime frequency ratios" and INV-02 ("makes frequency invalid");
  a non-coprime pair retraces a shorter curve and would make "the fundamental period" ambiguous.
- **R6 Undo refunds.** Decision: as Aurora Loom (R02-G01-01 R4). Rationale: a shared, documented convention across games.
- **R7 Puzzle contract.** Decision: `LissajousLabyrinthRules: PuzzleRules` over the four dials. Rationale: R02-G02-02 can
  certify levels with R02-F23's validator; the state space is 9 × 9 × 16 × 16 = 20,736 (fewer when coprime).
