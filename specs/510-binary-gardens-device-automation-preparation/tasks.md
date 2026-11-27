# Tasks: R02-G21-10 — Binary Gardens: device automation preparation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-10 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-10 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No device
is contacted. No {owner} tasks; one {device} task. Prerequisites: R02-G21-05 … R02-G21-09 recorded.

## Phase 1: Setup

- [X] T-R02G2110-001 Baselines after R02-G21-09 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1/2/3c/3e/3f exit=0
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 2 with `BinaryGardens`; no Swift changes
  follow; the rendering baseline is R02-G21-09's runs)

## Phase 2: Story 1 — the campaign knows what to run (P1) 🎯

- [X] T-R02G2110-002 [US1] Create `docs/apps/binary-gardens/device-rows.json` (data-model.md: "schema 1, sorted keys"; — Verified 2026-11-27: device-rows.json (8 rows, 12 scenarios) and release step device-rows-r02-g21 installed; device-rows exit=0: PASS (8 rows, 12 scenarios)
  devices D1 → DEV1-R02-G21, D2 → DEV2-R02-G21, D3 → DEV3-R02-G21; the 12 scenarios of clarification Q2; rows BG-D1 …
  BG-D8 of clarification Q1 with title, devices, procedure, measurements, pass (clarification Q5), gating (false only
  for BG-D6), covers, owner_steps, status "pending device campaign"; no result field; BG-D8 reads the panel's win text,
  BG-D5 and BG-D6 quote feature 506's announcements as recorded); edit `scripts/release_check.py` (step
  `device-rows-r02-g21`); `--name device-rows -- python3 scripts/check_device_rows.py --experience
  r02-g21.binary-gardens` (expected `device-rows r02-g21.binary-gardens: PASS (8 rows, 12 scenarios)`)
- [X] T-R02G2110-003 [P] [US1] Write `BinaryGardensDeviceRowsCheckTests` (agent A, as a separate file the lead inserts — Verified 2026-11-27: BinaryGardensDeviceRowsCheckTests (8 tests) inserted into test_scripts.py; script-tests exit=0 (run alone)
  into `scripts/test_scripts.py` above the `if __name__ == "__main__":` block: the real Binary Gardens definition passes;
  a copy with a scenario removed, a copy with BG-D1's `pass` field removed, a copy naming an unknown scenario, a copy
  with T-R02G2109-011 and a copy with T-R02G2104-011 dropped from every row's covers each fail by name with the five
  reasons of contracts/api.md; the release step `device-rows-r02-g21` runs the
  check for `r02-g21.binary-gardens`); `--name script-tests` (alone)

## Phase 3: Story 2 — a person can follow the plan (P2)

- [X] T-R02G2110-004 [P] [US2] Create `docs/apps/binary-gardens/device-campaign.md` (agent B, modelled on — Verified 2026-11-27: device-campaign.md installed; lead review: ids BG-D1 … BG-D8, titles, devices D1/D2/D3 and gating (BG-D6 non-gating) equal device-rows.json; D3 26.5 and BLOCKED_OWNER_ACTION stated; docs exit=0
  `docs/apps/mushroom-weather/device-campaign.md`, read against the gestures of feature 504: devices and order, D3 on
  iPadOS 26.5 never updated, owner actions as BLOCKED_OWNER_ACTION, every row BG-D1 … BG-D8 with devices, procedure,
  pass condition and "pending device campaign", no number claimed, the stress session only in the device campaign);
  the lead reviews that its ids, titles, devices and gating equal the definition's and records the review in the tick
  (User Story 2, scenario 2); `--name docs -- python3 scripts/validate_docs.py`

## Phase 4: Regression, documentation and close

- [ ] T-R02G2110-005 Docs: `docs/architecture/binary-gardens.md` (device preparation),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2110-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full` (nothing in the app changes)
- [ ] T-R02G2110-007 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2110-008 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2110-009 {device} After ImplementationLock-100: the device campaign (UA-F13) runs rows BG-D1 … BG-D8 on D1,
  D2, D3 (SC-R02G2110-004)
- [ ] T-R02G2110-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 … 008, 010. 009 stays open until device testing. Shared files
(definition, release_check.py, script tests, docs) stay with the lead except the two agent files. MVP: Story 1.
Requirement coverage: FR-001 → 002; FR-002 → 004; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 → 005 … 008; FR-006 →
002, 003.
