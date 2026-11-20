# Feature Specification: R02-F24 — Procedural content authoring, balancing and catalogs

**Feature Branch**: `224-procedural-content-authoring-balancing-and-catalogs` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-F24 (migration ledger, shared round feature) · ID namespace FR-R02F24-###, SC-R02F24-###, T-R02F24-###

**Input**: User description: the archived R02-F24 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"build-time generated catalogs; tutorial contracts; difficulty progression; deterministic checks", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/224-procedural-content-authoring-balancing-and-catalogs`; FR-R02F24-###,
  SC-R02F24-###, T-R02F24-###.
- **Section 13 disposition: new, in an existing module.** Section 13.4 names VisualCorePuzzle and scripts/ as the home;
  R02-F23 placed the puzzle contract in VisualCoreSimulation and this feature follows it. The framework has `Preset`
  (VisualCoreParameters) and `NamedLibrary` (VisualCorePersistence) for user-made collections, and R02-F23's certified
  levels and generator; it has no ordered level catalog with a digest, no difficulty measure or progression rule and no
  tutorial contract. This feature adds them; the catalog is built from a plan and a seed by code and pinned by its
  digest in tests, so the "build-time" catalog is reproduced and checked on every test run rather than written by a
  separate tool. Existing types stay unchanged.
- **Who the users are:** every player of a level-based experience, who meets as first level the easiest level of the first stage, a tutorial that
  teaches one idea at a time and only moves on when the idea was used, and levels that get harder steadily, never in a
  sudden jump and never easier again by much; the engineer, who needs a catalog that is the same on every build and
  device, with every level certified.
- **Prerequisites:** R02-F23 (puzzle contract) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** building a full catalog on D1–D3 is not needed (catalogs are built on
  the host); tutorial use with VoiceOver on D1–D3 is recorded in the device campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): R02-F23's `PuzzleLevel`, `PuzzleValidator`, `PuzzleCertificate` and
`PuzzleGenerator`, `SeedDerivation` and `StableHash` are present. The names `LevelCatalog` (Light Maze), `Tutorial`,
`TutorialStep`, `TutorialProgress` (Physics Playground) and `CatalogError` (VisualCoreExperience and two experiences) are
taken, so this feature uses `PuzzleCatalog`, `PuzzleCatalogPlan`, `PuzzleCatalogStage`, `PuzzleCatalogEntry`,
`PuzzleCatalogBuilder`, `PuzzleCatalogChecker`, `PuzzleCatalogReport`, `PuzzleCatalogIssue`, `PuzzleDifficulty`,
`ProgressionRule`, `TutorialContract`, `TutorialContractStep`, `TutorialCondition`, `TutorialEvent`,
`TutorialContractProgress` and `ContentError`, all free.

- Q: How is a catalog planned, built and identified? → A: a `PuzzleCatalogPlan` has a catalog id (lowercase slug), a seed
  and 1 … 16 ordered `PuzzleCatalogStage`s (count 1 … 500, a `FairnessBudget`, a uniqueness promise, an attempt budget per
  level 1 … 10,000), at most 1,000 levels in all. `PuzzleCatalogBuilder.build` walks a global index n = 0, 1, …; level
  candidates come from `PuzzleGenerator.generate(seed: SeedDerivation.derive(seed, index: n), …)`; each call uses the stage's attempt
  budget and advances n by one; a level whose identity is already in the catalog is skipped; a stage fails with
  `.planFailed(stage, calls)` as soon as a call finds no certified level, or when 4 × count calls have not filled it.
  `PuzzleCatalog(id:entries:)` refuses a bad id (`.plan("id")`) and 0 or more than 1,000 entries (`.plan("entries")`)
  but accepts duplicates and uncertified levels, which only the checker judges; the builder never produces them. Each stage's levels are ordered by difficulty, then identity. The `PuzzleCatalog` holds
  the id, schema 1, the `PuzzleCatalogEntry`s (level and difficulty) and a digest: the SHA-256 hex of "<id>\n" followed by
  each identity and "\n". Impact: FR-R02F24-001; SC-R02F24-001.
- Q: How is difficulty measured and when does progression fail? → A: `PuzzleDifficulty` is the certificate's shortest
  solution length and states explored, ordered by length then states. A `ProgressionRule` (maximum drop 0 … 64, maximum
  jump 0 … 64; defaults 1 and 3) compares neighbours' shortest lengths: the next may be at most `maxDrop` shorter and at
  most `maxJump` longer. The builder applies it to the finished catalog and fails with `.progression(position)` at the
  first breach. Impact: FR-R02F24-002; SC-R02F24-002.
- Q: What does the checker report? → A: `PuzzleCatalogChecker.check(_:rules:rule:)` re-certifies every level and returns a
  `PuzzleCatalogReport` listing every `PuzzleCatalogIssue` in position order: `uncertified(index, verdict)`,
  `duplicate(index, first)`, `difficultyMismatch(index)` (stored difficulty differs from the certificate),
  `drop(index)`, `jump(index)` and `digestMismatch` (a stored digest that
  differs from the entries, possible only for values made outside the public initialiser); a report without issues passes. The same catalog always gives the
  same report. Impact: FR-R02F24-003; SC-R02F24-002.
- Q: What is a tutorial contract, and how does it advance? → A: a `TutorialContract` has an id (slug) and 1 … 64
  `TutorialContractStep`s (id slug, unique; a text key of 1 … 128 characters; a `TutorialCondition`: `.move` — any move;
  `.moves(n)` — n moves since the step began, 1 … 1,000; `.solve` — any level solved; `.solveLevel(identity)`; or
  `.acknowledge`). `TutorialContractProgress` holds the contract id, the current step index, the moves counted in the
  step, the completed and the skipped step ids and whether it is finished; `apply(_ event: TutorialEvent)` (`.moved`,
  `.solved(identity)`, `.acknowledged`) advances exactly when the current condition is met and ignores other events and
  events after the end; `skip()` marks the current step skipped and advances; `restart()` returns to the start.
  Impact: FR-R02F24-004; SC-R02F24-003.
- Q: How are stored forms checked and refusals named? → A: `PuzzleCatalog` and `TutorialContractProgress` are JSON schema
  1 with sorted keys; decoding a catalog decodes each level (whose identity is checked) and recomputes the digest
  (`.edited` on mismatch); progress is decoded against its contract (`decode(_:for:)`: contract id, step range and step
  ids must match). Refusals are `ContentError` with codes `r2-f24.plan`, `r2-f24.plan-failed`, `r2-f24.progression`,
  `r2-f24.tutorial`, `r2-f24.newer-schema`, `r2-f24.malformed` and `r2-f24.edited`. Impact: FR-R02F24-005, 006;
  SC-R02F24-003, 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A reproducible level catalog (Priority: P1) 🎯

The engineer describes a catalog — how many levels, which seed, which budgets per stage — and gets an ordered list of
certified levels with a digest; the same plan always gives the same catalog and digest.

**Why this priority**: every level-based experience ships a catalog.

**Independent Test**: building a plan twice gives identical catalogs and digests; every level certifies; a pinned digest
catches any change.

**Acceptance Scenarios**:

1. **Given** a plan, **When** the catalog is built twice, **Then** both are identical, digest included.
2. **Given** a stored catalog with one level changed, **When** it is opened, **Then** it is refused.

### User Story 2 - Difficulty that rises steadily (Priority: P1)

Each level gets a difficulty measure from its certification; the catalog's order must rise steadily: no level is much
easier than the one before, and no step is a big jump.

**Independent Test**: catalogs that violate the rule are reported with the offending position; built catalogs satisfy it.

### User Story 3 - Tutorial contracts (Priority: P2)

A tutorial is a short list of steps, each naming the text to show (a key, not the text itself) and the condition that
completes it (a move made, a level solved, a number of moves); the tutorial advances only when the condition is met, can
be skipped and resumed, and is saved with the player's progress.

**Independent Test**: scripted event sequences advance the tutorial exactly at the steps' conditions; skipping and
resuming keep the position; saved progress reopens identically.

### User Story 4 - Deterministic checks (Priority: P2)

The engineer checks a catalog without rebuilding it: every level certifies, identities are unique, the difficulty rule
holds, the digest matches; the report is the same on every run.

**Independent Test**: planted faults (a duplicate level, an uncertified level, a wrong digest, a difficulty jump) are each
reported with their position; a sound catalog passes.

### Edge Cases

- **A plan the generator cannot fill:** reported with the stage and the attempts made, never a short catalog.
- **An empty plan or zero levels:** refused.
- **Two identical levels:** reported by the checker as a duplicate; the builder never produces them.
- **A tutorial event that matches no step, or comes after the end:** ignored, the position unchanged.
- **Damaged, newer or edited stored catalogs and progress:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F24-001**: A catalog MUST be built deterministically from a plan (stages with counts, budgets and promises) and
  a seed, contain only certified levels in order, and carry a content digest.
- **FR-R02F24-002**: Each level MUST receive a difficulty measure derived from its certification, and the catalog order
  MUST satisfy a progression rule with stated tolerances.
- **FR-R02F24-003**: A checker MUST verify a catalog (certification, unique identities, progression, digest) and report
  every failure with its position, identically on every run.
- **FR-R02F24-004**: A tutorial contract MUST define ordered steps with a text key and a completion condition, advance
  only on matching events, support skip and resume, and store its progress.
- **FR-R02F24-005**: Catalogs and tutorial progress MUST have versioned stored forms; newer, damaged and edited forms MUST
  be refused.
- **FR-R02F24-006**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F24-007**: Existing types (`Preset`, `NamedLibrary`, the R02-F23 contract) and their tests MUST be unchanged;
  every new public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Catalog plan**: catalog id, seed, ordered stages (count, budget, uniqueness promise, attempt budget).
- **Level catalog**: id, schema, levels with their difficulty, digest.
- **Difficulty**: measure from the certificate (shortest solution, states explored, branching).
- **Progression rule**: largest allowed drop and largest allowed jump between neighbours.
- **Tutorial**: id, ordered steps (text key, completion condition).
- **Tutorial progress**: current step, completed and skipped steps, move counts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F24-001**: A plan of 3 stages and 30 levels builds twice into identical catalogs with identical digests; the
  digest equals the value pinned in the test; every level certifies.
- **SC-R02F24-002**: Built catalogs satisfy the progression rule; 100 seeded catalogs with one planted fault each are
  reported with exactly that fault and position.
- **SC-R02F24-003**: 100 seeded tutorial event scripts advance exactly as the steps' conditions say; skip and resume keep
  the position; progress round-trips byte for byte.
- **SC-R02F24-004**: Catalogs round-trip byte for byte; newer, damaged and edited forms are refused.
- **SC-R02F24-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Each experience supplies its rules and candidate makers (R02-F23); this slice proves the catalog, checker and tutorial
  on the R02-F23 test puzzles.
- Tutorial text is localised by the consuming experience from its keys; layout, colours and VoiceOver presentation
  belong to it, on iPhone and iPad alike.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Build-time generated catalogs | FR-R02F24-001, 005 |
| Tutorial contracts | FR-R02F24-004 |
| Difficulty progression | FR-R02F24-002 |
| Deterministic checks | FR-R02F24-003 |
| Observability | FR-R02F24-003, 006 |
| No Stage One breakage | FR-R02F24-007 |

## Negative Requirements / Excluded scope

- No new module, no change to `Preset`, `NamedLibrary` or the R02-F23 contract, no level editor, no telemetry-driven
  balancing, no downloadable content, no device run before ImplementationLock-100, no analytics.
