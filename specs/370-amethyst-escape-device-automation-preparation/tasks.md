# Tasks: R02-G07-10 — Amethyst Escape: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G07-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G07-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G0710-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0; rendering baseline is R02-G07-09's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G07-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G0710-002 [US1] Create `docs/apps/amethyst-escape/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-22: device-rows exit=0 (device-rows r02-g07.amethyst-escape: PASS (8 rows, 12 scenarios)); release_check step device-rows-r02-g07
  keys"; devices D1 → DEV1-R02-G07, D2 → DEV2-R02-G07, D3 → DEV3-R02-G07; the 12 scenarios of clarification Q2; rows
  AE-D1 … AE-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for AE-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g07`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g07.amethyst-escape`
- [X] T-R02G0710-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Amethyst Escape definition passes; a — Verified 2026-11-22: script-tests exit=0 (run alone; AmethystEscapeDeviceRowsCheckTests 6/6: real definition passes, removed scenario, missing pass field and uncovered T-R02G0709-011 fail by name, release step runs the check)
  copy with a scenario removed, a copy with AE-D1's `pass` field removed and a copy with T-R02G0709-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g07` runs the check for
  `r02-g07.amethyst-escape`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G0710-004 [P] [US2] Create `docs/apps/amethyst-escape/device-campaign.md` (agent B, modelled on — Verified 2026-11-22: docs exit=0; docs/apps/amethyst-escape/device-campaign.md: D1 → D2 → D3 (D3 stays on iPadOS 26.5), owner actions as BLOCKED_OWNER_ACTION, rows AE-D1 … AE-D8 pending, no number claimed
  `docs/apps/chrono-constellator/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row AE-D1 … AE-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G0710-005 Docs: `docs/architecture/amethyst-escape.md` (device preparation), — Verified 2026-11-22: round02-host exit=0; docs/architecture/amethyst-escape.md device preparation, ExperiencesRound02 README feature 370, docs/automatedtesting.md entry
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0710-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full exit=0 (nothing in the app changes)
  `--name host-full` (nothing in the app changes)
- [X] T-R02G0710-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [X] T-R02G0710-008 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: reference-2 exit=0
- [ ] T-R02G0710-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows AE-D1 … AE-D8 on D1,
  D2, D3 (SC-R02G0710-004)
- [X] T-R02G0710-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-22: converge clean (no tasks appended); sealed 13 passing checks; recorded pass
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1.
