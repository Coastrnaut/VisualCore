# Tasks: R02-G08-10 — Faceted Forge: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G08-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G08-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G0810-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0
  --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G08-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [ ] T-R02G0810-002 [US1] Create `docs/apps/faceted-forge/device-rows.json` (data-model.md: "schema 1, sorted
  keys"; devices D1 → DEV1-R02-G08, D2 → DEV2-R02-G08, D3 → DEV3-R02-G08; the 12 scenarios of clarification Q2; rows
  FF-D1 … FF-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for FF-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g08`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g08.faceted-forge`
- [ ] T-R02G0810-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Faceted Forge definition passes; a
  copy with a scenario removed, a copy with FF-D1's `pass` field removed and a copy with T-R02G0809-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g08` runs the check for
  `r02-g08.faceted-forge`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [ ] T-R02G0810-004 [P] [US2] Create `docs/apps/faceted-forge/device-campaign.md` (agent B, modelled on
  `docs/apps/amethyst-escape/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row FF-D1 … FF-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [ ] T-R02G0810-005 Docs: `docs/architecture/faceted-forge.md` (device preparation),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0810-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (nothing in the app changes)
- [ ] T-R02G0810-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0810-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0810-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows FF-D1 … FF-D8 on D1,
  D2, D3 (SC-R02G0810-004)
- [ ] T-R02G0810-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1.
