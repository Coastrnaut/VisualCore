# Tasks: R02-G19-10 — Microscopic Aurora: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G19-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G19-10 --name <check> -- <command>` (never
a scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1910-001 Baselines after R02-G19-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-26: 2026-11-26 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed tree (.autonomy/migration/checks/R02-G19-10.baseline-*.json)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3e with `MicroscopicAurora`; no Swift changes
  follow; the rendering baseline is R02-G19-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1910-002 [US1] Create `docs/apps/microscopic-aurora/device-rows.json` (data-model.md: "schema 1, sorted keys"; — Verified 2026-11-26: 2026-11-26 device-rows exit 0: device-rows r02-g19.microscopic-aurora: PASS (8 rows, 12 scenarios) (.autonomy/migration/checks/R02-G19-10.device-rows.json); release step device-rows-r02-g19 added
  devices D1 → DEV1-R02-G19, D2 → DEV2-R02-G19, D3 → DEV3-R02-G19; the 12 scenarios of clarification Q2; rows MA-D1 …
  MA-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false only
  for MA-D6), covers, owner_steps, status "pending device campaign"; no result field); edit `scripts/release_check.py`
  (step `device-rows-r02-g19`); `--name device-rows -- python3 scripts/check_device_rows.py --experience
  r02-g19.microscopic-aurora`
- [X] T-R02G1910-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Microscopic Aurora definition passes; a — Verified 2026-11-26: 2026-11-26 script-tests exit 0 run alone (.autonomy/migration/checks/R02-G19-10.script-tests.json): 8 MicroscopicAuroraDeviceRowsCheckTests (real definition passes; removed scenario, missing pass field and uncovered tasks fail by name; release step runs the check)
  copy with a scenario removed, a copy with MA-D1's `pass` field removed and a copy with T-R02G1909-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g19` runs the check for
  `r02-g19.microscopic-aurora`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1910-004 [P] [US2] Create `docs/apps/microscopic-aurora/device-campaign.md` (agent B, modelled on — Verified 2026-11-26: 2026-11-26 docs exit 0 (.autonomy/migration/checks/R02-G19-10.docs.json): device-campaign.md with rows MA-D1 … MA-D8 matching device-rows.json, devices in order, D3 on iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, no number claimed
  `docs/apps/apsides-workshop/device-campaign.md`, read against the gestures of feature 484: devices and order, D3 on
  iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, every row MA-D1 … MA-D8 with devices, procedure, pass condition
  and "pending device campaign", no number claimed, the stress session only in the device campaign); `--name docs --
  python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [ ] T-R02G1910-005 Docs: `docs/architecture/microscopic-aurora.md` (device preparation),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1910-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full` (nothing in the app changes)
- [ ] T-R02G1910-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1910-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1910-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows MA-D1 … MA-D8 on D1,
  D2, D3 (SC-R02G1910-004)
- [ ] T-R02G1910-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
