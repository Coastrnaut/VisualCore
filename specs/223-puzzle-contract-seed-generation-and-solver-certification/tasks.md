# Tasks: R02-F23 — Puzzle contract, seed generation and solver certification

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F23 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F23 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
tasks; one {device} task. Fixture seed 2_023; tests stay short.

## Phase 1: Setup

- [X] T-R02F23-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host exit 0, baseline-timing exit 0 (.autonomy/migration/checks/R02-F23.baseline-*.json); rendering baseline R02-F22 rendering-27/26 exit 0
  timing run; the rendering baseline is R02-F22's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F23-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleError.swift` and `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleRules.swift` (PuzzleRules "rulesID lowercase slug ≤ 64; — Verified 2026-11-20: 2026-11-20 host exit 0: PuzzleRulesTests 3/3 (budget refusals and codes; verdict names; slug rule; fixture rules pure over all 512 lights-out states) (.autonomy/migration/checks/R02-F23.host.json)
  pure", PuzzleUniqueness, FairnessBudget "0 ≤ min ≤ max ≤ 4,096; branching 1 … 1,024; nodes 1 … 1,000,000",
  PuzzleVerdict with names, PuzzleCertificate) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleFixtures.swift` (3 × 3 lights-out and a sliding-row test
  puzzle, both with at most 512 states) and `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleRulesTests.swift` (budget refusals and codes; verdict names;
  fixture rules pure and solvable); `--name host`

## Phase 3: Story 1 — levels that are what they say (P1) 🎯

- [X] T-R02F23-003 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleLevel.swift` ("solution ≤ 4,096 moves; identity = SHA-256 hex of canonical — Verified 2026-11-20: 2026-11-20 host-2 exit 0: PuzzleLevelTests 8/8 (200 seeded round trips with identical identity and bytes; 17 one-value changes give distinct identities; golden identity pinned; edited, newer and damaged forms refused) (.autonomy/migration/checks/R02-F23.host-2.json)
  JSON; schema 1") with `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleLevelTests.swift` (200 seeded levels round-trip with identical identities; any one
  changed value changes the identity; edited, newer and damaged forms refused; rules-id and length refusals);
  `--name host-2`

## Phase 4: Stories 2 and 4 — certification and fairness (P1, P2)

- [X] T-R02F23-004 [P] [US2] [US4] Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleValidator.swift` (certify per clarification Q3) with — Verified 2026-11-20: 2026-11-20 host-3 exit 0: PuzzleValidatorTests 5/5 (200 planted faults give exactly their verdict, all 8 kinds; 50 sound levels pass; repeat certificates equal; already-solved start) (.autonomy/migration/checks/R02-F23.host-3.json)
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleValidatorTests.swift` (200 seeded levels with one planted fault each — wrong rules, illegal move, short
  solution, second solution for goal and solution promises, too long, too short, too branching, budget exceeded — fail
  with exactly the planted verdict; sound levels pass; certificates repeat; an already-solved start); `--name host-3`

## Phase 5: Story 3 — generation (P2)

- [X] T-R02F23-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleGenerator.swift` ("attempts 1 … 10,000"; derived seeds per attempt) with — Verified 2026-11-20: 2026-11-20 host-4 exit 0: PuzzleGeneratorTests 6/6 (100 seeds generate identical certified levels twice; recorded seed regenerates the candidate; rejection counts; generationFailed after exactly n attempts; attempt refusals) (.autonomy/migration/checks/R02-F23.host-4.json)
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleGeneratorTests.swift` (100 seeds generate identical levels twice and each certifies; the level's seed is the
  successful attempt's derived seed and regenerates the same candidate; rejection counts; an impossible request fails after exactly its attempt budget; attempt
  refusals); `--name host-4`

## Phase 6: Regression, documentation and close

- [ ] T-R02F23-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and
  `--name host-full`
- [X] T-R02F23-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-20: 2026-11-20 public-api exit 0 (4,047 declarations), documented-api exit 0, docs/architecture/puzzle-contract.md, README section, map F23 as built (home VisualCoreSimulation), path-map module entry done with note, render_autocreator + validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/puzzle-contract.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F23 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F23-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F23-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F23-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02F23-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F23-012 {device} Measure the generation time of a batch of certified levels on D1–D3 and record it in the
  device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 → … → 011. Agents: A (003), B (004), C (005; its tests wait for B's
validator). Shared files (002, docs) stay with the lead. MVP: Stories 1 and 2.
