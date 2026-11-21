# Research: R02-G03-02

- **R1 — Building solvable levels.** Decision: construct a solved rope, then walk `scramble` legal moves away from it.
  Rationale: the reverse walk is a legal solution (a unit step's sweep and tension are symmetric), so every kept
  candidate is solvable by construction and the solver only has to prove the shortest length. Alternatives: random ropes
  with a searched target (rejected: most random ropes have no reachable non-degenerate target within a small depth).
- **R2 — Solver.** Decision: breadth-first search over legal ropes to depth 3 with a visited set keyed by the points.
  Rationale: the win is a signature (crossings, writhe), not a single rope, so a backward or bidirectional search has no
  goal state; with ≤ 10 points the search is at most 3,661 expansions, small enough for every level on a debug host.
  Alternatives: iterative deepening (same bound, more repeated work); A* (no admissible heuristic for the signature).
- **R3 — Band ranges.** Decision: shortest 1, 1–2, 2, 2–3, 3 moves and ropes of 6 … 10 points by band. Rationale: keeps the
  exhaustive search bounded while difficulty grows through rope length, gates and target crossings; allowances (8 … 19)
  leave room for exploration.
- **R4 — Counterexamples.** Decision: near miss from the winning rope (first legal move that does not win) and a crossing
  refusal taken from the first explored rope that has one. Rationale: both always exist in practice for ropes whose
  projection crosses itself; a candidate without them is skipped, so every witness has both.
