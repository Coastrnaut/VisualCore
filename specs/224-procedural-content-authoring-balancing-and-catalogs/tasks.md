# Tasks: R02-F24 — Procedural content authoring, balancing and catalogs

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F24 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F24 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
tasks; one {device} task. Fixture seed 2_024; tests stay short.

## Phase 1: Setup

- [X] T-R02F24-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host exit 0, baseline-timing exit 0 incl. engine timeout bounds (.autonomy/migration/checks/R02-F24.baseline-*.json); rendering baseline R02-F23 rendering-27/26 exit 0
  timing run (now including the experience engine's timeout and cancellation bounds); the rendering baseline is R02-F23's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F24-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/ContentError.swift` and `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalogPlan.swift` (PuzzleCatalogStage "count 1 … 500; — Verified 2026-11-20: 2026-11-20 host exit 0: ProgressionRuleTests 4/4 (refusals and codes; breach positions; difficulty order and certificate initialiser; coding re-validates) (.autonomy/migration/checks/R02-F24.host.json)
  attempts 1 … 10,000", PuzzleCatalogPlan "id slug; 1 … 16 stages; ≤ 1,000 levels", PuzzleDifficulty ordered by shortest
  then explored, ProgressionRule "each 0 … 64 (defaults 1, 3)" with `standard` and `breach`) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/ProgressionRuleTests.swift` (refusals and codes; breach positions for drops and jumps; difficulty order and the
  certificate initialiser); `--name host`

## Phase 3: Stories 1 and 2 — catalogs and progression (P1) 🎯

- [X] T-R02F24-003 [P] [US1] [US2] Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalog.swift` (PuzzleCatalogEntry, PuzzleCatalog "digest = — Verified 2026-11-20: 2026-11-20 host-2 exit 0: PuzzleCatalogTests 13/13 (30-level plan builds twice with pinned digest 678aafc0…; every level certifies; stages ordered; progression holds; planFailed for a nil maker (1 call) and for too few distinct boards (40 calls, duplicates judged on seed-free content); progression(4); round trip; newer, damaged, edited refused) (.autonomy/migration/checks/R02-F24.host-2.json)
  SHA-256 hex of '<id>\n' + identities each followed by '\n'; schema 1", PuzzleCatalogBuilder per clarifications Q1, Q2)
  with `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleCatalogTests.swift` (a 3-stage, 30-level lights-out plan builds twice identically with a pinned
  digest; every level certifies; stages ordered by difficulty; progression holds; unfillable plans fail with stage and
  calls (a failing call, and too many duplicates); a progression breach fails with its position; round trip byte for byte; newer, damaged and edited forms refused);
  `--name host-2`

## Phase 4: Story 4 — deterministic checks (P2)

- [X] T-R02F24-004 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalogChecker.swift` (PuzzleCatalogIssue, PuzzleCatalogReport, — Verified 2026-11-20: 2026-11-20 host-3 exit 0: PuzzleCatalogCheckerTests 4/4 (50 sound catalogs pass; 100 planted faults give exactly their issue; every breach listed; issue order) (.autonomy/migration/checks/R02-F24.host-3.json)
  PuzzleCatalogChecker per clarification Q3) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleCatalogCheckerTests.swift` (100 seeded catalogs with one
  planted fault each — uncertified level, duplicate, difficulty mismatch, drop, jump, digest mismatch — report exactly
  that issue and position; sound catalogs pass; reports repeat); `--name host-3`

## Phase 5: Story 3 — tutorial contracts (P2)

- [X] T-R02F24-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreSimulation/TutorialContract.swift` (TutorialCondition "n 1 … 1,000", TutorialContractStep — Verified 2026-11-20: 2026-11-20 host-4 exit 0: TutorialContractTests 7/7 (100 seeded scripts match a reference model; unmatched, late and foreign events ignored; skip, resume, restart; round trip; stored-form and init refusals) (.autonomy/migration/checks/R02-F24.host-4.json)
  "id slug, unique; key 1 … 128 characters", TutorialContract "id slug; 1 … 64 steps", TutorialEvent,
  TutorialContractProgress "schema 1; decoded against its contract") with `Packages/VisualCore/Tests/VisualCoreSimulationTests/TutorialContractTests.swift` (100 seeded
  event scripts advance exactly at the conditions; unmatched and late events ignored; skip and restart; round trip byte
  for byte; progress for another contract or out of range refused; refusals and codes); `--name host-4`

## Phase 6: Regression, documentation and close

- [X] T-R02F24-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences (sim-27.2) and host-full exit 0
  `--name host-full`
- [X] T-R02F24-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-20: 2026-11-20 public-api exit 0, documented-api exit 0, docs/architecture/content-catalogs.md, README section, map F24 as built (home VisualCoreSimulation), render_autocreator + validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/content-catalogs.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F24 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F24-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F24-009 Reference regression chunk 2 (`--name reference-2`)
- [X] T-R02F24-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-20: 2026-11-20 script-tests exit 0, run alone (.autonomy/migration/checks/R02-F24.script-tests.json)
- [ ] T-R02F24-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F24-012 {device} Drive a tutorial contract with VoiceOver on D1–D3 and record it in the device campaign; never
  before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 → … → 011. Agents: A (003), B (004; builds catalogs by hand until A's
builder exists), C (005). Shared files (002, docs) stay with the lead. MVP: Stories 1 and 2.

## Phase 7: Convergence

- [X] T-R02F24-013 Add a checker test where two levels have the same content but different seeds (different identities) — Verified 2026-11-20: 2026-11-20 host-5 exit 0: PuzzleCatalogCheckerTests 5/5 incl. duplicatesIgnoreTheSeed (same content, seeds 11 and 12, distinct identities → duplicate(1, first: 0); different content passes) (.autonomy/migration/checks/R02-F24.host-5.json)
  and are reported as `.duplicate`, while two levels with different content are not, in
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleCatalogCheckerTests.swift`; `--name host-5` per spec
  Clarifications Q1, Q3 (partial)
