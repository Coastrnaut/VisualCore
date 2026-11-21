# Research: R02-G05-02

- **R1 Edit sets before the first tick.** Decision: the solver searches multisets of carves plus sets of valve toggles
  applied before tick 1, then runs to the tick limit. Rationale: the kernel's routing depends only on heights and valves,
  so an edit set has one outcome; a player may also edit mid-run, so the certificate is an upper bound on the true
  smallest plan and the witness is always playable. Alternatives: a tick-level search through `ColorfallCanyonsRules`
  (state space grows with every tick; infeasible to certify 100 levels in seconds).
- **R2 Simulate each routing once.** Decision: key an edit set by (every cell's downhill neighbour, valve states). Rationale:
  carves that do not change any downhill choice cannot change the outcome; the prototype needed at most 6,540 runs for one
  level. Alternatives: simulating every set (up to hundreds of thousands of runs).
- **R3 Planted plans and pooled basins.** Decision: generate terrain, plant one path change per spring, put basins where
  the planted paths end in pools, and take the targets from the planted run; keep the candidate only when the unedited
  level fails and the solver's smallest count is in the band's range. Rationale: a prototype that placed basins at random
  rarely reached them, and one that planted random carves mostly changed nothing (levels won unedited); this rule
  produced 20 of 20 levels per band within 256 candidates. Alternatives: hand-authored levels (excluded by the spec).
- **R4 Band ranges.** Decision: smallest edits 1 … 2, 2 … 3, 3, 3, 3 for bands 1 … 5 (corrected from 3 … 4 and 4 for bands 4
  and 5 after measuring the depth-4 search on the debug host build) with 1, 2, 2, 3, 3 springs.
  Rationale: band means cannot fall, and R02-F24's progression rule (drop ≤ 1, jump ≤ 3) holds across band boundaries.
- **R5 Witness digests.** Decision: 16 hex characters of the SHA-256 of the cell masses after every tick up to the win.
  Rationale: the source asks for per-tick state digests; 16 characters keep 100 files small while any change still shows.
