# Tasks: R02-G13-10 — Acoustic Constellator: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G13-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G13-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1310-001 Baselines after R02-G13-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on b7ac87e88 (.autonomy/migration/checks/R02-G13-10.baseline-*.json); rendering baseline = R02-G13-09 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G13-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1310-002 [US1] Create `docs/apps/acoustic-constellator/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-24: 2026-11-24: device-rows.json (schema 1; D1-D3 tied to DEV1/2/3-R02-G13; 12 scenarios; ACN-D1…D8 pending, ACN-D6 non-gating), release step device-rows-r02-g13; device-rows exit 0, PASS (8 rows, 12 scenarios) (.autonomy/migration/checks/R02-G13-10.device-rows.json)
  keys"; devices D1 → DEV1-R02-G13, D2 → DEV2-R02-G13, D3 → DEV3-R02-G13; the 12 scenarios of clarification Q2; rows
  ACN-D1 … ACN-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for ACN-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g13`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g13.acoustic-constellator`
- [X] T-R02G1310-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Acoustic Constellator definition passes; a — Verified 2026-11-24: 2026-11-24: agent A 8 tests (AcousticConstellatorDeviceRowsCheckTests: real definition passes; scenario, field and covered-task removals fail by name; release step); lead retest OK; script-tests exit 0 (.autonomy/migration/checks/R02-G13-10.script-tests.json)
  copy with a scenario removed, a copy with ACN-D1's `pass` field removed and a copy with T-R02G1309-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g13` runs the check for
  `r02-g13.acoustic-constellator`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1310-004 [P] [US2] Create `docs/apps/acoustic-constellator/device-campaign.md` (agent B, modelled on — Verified 2026-11-24: 2026-11-24: agent B written plan (devices in order, D3 on iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, ACN-D1…D8 word for word from the definition, no number); docs exit 0 (.autonomy/migration/checks/R02-G13-10.docs.json)
  `docs/apps/harmonic-bridges/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row ACN-D1 … ACN-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1310-005 Docs: `docs/architecture/acoustic-constellator.md` (device preparation), — Verified 2026-11-24: 2026-11-24: architecture device-preparation section, ExperiencesRound02 README feature 430, testing doc; round02-host exit 0 (.autonomy/migration/checks/R02-G13-10.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1310-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G13-10.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full` (nothing in the app changes)
- [X] T-R02G1310-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G13-10.reference-1.json)
- [X] T-R02G1310-008 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-24: 2026-11-24: reference-2 exit 0 (.autonomy/migration/checks/R02-G13-10.reference-2.json)
- [ ] T-R02G1310-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows ACN-D1 … ACN-D8 on D1,
  D2, D3 (SC-R02G1310-004)
- [ ] T-R02G1310-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
