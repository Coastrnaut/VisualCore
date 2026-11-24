# Tasks: R02-G14-10 — Moonlit Mechanism: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G14-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G14-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1410-001 Baselines after R02-G14-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G14-10.baseline-*.json); rendering baseline = R02-G14-09 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G14-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1410-002 [US1] Create `docs/apps/moonlit-mechanism/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-24: 2026-11-24: device-rows.json (12 scenarios, MM-D1 … MM-D8, DEV1/2/3-R02-G14), release step device-rows-r02-g14; device-rows exit 0: PASS (8 rows, 12 scenarios) (.autonomy/migration/checks/R02-G14-10.device-rows.json)
  keys"; devices D1 → DEV1-R02-G14, D2 → DEV2-R02-G14, D3 → DEV3-R02-G14; the 12 scenarios of clarification Q2; rows
  MM-D1 … MM-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for MM-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g14`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g14.moonlit-mechanism`
- [X] T-R02G1410-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Moonlit Mechanism definition passes; a — Verified 2026-11-24: 2026-11-24: agent A MoonlitMechanismDeviceRowsCheckTests (8 tests: real definition passes, removals fail by name, release step); lead retest script-tests exit 0 alone (.autonomy/migration/checks/R02-G14-10.script-tests.json)
  copy with a scenario removed, a copy with MM-D1's `pass` field removed and a copy with T-R02G1409-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g14` runs the check for
  `r02-g14.moonlit-mechanism`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1410-004 [P] [US2] Create `docs/apps/moonlit-mechanism/device-campaign.md` (agent B, modelled on — Verified 2026-11-24: 2026-11-24: agent B device-campaign.md (rows MM-D1 … MM-D8 word for word with the definition, MM-D3 gesture wording corrected in both); docs exit 0 (.autonomy/migration/checks/R02-G14-10.docs.json)
  `docs/apps/acoustic-constellator/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions as
  BLOCKED_OWNER_ACTION, every row MM-D1 … MM-D8 with devices, procedure, pass condition and "pending device campaign",
  no number claimed, the stress session only in the device campaign); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1410-005 Docs: `docs/architecture/moonlit-mechanism.md` (device preparation), — Verified 2026-11-24: 2026-11-24: architecture device preparation section, ExperiencesRound02 README, testing doc; round02-host exit 0 (.autonomy/migration/checks/R02-G14-10.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1410-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (nothing in the app changes)
- [ ] T-R02G1410-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1410-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1410-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows MM-D1 … MM-D8 on D1,
  D2, D3 (SC-R02G1410-004)
- [ ] T-R02G1410-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
