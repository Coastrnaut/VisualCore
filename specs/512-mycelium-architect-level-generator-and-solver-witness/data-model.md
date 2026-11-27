# Data model: R02-G22-02

| Entity | Fields | Rules |
|---|---|---|
| `MyceliumArchitectLevel` (extended) | + sites: [Cell]? | nil or 2 … 12 distinct cells, on the board, empty (not root, terminal, rock, toxin, fixed nutrient), ascending; refusals "site count", "site", "site not empty" after the shared-cell check and before "nothing placeable"; omitted from the stored form and fingerprint when nil |
| `MyceliumArchitectManifestEntry` | number 1 … 100, plannedSeed (UInt64), band 1 … 5, budget, emphasis, concept | copied from the archived manifest |
| `MyceliumArchitectBandProfile` | width and height ranges, rock ‰, toxin ‰, terminals, sites, fixed nutrients, seed limit, strength, reach, κ, ο, pulses, budget slack, limit slack, plan length p | values of spec clarification Q2 (as measured, research R4); candidate bound 1 024 |
| `MyceliumArchitectPlan` | actions (arrangement actions, then run) | length p + 1 |
| `MyceliumArchitectDifficulty` | witnessLength, terminals, boardCells, toxins, sites, moveSpace, searchedBelow, work, nearestMiss | from the level and the solver |
| `MyceliumArchitectSolution` | plan, work, countsByDepth, nearestMiss (loss, arrangement, failure) | countsByDepth[d] for d < plan length, none winning |
| `MyceliumArchitectWitness` | schema 1, number, level, actions, digests, fingerprints, terminal report, counterexample, difficulty, skipped | sorted-key JSON; newer schema → newer-schema; damaged → malformed; no longer replaying → witness |
| `MyceliumArchitectCatalog` | levels (100, manifest order), digest | progression rule on witness length |

Refusals added: `generation(Int)` → `r02-g22.generation`; `witness(String)` → `r02-g22.witness`; the play's `.action("not
a site")`.
