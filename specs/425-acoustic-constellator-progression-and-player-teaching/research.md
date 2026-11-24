# Research: R02-G13-05

- **R1 Hints from the solver.** Decision: the solver's minimal plan is computed from the current links and starting
  phases (`plan(_:links:phases:)`: the base is the current links plus the missing symbol pairs, the options are the
  helper links the degree and link limits allow and ±1 nudges); its first action is the hint (missing pairs first, then
  helper links, then nudges, then the listen), provided the plan's actions plus the listen fit the actions left.
  Rationale: from a level's opening this is exactly the certified plan, and after each followed action the plan from the
  new state needs one action fewer (the rest of the old plan still wins and is minimal), so following exact hints wins
  every certified level within its budget (US2); the work bound keeps the search small. Alternatives: planning through
  a derived level (rejected: a level allows at most 6 fixed links, a play may hold more); a search over action
  sequences (rejected: links commute and nudges commute, so the set suffices).
- **R2 Three hint levels.** Decision: the kind (link a symbol pair, link a helper pair, nudge, listen), then the stars,
  then the exact action. Rationale: progressive help that leaves the player work at levels 1 and 2.
- **R3 Stars from actions spent.** Decision: every accepted link, unlink, nudge and listen record counts, undone ones
  included; 3 at the certified witness's action count, 2 within + 2, else 1. Rationale: as features 405 and 415; undo
  cannot buy stars; the witness is a proven minimum (no smaller set wins), so 3 stars mean "a minimal constellation".
- **R4 Daily multiplier 89.** Decision: coprime with 100 and distinct from the other round-two games' 37 … 83.
- **R5 Schema 2 with migration.** Decision: `{level, mode, progress, records, tutorial}`; a schema-1 payload migrates to
  level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: four failures exist — `missing(pair)`, `disconnected(tick, link)`,
  `incoherent(longestRun)` and `budget(action)`; the text names the action and the numbers the kernel recorded, then
  offers undo or retry. Rationale: the kernel records each, with the failing action's index.
