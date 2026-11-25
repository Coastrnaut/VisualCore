# Tasks: R02-G16-10 — Starlit Cartouche: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/device-rows.md](contracts/device-rows.md), [quickstart.md](quickstart.md). Gate R02-G16-10 (migration
ledger). Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-G16-10 --name <check> -- <command>` (never
a scratchpad path; recorded only after every agent has reported). Commit after every task with its check record (no
trailers). No device is contacted. No {owner} tasks; one {device} task.

## Phase 1: Setup

- [X] T-R02G1610-001 Baselines after R02-G16-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code; rendering baseline is R02-G16-09's runs
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457; no Swift changes follow; the
  rendering baseline is R02-G16-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G1610-002 [US1] Create `docs/apps/starlit-cartouche/device-rows.json` (data-model.md: "schema 1, sorted — Verified 2026-11-25: 2026-11-25 device-rows exit 0 (8 rows, 12 scenarios; SC-D4 names every gesture of feature 454); release step device-rows-r02-g16 added
  keys"; devices D1 → DEV1-R02-G16, D2 → DEV2-R02-G16, D3 → DEV3-R02-G16; the 12 scenarios of clarification Q2; rows
  SC-D1 … SC-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false
  only for SC-D6), covers, owner_steps, status "pending device campaign"; no result field); edit
  `scripts/release_check.py` (step `device-rows-r02-g16`); `--name device-rows -- python3 scripts/check_device_rows.py
  --experience r02-g16.starlit-cartouche`
- [X] T-R02G1610-003 [P] [US1] Edit `scripts/test_scripts.py` (agent A: the real Starlit Cartouche definition passes; a — Verified 2026-11-25: 2026-11-25 script-tests exit 0, run alone (StarlitCartoucheDeviceRowsCheckTests: the real definition passes; a removed scenario, a removed pass field and two dropped covered tasks fail by name; the release step runs the check)
  copy with a scenario removed, a copy with SC-D1's `pass` field removed and a copy with T-R02G1609-011 dropped from
  every row's covers each fail by name; the release step `device-rows-r02-g16` runs the check for
  `r02-g16.starlit-cartouche`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G1610-004 [P] [US2] Create `docs/apps/starlit-cartouche/device-campaign.md` (agent B, modelled on — Verified 2026-11-25: 2026-11-25 docs exit 0 (validate_docs); written plan by agent B, read against device-rows.json and the gestures of feature 454 by the lead, one rule sentence corrected
  `docs/apps/voxel-origami/device-campaign.md`, read against the gestures of feature 454: devices and order, D3 on
  iPadOS 26.5, owner actions as BLOCKED_OWNER_ACTION, every row SC-D1 … SC-D8 with devices, procedure, pass condition
  and "pending device campaign", no number claimed, the stress session only in the device campaign); `--name docs --
  python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [X] T-R02G1610-005 Docs: `docs/architecture/starlit-cartouche.md` (device preparation), — Verified 2026-11-25: 2026-11-25 docs updated (architecture device preparation, round-two README, automatedtesting); round-two host evidence is this gate's baseline-round02-1, -2, -3c, -3e, -3f (exit 0): no file under Packages or Apps changed since R02-G16-09's record, so no duplicate run (owner rule: no baseline rerun on an unchanged commit)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1610-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (nothing in the app changes)
- [ ] T-R02G1610-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1610-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1610-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows SC-D1 … SC-D8 on D1,
  D2, D3 (SC-R02G1610-004)
- [ ] T-R02G1610-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, docs) stay with the lead except the two agent files. MVP: Story 1. Requirement coverage:
FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008.
