# Research: R02-G02-02

- **R1 Deciding every setting.** Decision: enumerate all 55 coprime (a, b) pairs × 256 (φ, ψ) pairs and decide each with
  the kernel's exact `LissajousLabyrinthLap.verdict`, after a prefilter. Rationale: the source names exhaustive enumeration
  with segment-swept collision tests; 14,080 settings are few. Alternatives: gradient or sampling search (cannot prove a
  level has no shorter solution).
- **R2 Sound prefilter.** Decision: a checkpoint can only be visited at a tick whose sample lies in its axis-aligned box;
  x(n) depends on (a, φ), y(n) on b, z(n) on ψ, so per checkpoint three tables of 4,096-tick bit sets (144, 9 and 16 sets)
  are ANDed per setting; an empty result for any checkpoint proves a loss. Rationale: exact (never discards a winner),
  cheap, and leaves the full verdict as the only judge. Alternatives: no prefilter (≈ 14,080 full laps per level, too slow
  in debug tests); a bounding-sphere filter (weaker).
- **R3 Shortest path.** Decision: breadth-first search over legal states using `LissajousLabyrinthRules.moves` (single-dial
  changes keeping coprime frequencies) from the start until the first depth containing a winning setting; ties by the
  winning setting (a, b, φ, ψ) ascending; the action list from parent pointers recorded in the rules' move order.
  Rationale: one action may set any value, so depth ≤ 4 except where a non-coprime intermediate forces a detour; BFS
  handles both exactly.
- **R4 Building a candidate.** Decision: choose a target winning setting first, place checkpoints on its path at spread
  ticks, place obstacles on other legal settings' paths only where the target's lap clears them, then scramble a start
  and keep the candidate only when the solver confirms the band's shortest range. Rationale: construction guarantees at
  least one winner; certification is still by the solver. Alternatives: random levels filtered by solvability (most are
  unsolvable or trivial).
- **R5 Clearance metric.** Decision: the minimum over samples and obstacles of (squared distance − squared radius), an
  integer. Rationale: exact and reproducible; sample-based like the checkpoint test, while contact remains the exact
  segment test.
- **R6 Counterexamples.** Decision: a losing near miss (one legal dial change from the winning setting, smallest value
  distance) with its verdict, and a non-coprime pair refused by the rules. Rationale: the archived matrix asks for a
  counterexample "that violates coprime frequency ratios"; the near miss shows the level is not trivially wide.
