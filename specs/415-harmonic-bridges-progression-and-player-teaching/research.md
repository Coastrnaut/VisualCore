# Research: R02-G12-05

- **R1 Hints from the solver.** Decision: the solver's minimal plan is computed for the level with every string at its
  current peg (locks kept); when the current pegs already join the start to the goal in every step the plan is the
  test, otherwise its first tuning (lowest string index), provided the plan's tunings plus the test fit the actions
  left. Rationale: from a level's opening this is exactly the certified plan, and after each followed tuning the plan
  from the new pegs needs one tuning fewer (the rest of the old plan still wins), so following exact hints wins every
  certified level within its budget (US2); the work bound keeps the search small. Alternatives: a search over action
  sequences (rejected: the minimal set of retuned strings already orders the tunings, and the tunings commute).
- **R2 Three hint levels.** Decision: the kind (tune or test), then the string, then the peg. Rationale: progressive help
  that leaves the player work at levels 1 and 2.
- **R3 Stars from actions spent.** Decision: every accepted tuning and test record counts, undone ones included; 3 at
  the certified witness's action count, 2 within + 2, else 1. Rationale: as features 395 and 405; undo cannot buy stars.
  The witness is a proven minimum of tunings (no smaller set wins), so 3 stars mean "a minimal crossing".
- **R4 Daily multiplier 83.** Decision: coprime with 100 and distinct from the other round-two games' 37 … 79.
- **R5 Schema 2 with migration.** Decision: `{level, mode, progress, records, tutorial}`; a schema-1 payload migrates to
  level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: two failures exist — a broken test (`broken(step, string)`) and an exhausted
  budget (`budget(action)`); the text names the action, the broken step and string (or that no string reaches across),
  and in how many steps the start reached the goal. Rationale: the kernel records both, with the failing action's index.
