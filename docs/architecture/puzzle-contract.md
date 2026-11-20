# Puzzle contract

Feature 223 (R02-F23). Spec: [specs/223-puzzle-contract-seed-generation-and-solver-certification](../../specs/223-puzzle-contract-seed-generation-and-solver-certification/spec.md).

## The rule

A puzzle experience ships only levels that are certified: the explicit solution is legal move by move and ends solved,
it fits the fairness budget, and a promised uniqueness is proved by a bounded search — a search that runs out of budget
proves nothing. A level's identity is derived from its content, so any change changes it and an edited record is
refused; the same seed always generates the same level. The R02-F16 route solvers and the experience contract are
unchanged.

## Parts (VisualCoreSimulation)

- `PuzzleRules`: the pure rules an experience supplies — a rules id (a lowercase slug), `moves(in:)` in a fixed order,
  `apply(_:to:)` (nil when illegal) and `isSolved(_:)`.
- `PuzzleLevel`: immutable; rules id, start, solution (at most 4,096 moves), a `PuzzleUniqueness` promise (none, one
  solved goal, or the only shortest solution), a `FairnessBudget` (minimum and maximum length, a branching bound, a node
  budget) and an optional seed; its identity is the SHA-256 hex (`StableHash`) of its canonical JSON. Stored as JSON
  schema 1; a newer schema, a damaged form or an identity mismatch is refused.
- `PuzzleValidator.certify` checks, in order: the rules id, every move, the solved end, the length bounds; then a
  breadth-first search to the maximum length within the node budget checks branching, the shortest solution against the
  minimum and the uniqueness promise. The `PuzzleCertificate` holds the `PuzzleVerdict` and what the search saw; it is
  the same on every run.
- `PuzzleGenerator.generate` tries attempt i with `SeedDerivation.derive(seed, index: i)` and returns the first
  certified candidate as a `PuzzleGeneration` (with rejection counts), recording the winning attempt's seed so it can be
  regenerated; when no attempt certifies it reports failure.

## Failures

`PuzzleError` reason codes: `r2-f23.rules-id`, `r2-f23.solution-length`, `r2-f23.budget`, `r2-f23.attempts`,
`r2-f23.generation-failed`, `r2-f23.newer-schema`, `r2-f23.malformed`, `r2-f23.edited`; verdicts are answers, not
errors.

## Limits

Each experience supplies its own rules; uniqueness is proved only within the length bound and node budget; levels are
presented by the consuming experiences. Generation time of a batch is measured on D1–D3 in the device campaign.

## Sources

Breadth-first search, saturating path counting and content hashing are textbook methods; the test puzzles
(lights-out, a sliding row) use public-domain mechanics. All code is original to VisualCore.
