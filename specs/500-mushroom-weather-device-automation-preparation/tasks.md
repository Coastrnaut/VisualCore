# Tasks: R02-G20-10 — Mushroom Weather: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G20-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G20-10 --name <check> -- <command>` (never
a scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G2010-001 Baselines after R02-G20-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G20-10.baseline-*.json)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3f with `MushroomWeather`; no Swift changes
  follow; the rendering baseline is R02-G20-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G2010-002 [US1] Create `docs/apps/mushroom-weather/device-rows.json` (data-model.md: "schema 1, sorted keys"; — Verified 2026-11-27: device-rows exit=0, PASS (8 rows, 12 scenarios) (.autonomy/migration/checks/R02-G20-10.device-rows.json); release step device-rows-r02-g20
  devices D1 → DEV1-R02-G20, D2 → DEV2-R02-G20, D3 → DEV3-R02-G20; the 12 scenarios of clarification Q2; rows MW-D1 …
  MW-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false only
  for MW-D6), covers, owner_steps, status "pending device campaign"; no result field); edit `scripts/release_check.py`
  (step `device-rows-r02-g20`); `--name device-rows -- python3 scripts/check_device_rows.py --experience
  r02-g20.mushroom-weather`
- [X] T-R02G2010-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Mushroom Weather definition passes; a — Verified 2026-11-27: script-tests exit=0, 808 tests incl. MushroomWeatherDeviceRowsCheckTests (8) (.autonomy/migration/checks/R02-G20-10.script-tests.json)
  copy with a scenario removed, a copy with MW-D1's `pass` field removed and a copy with T-R02G2009-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g20` runs the check for
  `r02-g20.mushroom-weather`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G2010-004 [P] [US2] Create `docs/apps/mushroom-weather/device-campaign.md` (agent B, modelled on — Verified 2026-11-27: docs exit=0 (.autonomy/migration/checks/R02-G20-10.docs.json); campaign plan with D3 on iPadOS 26.5 not updated, owner actions as BLOCKED_OWNER_ACTION, rows MW-D1 … MW-D8 pending
  `docs/apps/microscopic-aurora/device-campaign.md`, read against the gestures of feature 494: devices and order, D3 on
  iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, every row MW-D1 … MW-D8 with devices, procedure, pass condition
  and "pending device campaign", no number claimed, the stress session only in the device campaign); `--name docs --
  python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [ ] T-R02G2010-005 Docs: `docs/architecture/mushroom-weather.md` (device preparation),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2010-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full` (nothing in the app changes)
- [ ] T-R02G2010-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2010-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2010-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows MW-D1 … MW-D8 on D1,
  D2, D3 (SC-R02G2010-004)
- [ ] T-R02G2010-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
