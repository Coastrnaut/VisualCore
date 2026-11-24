# Research: R02-G14-05

- **R1 Hints from the solver.** Decision: the solver's minimal plan is computed from the current phases and lamp height
  (`plan(_:phases:height:)`: the same plan-vector search by L1 norm, pruned by the lamp range and the mesh alignments);
  its first witness action is the hint (turns, then re-seats in gear order, then lamp steps, then the run), provided the
  plan's actions plus the run fit the actions left. Rationale: from a level's opening this is exactly the certified
  plan, and after each followed action the plan from the new state needs one action fewer (actions commute, so the rest
  of the old vector still wins and is minimal), so following exact hints wins every certified level within its budget
  (US2); the work bound keeps the search small. Alternatives: planning through a derived level (rejected: needless
  copies and a fingerprint change); a search over action sequences (rejected: actions commute, so the vector suffices).
- **R2 Three hint levels.** Decision: the kind (turn, re-seat, lamp, run), then the way or the gear, then the exact
  action. Rationale: progressive help that leaves the player work at levels 1 and 2.
- **R3 Stars from actions spent.** Decision: every accepted turn, re-seat, lamp step and run record counts, undone ones
  included; 3 at the certified witness's action count, 2 within + 2, else 1. Rationale: as features 415 and 425; undo
  cannot buy stars; the witness is a proven minimum, so 3 stars mean "a minimal set-up".
- **R4 Daily multiplier 97.** Decision: coprime with 100 and distinct from the other round-two games' 37 … 89.
- **R5 Schema 2 with migration.** Decision: `{level, mode, progress, records, tutorial}`; a schema-1 payload migrates to
  level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: five failures exist — `jammed(child)`, `forbidden(frame, cell)`,
  `missing(frame, count)`, `stray(frame, count)` and `budget(index)`; the text names the action and the numbers the
  kernel recorded (the jammed gear's parent and the stray allowance read from the level), then offers undo or retry.
