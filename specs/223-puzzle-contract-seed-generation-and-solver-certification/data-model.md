# Data model: R02-F23

| Entity | Fields | Rules |
|---|---|---|
| PuzzleRules (protocol) | rulesID, State, Move, moves(in:), apply(_:to:), isSolved(_:) | rulesID lowercase slug ≤ 64; pure |
| PuzzleUniqueness | none, goal, solution | |
| FairnessBudget | minLength, maxLength, maxBranching, nodeBudget | 0 ≤ min ≤ max ≤ 4,096; branching 1 … 1,024; nodes 1 … 1,000,000 |
| PuzzleLevel | rulesID, start, solution, uniqueness, budget, seed?, identity | solution ≤ 4,096 moves; identity = SHA-256 hex of canonical JSON; schema 1 |
| PuzzleVerdict | valid, wrongRules, illegalMove(index), notSolved, tooShort(length), tooLong(length), tooBranching(count), notUnique, unproven | first failure in the fixed order |
| PuzzleCertificate | verdict, explored, shortest?, solvedStates (≤ 2), shortestPaths (≤ 2), maxBranching | Equatable; identical per run |
| PuzzleGeneration | level, attempts, rejections (verdict name → count) | attempts 1 … 10,000 |
| PuzzleError | rulesID, solutionLength, budget(String), attempts, generationFailed(Int), newerSchema(Int), malformed(String), edited | `reasonCode` `r2-f23.*` |
