# Feature Specification: R02-F24 — Procedural content authoring, balancing and catalogs

**Feature Branch**: `224-procedural-content-authoring-balancing-and-catalogs` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

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
- **Who the users are:** every player of a level-based experience, who meets a gentle first level, a tutorial that
  teaches one idea at a time and only moves on when the idea was used, and levels that get harder steadily, never in a
  sudden jump and never easier again by much; the engineer, who needs a catalog that is the same on every build and
  device, with every level certified.
- **Prerequisites:** R02-F23 (puzzle contract) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** building a full catalog on D1–D3 is not needed (catalogs are built on
  the host); tutorial use with VoiceOver on D1–D3 is recorded in the device campaign. **Owner-only items:** none.

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
- **Two identical levels:** refused as duplicates.
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
