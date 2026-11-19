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

- [X] T-A23-504 [US3] Write `ExperienceTests/RecoveryTests.swift` per clarification Q3 (SC-A23-503): in ready, invalid, — Verified 2026-11-19: 2026-11-19: RecoveryTests (7): 10 rebuilds each in ready, invalid, refused, failed and hidden give a byte-identical still, the same state, schedule, slots, compile count and level, leaked 0; an edit before a rebuild compiles once after it; defect found and fixed in PreviewPipeline.swift: a rebuild in the invalid or refused state did not rebuild the slots and programs held from the last good schedule (restore only acted in ready) and shrank the program cache, so release now notes what is held and restore rebuilds it; .autonomy/checks/A23-P05.vpl-ios27.json exit 0 (162 core and 73 experience tests on sim-27.2); written by an agent, retested
  refused, failed and hidden, 10 `recreateContext` calls each followed by a frame give a byte-identical still, the same
  state, the same level and `leaked` 0; a compile requested before a rebuild happens once after it; fix anything found

## Phase 4: Story 4 — usability on the phone (P2)

- [X] T-A23-505 [P] [US4] Write `Apps/VisualCore/Tests/UI/VisualProgrammingLab/{VPLSupport,VPLCanvasUITests,VPLRecoveryUITests}.swift` — Verified 2026-11-19: 2026-11-19: Apps/VisualCore/Tests/UI/VisualProgrammingLab/{VPLSupport,VPLCanvasUITests,VPLRecoveryUITests}.swift: the list-form Mix journey to Ready (44.7 s), a mismatched choice's refusal sentence (29.4 s), a saved graph listed and opened after a relaunch (37.6 s), all passing in .autonomy/checks/A23-P05.app-unit-2.json on the iOS 27.2 phone; the first run (A23-P05.app-unit.json) failed because XCTest never saw the app idle while a SwiftUI menu was open over the canvas, which presents 30 frames a second, so LabControls' Add node, Examples and input pickers became inline expanding button lists (add-node-<kind>, example-<id>, input-<id>-<index>-option-<tag>); A23-P05.vpl-ios27-2.json exit 0 after the change; written by agents, retested
  per clarification Q4 and contracts/tests.md (SC-A23-504): the list-form journey to "Ready", the mismatched choice's
  refusal sentence, and save → terminate → relaunch → listed and opens; each under 60 s
- [X] T-A23-506 Add the chunk `"e3": ["VPLCanvasUITests", "VPLRecoveryUITests"]` to `scripts/release_check.py` (`UI_CHUNKS` — Verified 2026-11-19: 2026-11-19: scripts/release_check.py UI_CHUNKS e3 = VPLCanvasUITests, VPLRecoveryUITests, serial (SERIAL_CHUNKS); release_check --list shows app-ui-ios27-e3; A23-P05.app-unit-2.json exit 0
  and `SERIAL_CHUNKS`) and any chunk list in `scripts/test_scripts.py` (lead)

## Phase 5: Story 5 — the device plan (P3)

- [X] T-A23-507 [P] [US5] Write `docs/apps/visual-programming-lab/device-campaign.md` per clarification Q5 (rows VPL-D1 to — Verified 2026-11-19: 2026-11-19: docs/apps/visual-programming-lab/device-campaign.md: rows VPL-D1 to VPL-D6 for D1 iPhone 15 (iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5 (18 rows, all pending; steps, expected results, owner actions; only code constants, no measured figure), linked from the README; validate_docs PASS; written by an agent, reviewed
  VPL-D6 for D1, D2, D3; steps, expected result, owner actions, state pending) after
  `docs/apps/shader-studio/device-campaign.md`, and link it from the README (SC-A23-505)

## Phase 6: Evidence

- [X] T-A23-508 Review checkpoint: `--name vpl-ios27` (both package test targets on sim-27.2, each under 10 s), the — Verified 2026-11-19: 2026-11-19: review checkpoint: .autonomy/checks/A23-P05.vpl-ios27-2.json exit 0 (162 core and 73 experience tests on sim-27.2, after the inline lists), A23-P05.documented-api.json, A23-P05.isolation.json and A23-P05.core-purity.json exit 0
  documented API, isolation and core purity
- [X] T-A23-509 Contract: G-DEVICE closed by "A23-P05" as the plan (its rows stay pending); M31 notes the pending rows — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P05.contract.json exit 0 (G-DEVICE closed by A23-P05 as the plan; M31 available with a note that its device rows stay pending)
  (`--name contract`)
- [X] T-A23-510 The catalog, packages and script tests; `xcodegen generate`; `--name app-unit -- python3 scripts/release_check.py — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P05.catalog.json, A23-P05.experience-packages.json and A23-P05.script-tests.json exit 0; xcodegen generate; A23-P05.app-unit-2.json exit 0 (build for testing, app unit tests and the e3 interface chunk on the iOS 27.2 phone); A23-P05.verify-27.json exit 0 (all 9 scenarios on iOS 27.2)
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

## Phase 7: Convergence

- [X] T-A23-512 Record the as-built design in `specs/170-vpl-p05-budget-usability/{data-model.md,contracts/tests.md}` and `specs/167-vpl-p02-node-canvas/contracts/experience.md` (as an A23-P05 note), per SC-A23-501, clarification Q4 and contracts/tests.md (contradicts, unrequested): — Verified 2026-11-19: 2026-11-19: as-built notes in data-model.md (stress comparison, held/restore), contracts/tests.md (inline lists, ids) and specs/167 contracts/experience.md (A23-P05 note); .autonomy/checks/A23-P05.documented-api-2.json exit 0; validate_docs 186 dossiers 0 problems
  - the stress comparison: the three examples hold 1, 2 and 3 slots, so each cycle's level is compared with the first cycle showing the same example (cycle 49 with cycle 1, cycle 50 with cycle 2), with `leaked` 0 after every cycle; `LabLevel` is in StressCycleTests;
  - the Add node menu, the Examples menu and the list form's pickers became inline expanding button lists (`add-node` with `add-node-<kind>`, `examples` with `example-<id>`, `input-<id>-<index>` with `input-<id>-<index>-option-<tag>`), because XCTest never saw the app idle while a system menu was open over a canvas presenting 30 frames a second;
  - `PreviewPipeline` notes the programs and slots it holds on release and rebuilds them on restore in every state but failed, so a rebuild keeps the level in the invalid and refused states.
