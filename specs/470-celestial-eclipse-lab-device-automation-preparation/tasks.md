# Tasks: R02-G17-10 — Celestial Eclipse Lab: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G17-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G17-10 --name <check> -- <command>` (never
a scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1710-001 Baselines after R02-G17-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0 on the committed R02-G17-09 record; rendering baseline is R02-G17-09's runs
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3c with `CelestialEclipseLab`; no Swift
  changes follow; the rendering baseline is R02-G17-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1710-002 [US1] Create `docs/apps/celestial-eclipse-lab/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-25: 2026-11-25 device-rows exit 0 (8 rows, 12 scenarios; CEL-D4 names every gesture of feature 464); release step device-rows-r02-g17 added
  keys"; devices D1 → DEV1-R02-G17, D2 → DEV2-R02-G17, D3 → DEV3-R02-G17; the 12 scenarios of clarification Q2; rows
  CEL-D1 … CEL-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating
  (false only for CEL-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g17`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g17.celestial-eclipse-lab`
- [X] T-R02G1710-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Celestial Eclipse Lab definition — Verified 2026-11-25: 2026-11-25 script-tests-device-rows exit 0 (CelestialEclipseLabDeviceRowsCheckTests, 8 tests)
  passes; a copy with a scenario removed, a copy with CEL-D1's `pass` field removed and a copy with T-R02G1709-011
  dropped from every row's covers each fail by name; the release step `device-rows-r02-g17` runs the check for
  `r02-g17.celestial-eclipse-lab`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1710-004 [P] [US2] Create `docs/apps/celestial-eclipse-lab/device-campaign.md` (agent B, modelled on — Verified 2026-11-25: 2026-11-25 plan read against device-rows.json, spec and sources by the lead (panel labels, gestures, level 1 plan, devices); no Retry or second-tap fly sentence carried over
  `docs/apps/starlit-cartouche/device-campaign.md`, read against the gestures of feature 464: devices and order, D3 on
  iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, every row CEL-D1 … CEL-D8 with devices, procedure, pass condition
  and "pending device campaign", no number claimed, the stress session only in the device campaign); `--name docs --
  python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1710-005 Docs: `docs/architecture/celestial-eclipse-lab.md` (device preparation), — Verified 2026-11-25: 2026-11-25 docs updated (architecture device preparation, package README, automatedtesting); round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1710-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full exit 0 (no app sources changed, app-unit not rerun)
  `--name host-full` (nothing in the app changes)
- [X] T-R02G1710-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0
- [ ] T-R02G1710-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1710-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows CEL-D1 … CEL-D8 on
  D1, D2, D3 (SC-R02G1710-004)
- [ ] T-R02G1710-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
