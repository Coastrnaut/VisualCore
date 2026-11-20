# Tasks: R02-G01-07 — Aurora Loom: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_307;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0107-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G01-07.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-03's rendering runs (exit 0)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [ ] T-R02G0107-002 [US2] Edit `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomProgress.swift` (Result gains "trace: [AuroraLoomMove], verified:
  Bool"; `record(level:moves:shortest:trace:)` keeps the fewer moves, ties keep the earlier trace; Codable with traces,
  deterministic encoding) and create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomReconciliation.swift` ("replay each verified trace on a fresh
  play of its certified level; keep only when won in exactly bestMoves with the recorded stars"; dropped count;
  frontier never below the highest kept result + 1) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomReconciliationTests.swift` (honest
  traces kept; edited stars, moves and trace steps dropped; traceless unverified results kept); `--name host`

## Phase 3: Story 1 — progress survives (P1)

- [ ] T-R02G0107-003 [US1] Edit `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift` (schema 3; migration 2 → 3 "results without
  a trace, verified false"; traces recorded on campaign and daily wins; reconciliation on restore with
  `reconciliationDropped`; replay mode with `replay.start [1…100]`, `replay.step`, `replay.stop` and codes
  r02-g01.no-replay, r02-g01.replay-end, r02-g01.replay), `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomScenarios.swift` and
  `Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json`, with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift` updates; `--name host-2`
- [ ] T-R02G0107-004 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomPersistenceTests.swift` (agent B: 500 seeded reachable
  states round-trip with equal digests; 100 schema-1 and schema-2 payloads migrate with progress kept; 200 seeded saves
  with honest and edited results reconcile exactly; every certified level's stored trace replays with the recorded
  fingerprints; replay never changes progress); `--name host-3`

## Phase 4: Story 3 — replay in the experience (P2)

- [ ] T-R02G0107-005 [US3] Edit `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` and `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift`
  (Replay for a solved level, Step, Stop in the scrolling panel with labels and values; a one-time announcement of
  dropped results; replay steps announced) with `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomReplayTests.swift` (agent C: replay through
  the port and presenter; refusals during replay; dropped-results announcement); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0107-006 Docs: `docs/architecture/aurora-loom.md` (persistence and replay), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0107-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0107-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0107-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0107-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0107-011 {device} After ImplementationLock-100: progress survives a real termination on D1/D2/D3
- [ ] T-R02G0107-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → 003 (lead) → {004 (agent B), 005 (lead; agent C writes the simulator tests)} → 006 … 010, 012.
011 stays open until device testing. Shared files (adapter, scenarios, presenter, controls, docs) stay with the lead.
MVP: Stories 1 and 2.
