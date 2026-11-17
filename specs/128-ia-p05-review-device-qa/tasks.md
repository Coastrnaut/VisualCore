# Tasks: Interactive Anatomy — Phase 05 Scientific review and device QA

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/review.md](contracts/review.md), [quickstart.md](quickstart.md). Gate A17-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A17-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. Precedent:
`specs/107-sse-p05-review/tasks.md`.

## Phase 1: Setup

- [X] T-A17-501 Baseline: cite the A17-P04 evidence (`.autonomy/checks/A17-P04.{ia-ios27,app-unit,verify-27}.json`) on the tree recorded at A17-P04, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A17-P04 evidence cited: .autonomy/checks/A17-P04.ia-ios27.json, A17-P04.app-unit.json and A17-P04.verify-27.json, all exit 0; Packages unchanged since the A17-P04 record commit 9d8c6bbe

## Phase 2: Core (story 1)

- [X] T-A17-502 [US1] Create `Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyReviewRecord,AnatomyReview}.swift` and `Core/Content/knee-right.review.json` (envelope kind `a17.review-record`, schema 1, contentVersion 2, 14 editorial entries: reviewer "Lead engineer (editorial review)", date "2026-11-16", the method of clarification Q2, the part's citation ids; no clinical entry), validation per data-model.md ("unknown part → missing-reference; empty reviewer, date or method → empty-text; bad date → damaged; duplicate part + kind → duplicate-id"; content version higher → newer-version, lower → damaged), `AnatomyReview.modelStatement` and `lines(partID:record:)`; extend `Core/AnatomyPanel.swift` with `modelStatement` and `reviewLines`; with `CoreTests/{ReviewRecordTests,ReviewDocumentTests}.swift` and `PanelTests` updated (every part has an editorial entry and the not-reviewed line; each refusal named; a clinical entry changes only its part's line; the generated table in `docs/apps/interactive-anatomy/review.md` matches, `UPDATE_DATA_SOURCES=1` rewrites it; the lead writes review.md's prose (method, the BLOCKED_OWNER_ACTION clinical review with its steps, the model statement) and the empty marked block first) (FR-A17-501–504, 506; SC-A17-501, 502, 504) — Verified 2026-11-16: 2026-11-16: AnatomyReviewRecord (a17.review-record schema 1, bound to content version 2, typed refusals) with knee-right.review.json (14 editorial entries, no clinical one), AnatomyReview (model statement, review lines), AnatomyPanel review lines; ReviewRecordTests, ReviewDocumentTests and PanelTests pass in .autonomy/checks/A17-P05.ia-ios27.json exit 0 (101 core, 75 experience, 4 manifest tests, iOS 27); the review table in docs/apps/interactive-anatomy/review.md generated with UPDATE_DATA_SOURCES=1 and matching; written by an agent, retested

## Phase 3: Experience (story 2)

- [X] T-A17-503 [US2] Update `Packages/ExperiencesCreative/InteractiveAnatomy/Experience/AnatomyControls.swift` (and the presenter if it builds the panel text) to show the model statement at the top of the panel, the review lines after the citations, and an "About this model" row (identifier `experience.a17.interactive-anatomy.about-model`); a failing bundled record leaves only the not-reviewed line and is counted; with `ExperienceTests/AnatomyListOnlyTests.swift` (all 14 parts selected through list actions only, no pointer event: panel lines, announcement "<name> selected." and state equal a tap selection's; the row model text, spoken label and enabled state for every part) (FR-A17-503–505; SC-A17-503) — Verified 2026-11-16: 2026-11-16: the panel shows the model statement first and the review lines after the citations, an About this model row (about-model), a failing record counted with only the not-reviewed line; AnatomyListOnlyTests (all 14 parts through list actions only, panel, announcement and state equal to a tap's) pass in .autonomy/checks/A17-P05.ia-ios27.json exit 0 (101 core, 75 experience, 4 manifest tests, iOS 27); .autonomy/checks/A17-P05.documented-api.json exit 0

## Phase 4: Story 3 and records

- [X] T-A17-504 [P] [US3] Write `docs/apps/interactive-anatomy/device-campaign.md` (rows IA-D1 … IA-D7: frame pacing at both levels, thermals over 10 minutes, memory, VoiceOver with the list alone, Dynamic Type, Reduce Motion, the accessibility audit with `VC_RUN_AUDITS=1`; each with device class, procedure, threshold and "pending device campaign") (FR-A17-507) — Verified 2026-11-16: 2026-11-16: docs/apps/interactive-anatomy/device-campaign.md lists IA-D1 to IA-D7 (frame pacing at both levels, thermals over 10 minutes, memory, VoiceOver with the list alone, Dynamic Type, Reduce Motion, the accessibility audit), each with device class, procedure, threshold and pending status; validate_docs.py PASS
- [X] T-A17-505 Contract `docs/apps/interactive-anatomy/visualcore-contract.json`: G-REVIEW closed by "A17-P05"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app interactive-anatomy --render`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A17-P05.contract.json exit 0; G-REVIEW closed by A17-P05; M06, M10 and M18 available (M27 waits on G-RELEASE, A17-P06)
- [ ] T-A17-506 Tests on sim-27.2 (`--name ia-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`) and the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/InteractiveAnatomy`)
- [ ] T-A17-507 App build and unit, runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a17.interactive-anatomy --runtime 27`), packages, catalog check and script tests
- [ ] T-A17-508 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A17-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A17-501 → 502 → 503 → {504 in parallel with 503} → 505 → 506 → 507 → 508.

## Parallel examples

Agent C: T-A17-502. Agent E, after C: T-A17-503. Lead: T-A17-504 (docs), contract, runs, commits.

## Implementation strategy

MVP: the record and the review lines (502), which carry the phase's MVP. The list-only fixture (503) and the device
plan (504) close the phase. Review checkpoint after 502 and at 506.
