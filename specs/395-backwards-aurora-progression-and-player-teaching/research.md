# Research: R02-G10-05

- **R1 Hints from the solver.** Decision: a solver entry point searches from the current wave within the reversals
  left with the certification's iterative deepening and seam-count pruning; its first reversal is the plan. Rationale:
  following exact hints from any state that can still win wins (US2); the bound keeps the search small.
- **R2 Three hint levels.** Decision: length, then start, then both ends. Rationale: progressive help that leaves the
  player work at levels 1 and 2.
- **R3 Stars from reversals made.** Decision: undone reversals count; 3 at the smallest count, 2 within + 2, else 1.
  Rationale: as features 375 and 385; undo cannot buy stars.
- **R4 Daily multiplier 73.** Decision: coprime with 100 and distinct from the other round-two games' 37 … 71.
- **R5 Schema 2 with migration.** Decision: `{level, records, progress, mode, tutorial}`; a schema-1 payload migrates
  to level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
