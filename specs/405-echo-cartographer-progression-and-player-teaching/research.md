# Research: R02-G11-05

- **R1 Hints from the solver.** Decision: a solver entry point continues the certification's greedy pulse rule from the
  current knowledge and pulses until one beacon placement fits, within the energy left; when one placement already fits
  the plan is a claim on the lowest-index beacon not yet located. Rationale: from a level's opening the continuation is
  exactly the certified plan, so following exact hints wins every certified level (US2); the work bound keeps the search
  small. Alternatives: an exhaustive minimum-pulse search (rejected: the certification itself is greedy, and the
  exhaustive search is not bounded by the existing limit).
- **R2 Three hint levels.** Decision: the kind (pulse or claim), then its row, then the cell. Rationale: progressive
  help that leaves the player work at levels 1 and 2.
- **R3 Stars from energy spent.** Decision: every accepted pulse and claim record counts, undone ones included; 3 at the
  certified plan's pulse count, 2 within + 2, else 1. Rationale: as features 385 and 395; undo cannot buy stars. The
  certified plan is a witness, not a proven minimum, so 3 stars mean "as good as the certified plan".
- **R4 Daily multiplier 79.** Decision: coprime with 100 and distinct from the other round-two games' 37 … 73.
- **R5 Schema 2 with migration.** Decision: `{level, records, progress, mode, tutorial}`; a schema-1 payload migrates
  to level 1 and the restored level open, campaign mode, tutorial at step 1. Rationale: older saved states stay valid.
- **R6 Failure explanation.** Decision: the only failure is running out of energy; the text names the action (a pulse
  or a missed claim and its cell), the beacons located, the pulses sent and the claims missed. Rationale: the kernel
  records the failing action's index (`energy(index)`).
