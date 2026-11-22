# Research: R02-G08-05

- **R1 Hint plan.** Decision: the first cut of a winning sequence of exactly target pieces − current pieces cuts from
  the current pieces, found by the solver's bounded depth-first search started at the current pieces (pruned by
  `canPartition`, cut order as the solver's). Rationale: every cut adds one piece, so any winning continuation has
  exactly that many cuts and never wastes one; the solver already certified every level from its crystal within the
  bound, and from a state on a winning path the search is a subtree. Alternatives: replaying the certified solution
  (useless once the player has deviated); an unbounded search (could stall).
- **R2 Failure explanation.** Decision: name the sliver from the kernel's failure (`sliver(piece, cut)`) with the
  piece's share, or the cuts spent and the pieces against the target for a budget failure. Rationale: the kernel's
  failure is exact; the text only names it in words.
- **R3 Stars by cuts made.** Decision: the play's cut records at the win (undone cuts included) against the certified
  smallest cut count (3: ≤ smallest, 2: ≤ + 2, else 1). Rationale: every win spends exactly the lower bound of cuts, so
  the cuts spent cannot rank plays; the cuts made (trial and error) can.
- **R4 Daily multiplier 67.** Decision: (days since 2026-01-01 × 67) mod 100 + 1. Rationale: coprime with 100 (a
  permutation over 100 days) and distinct from the other round-two games' multipliers (37, 41, 43, 47, 53, 59, 61).
- **R5 Practice budget.** Decision: a copy of the level with the kernel's maximum budget (20). Rationale: extra cuts let
  a player try and undo freely without a budget failure; the level's fingerprint changes, so practice never mixes with
  campaign results.
- **R6 Schema 2.** Decision: `{level, records, progress, mode, tutorial}` with a migration from 1. Rationale: the
  established round-two pattern; progress and mode are part of the digest, the tutorial step is not.
