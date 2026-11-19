# Tasks: Visual Programming Lab — Phase 05 Resource-budget and usability testing

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/tests.md](contracts/tests.md), [quickstart.md](quickstart.md). Gate A23-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P05 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change; no device step; no audit run.
- **Precedent:** `specs/163-ss-p05-stress-recovery/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-501 Baseline: cite the A23-P04 evidence (`.autonomy/checks/A23-P04.{vpl-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-19: 2026-11-19: A23-P04 evidence cited: .autonomy/checks/A23-P04.vpl-ios27.json, A23-P04.app-unit.json and A23-P04.verify-27.json, all exit 0; since the A23-P04 record commit 993257e7 only Catalog files and the VisualCore catalog fixtures changed (e918deca, the A23 summary)
  the tree recorded at A23-P04 (`993257e7`); since then only the catalog summary fix `e918deca` changed (Catalog only)

## Phase 2: Stories 1–2 — no growth; exact passes (P1) 🎯

- [X] T-A23-502 [P] [US1] Write `Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/StressCycleTests.swift` — Verified 2026-11-19: 2026-11-19: StressCycleTests: 50 mixed cycles (a Mix added, wired, unwired and removed; the next example opened; a 7-slot graph refused; every 10th cycle a context rebuild), leaked 0 after every cycle, every cycle's level equal to the first cycle showing the same example (three examples hold 1, 2 and 3 slots, so cycle 50 is compared with cycle 2 and cycle 49 with cycle 1); the level comparison after a rebuild needed the pipeline fix of T-A23-504; .autonomy/checks/A23-P05.vpl-ios27.json exit 0 (162 core and 73 experience tests on sim-27.2); written by an agent, one #expect comment fixed by the lead, retested
  per clarification Q1 (SC-A23-501): 50 cycles (add, connect, disconnect and remove a Mix; open the next example; a
  7-slot graph through `graphOverride`, refused; back to the example; every 10th cycle a `recreateContext`), the level
  after cycle 1 equal to the level after cycle 50, `leaked` 0, each test under 10 s; fix any leak found in the
  experience and record it
- [X] T-A23-503 [P] [US2] Write `ExperienceTests/PassCountTests.swift` per clarification Q2 (SC-A23-502): Gradient into — Verified 2026-11-19: 2026-11-19: PassCountTests (3): Gradient into Output runs 2 passes per frame within 2 of 255 of its reference; with an unconnected Noise and a Constant still 2 passes and a byte-identical inset; the journey runs 6 (noise, gradient, mix, blur-h, blur-v, output); .autonomy/checks/A23-P05.vpl-ios27.json exit 0 (162 core and 73 experience tests on sim-27.2); written by an agent, retested
  Output runs 2 passes per frame and matches its reference within 2 of 255; with an unconnected Noise and a Constant
  it runs 2 and draws the same pixels; the journey graph runs 6

## Phase 3: Story 3 — recovery in every state (P2)

- [ ] T-A23-504 [US3] Write `ExperienceTests/RecoveryTests.swift` per clarification Q3 (SC-A23-503): in ready, invalid,
  refused, failed and hidden, 10 `recreateContext` calls each followed by a frame give a byte-identical still, the same
  state, the same level and `leaked` 0; a compile requested before a rebuild happens once after it; fix anything found

## Phase 4: Story 4 — usability on the phone (P2)

- [ ] T-A23-505 [P] [US4] Write `Apps/VisualCore/Tests/UI/VisualProgrammingLab/{VPLSupport,VPLCanvasUITests,VPLRecoveryUITests}.swift`
  per clarification Q4 and contracts/tests.md (SC-A23-504): the list-form journey to "Ready", the mismatched choice's
  refusal sentence, and save → terminate → relaunch → listed and opens; each under 60 s
- [ ] T-A23-506 Add the chunk `"e3": ["VPLCanvasUITests", "VPLRecoveryUITests"]` to `scripts/release_check.py` (`UI_CHUNKS`
  and `SERIAL_CHUNKS`) and any chunk list in `scripts/test_scripts.py` (lead)

## Phase 5: Story 5 — the device plan (P3)

- [X] T-A23-507 [P] [US5] Write `docs/apps/visual-programming-lab/device-campaign.md` per clarification Q5 (rows VPL-D1 to — Verified 2026-11-19: 2026-11-19: docs/apps/visual-programming-lab/device-campaign.md: rows VPL-D1 to VPL-D6 for D1 iPhone 15 (iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5 (18 rows, all pending; steps, expected results, owner actions; only code constants, no measured figure), linked from the README; validate_docs PASS; written by an agent, reviewed
  VPL-D6 for D1, D2, D3; steps, expected result, owner actions, state pending) after
  `docs/apps/shader-studio/device-campaign.md`, and link it from the README (SC-A23-505)

## Phase 6: Evidence

- [ ] T-A23-508 Review checkpoint: `--name vpl-ios27` (both package test targets on sim-27.2, each under 10 s), the
  documented API, isolation and core purity
- [ ] T-A23-509 Contract: G-DEVICE closed by "A23-P05" as the plan (its rows stay pending); M31 notes the pending rows
  (`--name contract`)
- [ ] T-A23-510 The catalog, packages and script tests; `xcodegen generate`; `--name app-unit -- python3 scripts/release_check.py
  --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-e3`; the runner (`--name verify-27`)
- [ ] T-A23-511 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → {502, 503, 504, 505, 507} → 506 → 508 → 509 → 510 → 511; 504 after 502 if both touch the presenter.

## Parallel examples

- **Agent S:** 502–504. **Agent U:** 505. **Agent V:** 507.
- **Lead:** 506, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the stress and pass-count proofs (502, 503).
- **Then:** recovery (504), the interface tests (505, 506) and the device plan (507).
- **Review checkpoint:** at 508.
- **Commits:** one per task.
