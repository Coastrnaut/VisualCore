# Content catalogs and tutorial contracts

Feature 224 (R02-F24). Spec: [specs/224-procedural-content-authoring-balancing-and-catalogs](../../specs/224-procedural-content-authoring-balancing-and-catalogs/spec.md).

## The rule

A level-based experience ships a catalog built by code from a plan and a seed: every level certified by the R02-F23
contract, ordered so difficulty rises steadily, identified by a digest that tests pin. A tutorial teaches one idea per
step and moves on only when that idea was used. The same plan gives the same catalog, and the same events the same
tutorial position, on every device. `Preset`, `NamedLibrary` and the R02-F23 contract are unchanged.

## Parts (VisualCoreSimulation)

- `PuzzleCatalogPlan`: a catalog id, a seed and 1 … 16 `PuzzleCatalogStage`s (count, fairness budget, uniqueness
  promise, attempts per level), at most 1,000 levels, and a `ProgressionRule`.
- `PuzzleDifficulty`: a certificate's shortest solution length, then the states explored. `ProgressionRule` bounds the
  drop (default 1) and jump (default 3) between neighbours' shortest lengths.
- `PuzzleCatalogBuilder.build` asks `PuzzleGenerator` for each level with `SeedDerivation.derive(seed, index: n)` for a
  global n, skips duplicates, orders each stage by difficulty then identity, checks the progression and returns a
  `PuzzleCatalog` of `PuzzleCatalogEntry`s whose digest is the SHA-256 hex of the id and the identities, one per line.
  Stored as JSON schema 1; an edited digest or level is refused.
- `PuzzleCatalogChecker.check` re-certifies every level and lists every `PuzzleCatalogIssue` in position order
  (uncertified, duplicate, difficulty mismatch, drop, jump, digest mismatch) in a `PuzzleCatalogReport`.
- `TutorialContract` holds up to 64 `TutorialContractStep`s (an id, a text key, a `TutorialCondition`: a move, n moves,
  any solve, a given level solved, or an acknowledgement). `TutorialContractProgress` advances on `TutorialEvent`s only
  when the current condition is met, supports skip and restart, and is stored as JSON schema 1, decoded against its
  contract.

## Failures

`ContentError` reason codes: `r2-f24.plan`, `r2-f24.plan-failed`, `r2-f24.progression`, `r2-f24.tutorial`,
`r2-f24.newer-schema`, `r2-f24.malformed`, `r2-f24.edited`; checker findings are issues, not errors.

## Limits

Catalogs are built and checked on the host and pinned by digest in tests, not written by a separate tool; tutorial
text is a key the consuming experience localises and presents (VoiceOver included, on iPhone and iPad). Tutorial use
with VoiceOver is recorded on D1–D3 in the device campaign.

## Sources

Seeded generation, neighbour-bounded difficulty curves and step-by-step tutorials are common game-design practice;
all code is original to VisualCore.
