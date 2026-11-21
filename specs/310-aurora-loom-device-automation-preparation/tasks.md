# Tasks: R02-G01-10 — Aurora Loom: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G01-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G01-10 --name <check> -- <command>` (never a
scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G0110-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G01-10.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02` (no Swift changes follow; the rendering baseline is R02-G01-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G0110-002 [US1] Create `docs/apps/aurora-loom/device-rows.json` (data-model.md: "schema 1, sorted keys"; — Verified 2026-11-21: 2026-11-21 device-rows exit 0 (docs/apps/aurora-loom/device-rows.json: schema 1, D1-D3 tied to DEV1-3-R02-G01, 12 scenarios, rows AL-D1 to AL-D8 pending, no result field)
  devices D1 → DEV1-R02-G01, D2 → DEV2-R02-G01, D3 → DEV3-R02-G01; the 12 scenarios of clarification Q2; rows AL-D1 …
  AL-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false only for
  AL-D6), covers, owner_steps, status "pending device campaign"; no result field)
- [ ] T-R02G0110-003 [P] [US1] Create `scripts/check_device_rows.py` (contracts/device-rows.md; clarification Q4: shape,
  manifest, ledger, coverage of the open {device} task lines of `specs/30[1-9]-aurora-loom-*/tasks.md` (301–309 only), the three
  R02-G01-06 items and the six UA-F13 names; named failures; exit codes) with tests in `scripts/test_scripts.py` (agent
  A: the real definition passes; a removed scenario, a missing field, an uncovered item, a result field, a schema 2, an
  unreadable file and an unknown experience each fail by name); `--name device-rows -- python3
  scripts/check_device_rows.py --experience r02-g01.aurora-loom`; `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [ ] T-R02G0110-004 [P] [US2] Create `docs/apps/aurora-loom/device-campaign.md` (agent B, modelled on
  `docs/apps/aurora/device-campaign.md`: devices and order, D3 on iPadOS 26.5, owner actions, every row AL-D1 … AL-D8 with
  devices, procedure, pass condition and "pending device campaign", no number claimed, short runs bounded by arithmetic
  except the UA-F13 stress session, which only the device campaign runs); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [ ] T-R02G0110-005 Lead: edit `scripts/release_check.py` (step `device-rows` running the check); docs:
  `docs/architecture/aurora-loom.md` (device preparation), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0110-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (nothing in the app changes)
- [ ] T-R02G0110-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0110-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0110-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows AL-D1 … AL-D8 on D1,
  D2, D3 (SC-R02G0110-004)
- [ ] T-R02G0110-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1.
