# Tasks: R02-G12-10 — Harmonic Bridges: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G12-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G12-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1210-001 Baselines after R02-G12-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0; no Swift changes follow
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G12-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1210-002 [US1] Create `docs/apps/harmonic-bridges/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-23: device-rows (check_device_rows.py --experience r02-g12.harmonic-bridges: PASS, 8 rows, 12 scenarios; devices DEV1/2/3-R02-G12; all six {device} tasks of 413-419 and the UA-F13 measurements covered) exit 0; release step device-rows-r02-g12 added
  keys"; devices D1 → DEV1-R02-G12, D2 → DEV2-R02-G12, D3 → DEV3-R02-G12; the 12 scenarios of clarification Q2; rows
  HB-D1 … HB-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for HB-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g12`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g12.harmonic-bridges`
- [X] T-R02G1210-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Harmonic Bridges definition passes; a — Verified 2026-11-23: script-tests (alone) exit 0, incl. HarmonicBridgesDeviceRowsCheckTests (8 tests: the real definition passes with 8 rows and 12 scenarios; a scenario removed from the manifest, an unknown scenario, HB-D1 without pass, T-R02G1209-011 and T-R02G1204-011 uncovered each fail by name; the release step device-rows-r02-g12 runs the check), lead retest
  copy with a scenario removed, a copy with HB-D1's `pass` field removed and a copy with T-R02G1209-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g12` runs the check for
  `r02-g12.harmonic-bridges`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1210-004 [P] [US2] Create `docs/apps/harmonic-bridges/device-campaign.md` (agent B, modelled on — Verified 2026-11-23: docs (validate_docs passes); docs/apps/harmonic-bridges/device-campaign.md written from the checked definition: devices in order, D3 on iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, rows HB-D1 ... HB-D8 with devices, procedure, measurements, pass, gating, covers, owner steps and 'pending device campaign', no number claimed
  `docs/apps/echo-cartographer/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row HB-D1 … HB-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1210-005 Docs: `docs/architecture/harmonic-bridges.md` (device preparation), — Verified 2026-11-23: round02-host exit 0; architecture doc device preparation, ExperiencesRound02 README feature 420, testing doc entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1210-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0 (nothing in the app changes)
  `--name host-full` (nothing in the app changes)
- [X] T-R02G1210-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit 0
- [X] T-R02G1210-008 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit 0
- [ ] T-R02G1210-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows HB-D1 … HB-D8 on D1,
  D2, D3 (SC-R02G1210-004)
- [ ] T-R02G1210-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
