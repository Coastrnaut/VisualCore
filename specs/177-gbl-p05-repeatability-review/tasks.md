# Tasks: Graphics Benchmark Lab — Phase 05 Repeatability, thermal and methodology review

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/review.md](contracts/review.md), [quickstart.md](quickstart.md). Gate A24-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P05 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change; no device run.
- **Precedent:** `specs/170-vpl-p05-budget-usability/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A24-501 Baseline: cite the A24-P04 evidence (`.autonomy/checks/A24-P04.{gbl-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.{gbl-ios27,app-unit,verify-27}.json exit 0 at A24-P04; Packages unchanged since 5553af36
  the tree recorded at A24-P04 (`5553af36`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Core — qualification and repeatability (P1) 🎯

- [X] T-A24-502 [P] [US1] `Core/RunQualification.swift` per clarification Q1 (FR-A24-501) and — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P05.gbl-core.json exit 0 (95 core and 53 experience tests); RunQualification (classes, ten reasons in fixed order, sentences) and RunQualificationTests (8)
  `CoreTests/RunQualificationTests.swift` (SC-A24-501): one fixture per class and reason, reasons in their fixed order,
  every sentence
- [X] T-A24-503 [P] [US2] `Core/Repeatability.swift` per clarification Q3 (FR-A24-503) and — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P05.gbl-core.json exit 0 (95 core and 53 experience tests); Repeatability (comparability keys, not-comparable reasons, spreads) and RepeatabilityTests (7)
  `CoreTests/RepeatabilityTests.swift` (SC-A24-502): three comparable trials and their spread; each not-comparable
  reason; one trial; a mixed GPU set (no GPU spread)
- [X] T-A24-504 [US1] `Core/RunCSV.swift` version 2 (`qualification`, `qualification_reasons` after `state`), the golden — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P05.gbl-core.json exit 0 (95 core and 53 experience tests); RunCSV version 2 with qualification rows after state, golden CSV regenerated (CRLF), RunCSVTests (9)
  CSV regenerated through the real writer, `RunCSVTests` updated (FR-A24-502)

## Phase 3: Experience — display and explanation (P1)

- [X] T-A24-505 [US1] [US2] [US3] `Experience/{GBLExplanation,ExplanationView,RepeatabilityView}.swift` and the — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P05.gbl-ios27.json (62 experience tests) and A24-P05.copy-explanation.json, exit 0
  `ResultsView`, `BenchPresenter`, `GBLControls` changes (FR-A24-502, 503, 504; contracts/review.md identifiers): the
  qualification in the list and the opened result, the repeatability block, `explain` from both, spoken headings
- [X] T-A24-506 [US1] [US3] `ExperienceTests/{QualificationDisplayTests,ExplanationTests}.swift`: the list and the — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P05.gbl-ios27.json: 62 experience tests in 11 suites, exit 0
  opened result show the class and sentences; an interrupted run (an interval over 1,000 ms after a pause) is
  invalid; the explanation names every limit of US3 and is reachable from a result and from repeatability; then
  `--name copy-explanation -- python3 scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --swift
  Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/GBLExplanation.swift` (SC-A24-503)

## Phase 4: Interface and device plan (P2)

- [X] T-A24-507 [P] [US4] `Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab/{GBLSupport,GBLRunUITests}.swift` per — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P05.app-ui-2.json: f3 GBLRunUITests 2 tests passed on iOS 27.2 phone, exit 0 (first run app-ui failed: journey clock included launch; usleep-polled app.state never refreshed; both fixed)
  clarification Q5, and chunk `f3` in `scripts/release_check.py` (lead, serial) (FR-A24-505, SC-A24-504)
- [X] T-A24-508 [P] [US5] `docs/apps/graphics-benchmark-lab/device-campaign.md`: GBL-D1 … GBL-D6 × D1, D2, D3 — Verified 2026-11-19: 2026-11-19: docs/apps/graphics-benchmark-lab/device-campaign.md: GBL-D1 … GBL-D6 on D1, D2, D3 (18 rows), all pending, no device number claimed; validate_docs passes
  (repeatability of each case over 5 trials, thermal states over a 10-run series, Low Power Mode, display refresh, GPU
  timer availability and plausibility, the system accessibility audits), steps, expected result, owner actions,
  state `pending`, and "no device number is claimed" (FR-A24-506, SC-A24-505)

## Phase 5: Evidence

- [ ] T-A24-509 Review checkpoint: `--name gbl-ios27`, documented API, isolation, core purity, scan-identifiers
- [ ] T-A24-510 App and interface: `xcodegen generate --spec project.yml`, then `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-f3`
- [ ] T-A24-511 Contract: G-DEVICE and G-EXPLAIN closed by "A24-P05", rows whose gaps are all closed available
  (`--name contract`); README of the experience; `--name catalog`, `experience-packages`, `script-tests`,
  `verify-27`
- [ ] T-A24-512 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → {502, 503, 507, 508}; 502 → 504; {502, 503, 504} → 505 → 506; {506, 507, 508} → 509 → 510 → 511 → 512.

## Parallel examples

- **Agent C:** 502, 503, 504. **Agent E (after C):** 505, 506. **Agent U:** 507 (Swift). **Agent D:** 508.
- **Lead:** 501, chunk f3, runs, contract, commits.

## Implementation strategy

- **MVP:** 502, 505. **Review checkpoint:** at 509. **Commits:** one per task.
