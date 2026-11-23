# Tasks: R02-G10-10 — Backwards Aurora: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G10-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G10-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1010-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0, 2026-11-23; rendering baseline is R02-G10-09's runs (exit 0)
  --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G10-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1010-002 [US1] Create `docs/apps/backwards-aurora/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-23: device-rows (check_device_rows.py --experience r02-g10.backwards-aurora: PASS, 8 rows, 12 scenarios, every open {device} task of 391-399 covered) exit 0, 2026-11-23; release step device-rows-r02-g10 added; BA-D3 to BA-D8 written for the reversal controls; the copied D4 owner step corrected here and in Nocturne Garden's definition
  keys"; devices D1 → DEV1-R02-G10, D2 → DEV2-R02-G10, D3 → DEV3-R02-G10; the 12 scenarios of clarification Q2; rows
  BA-D1 … BA-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for BA-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g10`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g10.backwards-aurora`
- [X] T-R02G1010-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Backwards Aurora definition passes; a — Verified 2026-11-23: script-tests (run alone, incl. BackwardsAuroraDeviceRowsCheckTests 6: the real definition passes, a removed scenario, a missing BA-D1 pass field and an uncovered T-R02G1009-011 each fail by name, the release step runs the check) exit 0, 2026-11-23; agent A's tests retested by the lead
  copy with a scenario removed, a copy with BA-D1's `pass` field removed and a copy with T-R02G1009-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g10` runs the check for
  `r02-g10.backwards-aurora`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1010-004 [P] [US2] Create `docs/apps/backwards-aurora/device-campaign.md` (agent B, modelled on — Verified 2026-11-23: docs (validate_docs.py) exit 0, 2026-11-23; docs/apps/backwards-aurora/device-campaign.md: devices in order, D3 on iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, rows BA-D1 to BA-D8 pending, no number claimed; agent B's file reviewed by the lead
  `docs/apps/nocturne-garden/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row BA-D1 … BA-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1010-005 Docs: `docs/architecture/backwards-aurora.md` (device preparation), — Verified 2026-11-23: round02-host exit 0, 2026-11-23; architecture device preparation, package README feature 400, testing entry (Backwards Aurora device rows); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1010-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0, 2026-11-23 (nothing in the app changes)
  `--name host-full` (nothing in the app changes)
- [ ] T-R02G1010-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1010-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1010-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows BA-D1 … BA-D8 on D1,
  D2, D3 (SC-R02G1010-004)
- [ ] T-R02G1010-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1.
