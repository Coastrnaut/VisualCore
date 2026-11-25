# Research: R02-G16-05

- **R1 Hints from the solver.** Decision: the solver's minimal plan is computed from the current star, beat and drawn
  strokes (`plan(_:from:beat:drawn:)`: the same breadth-first search, corridors by index from the ship's star then waits
  0 … 8, legs the chart refuses or fails skipped); its first leg is the hint, provided the plan fits the actions left.
  Rationale: from a level's opening this is exactly the certified plan; a breadth-first plan is a shortest path, so
  after its first leg the state is one leg closer and the plan from there has exactly one leg fewer; following exact
  hints therefore wins every certified level within its budget (US2), whatever tie the search breaks; the work bound
  keeps the search small. Alternatives: planning through a derived level (rejected: needless copies and a fingerprint
  change); keeping the old plan's tail (rejected: wrong after any other leg or an undo).
- **R2 Three hint levels.** Decision: the stroke (the corridor and its two stars), then the destination, then the exact
  leg with its wait. Rationale: progressive help that leaves the player work at levels 1 and 2; the stroke is what the
  player sees on the cartouche.
- **R3 Stars from actions spent.** Decision: every accepted leg record counts, undone ones included; 3 at the certified
  witness's leg count, 2 within + 2, else 1. Rationale: as feature 445; undo cannot buy stars; the witness is a proven
  minimum, so 3 stars mean "a shortest route".
- **R4 Daily multiplier 37.** Decision: coprime with 100 and distinct from the other round-two games' 31 … 97.
- **R5 Schema 2 with migration.** Decision: `{level, mode, progress, records, tutorial}`; a schema-1 payload migrates to
  level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: six failures exist — `departure(star, beat, close)`, `hazard(corridor, hazard,
  from, to)`, `arrival(star, beat, open, close)`, `deadline(beat, deadline)`, `stroke(corridor)` and `budget(spent)`;
  the text names the action (numbered from 1), its destination and wait and what the kernel recorded, then offers undo
  or retry.
