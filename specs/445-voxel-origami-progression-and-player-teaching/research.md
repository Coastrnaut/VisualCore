# Research: R02-G15-05

- **R1 Hints from the solver.** Decision: the solver's minimal plan is computed from the current quarter turns
  (`plan(_:turns:)`: the same breadth-first search, hinges in index order and −1 before +1, idle hinges, collisions and
  sweeps skipped); its first turn is the hint, provided the plan fits the actions left. Rationale: from a level's
  opening this is exactly the certified plan; a breadth-first plan is a shortest path, so after its first turn the state
  is one turn closer and the plan from there has exactly one turn fewer; following exact hints therefore wins every
  certified level within its budget (US2), whatever tie the search breaks; the work bound keeps the search small.
  Alternatives: planning through a derived level (rejected: needless copies and a fingerprint change); keeping the old
  plan's tail (rejected: wrong after any other turn or an undo).
- **R2 Three hint levels.** Decision: what moves (the hinge's tracked cube), then the hinge, then the exact turn.
  Rationale: progressive help that leaves the player work at levels 1 and 2; naming the cube that moves matches what the
  player drags (feature 444).
- **R3 Stars from actions spent.** Decision: every accepted turn record counts, undone ones included; 3 at the certified
  witness's turn count, 2 within + 2, else 1. Rationale: as features 425 and 435; undo cannot buy stars; the witness is a
  proven minimum, so 3 stars mean "a shortest fold".
- **R4 Daily multiplier 31.** Decision: coprime with 100 and distinct from the other round-two games' 41 … 97.
- **R5 Schema 2 with migration.** Decision: `{level, mode, progress, records, tutorial}`; a schema-1 payload migrates to
  level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: three failures exist — `collision(hinge, moving, still, cell)`,
  `sweep(hinge, moving, still, cell)` and `budget(index)`; the text names the action (numbered from 1), the hinge and
  way, the cubes and the cell the kernel recorded, then offers undo or retry.
