# Research: R02-G09-05

- **R1 Hint search.** Decision: a new solver entry point searches from the current blooms and sun for the fewest further
  moves that win within the moves and supply left: plants at the current sun, then a sun move first, then one removal
  first; depth-first with the solver's pruning (coverage, leak, cells outside), bounded by the same 20,000 evaluations.
  Rationale: from the opening it reproduces the certified search, so following exact hints wins every level; from other
  states it finds a short way back. Alternatives: replaying the certified solution (rejected: useless once the player
  deviates).
- **R2 Stars by moves made.** Decision: moves made including undone ones; 3 stars at the certified smallest count.
  Rationale: rewards planning, as Faceted Forge does with cuts.
- **R3 Daily multiplier 71.** Decision: coprime with 100 and unused by the other round-two games.
- **R4 Practice budget 40.** Decision: the kernel's maximum budget; a copy of the level, so the certified level is
  never changed.
- **R5 Failure text from the kernel.** Decision: the leak explanation reuses the kernel's own reason (sentence-cased),
  which already names the move, the action and the cell counts; the budget explanation states the moves and the match.
