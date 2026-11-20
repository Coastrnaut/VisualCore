# Data model: R02-F24

| Entity | Fields | Rules |
|---|---|---|
| PuzzleCatalogStage | count, budget, uniqueness, attempts | count 1 … 500; attempts 1 … 10,000 |
| PuzzleCatalogPlan | id, seed, stages, rule | id slug; 1 … 16 stages; ≤ 1,000 levels |
| PuzzleDifficulty | shortest, explored | ordered by shortest, then explored |
| ProgressionRule | maxDrop, maxJump | each 0 … 64 (defaults 1, 3) |
| PuzzleCatalogEntry | level, difficulty | |
| PuzzleCatalog | id, entries, digest | digest = SHA-256 hex of "<id>\n" + identities each followed by "\n"; schema 1 |
| PuzzleCatalogIssue | uncertified(index, verdict), duplicate(index, first), difficultyMismatch(index), drop(index), jump(index), digestMismatch | position order |
| PuzzleCatalogReport | issues | passes when empty |
| TutorialCondition | move, moves(n), solve, solveLevel(identity), acknowledge | n 1 … 1,000 |
| TutorialContractStep | id, textKey, condition | id slug, unique; key 1 … 128 characters |
| TutorialContract | id, steps | id slug; 1 … 64 steps |
| TutorialEvent | moved, solved(identity), acknowledged | |
| TutorialContractProgress | contractID, step, movesInStep, completed, skipped, finished | schema 1; decoded against its contract |
| ContentError | plan(String), planFailed(stage, calls), progression(Int), tutorial(String), newerSchema(Int), malformed(String), edited | `reasonCode` `r2-f24.*` |
