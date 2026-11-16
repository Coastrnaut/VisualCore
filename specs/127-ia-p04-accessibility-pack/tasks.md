# Tasks: Interactive Anatomy — Phase 04 Accessibility and offline content

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/accessibility-pack.md](contracts/accessibility-pack.md), [quickstart.md](quickstart.md). Gate A17-P04
(legacy). Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A17-P04 --timeout 600 --name <check> --
<command>`. Commit after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may
raise a system prompt. Precedent: `specs/126-ia-p03-layers-search/tasks.md`.

## Phase 1: Setup

- [X] T-A17-401 Baseline: cite the A17-P03 evidence (`.autonomy/checks/A17-P03.{ia-ios27-3,app-unit,verify-27}.json`) on the tree recorded at A17-P03, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A17-P03 evidence cited: .autonomy/checks/A17-P03.ia-ios27-3.json, A17-P03.app-unit.json and A17-P03.verify-27.json, all exit 0; Packages unchanged since the A17-P03 record commit eb7dbfdf

## Phase 2: Foundational — the VisualCore layout (story 2)

- [X] T-A17-402 [US2] Create `Packages/VisualCore/Sources/VisualCoreMath/AnchoredLabelLayout.swift` per contracts/accessibility-pack.md ("ordered by priority, then id"; box placed 6 points up and right of the projected anchor; "inside the canvas; no positive-area overlap; ≤ budget"; anchors behind the camera or outside clip depth culled) with `Packages/VisualCore/Tests/VisualCoreMathTests/AnchoredLabelLayoutTests.swift` (no overlaps over random candidates; priority 0 placed whenever on the canvas; behind the camera and outside the canvas none; budget; deterministic; touching boxes allowed), the VisualCoreMath row in `Packages/VisualCore/README.md` and the API baseline (`check_public_api.py --update` then `check_public_api.py`) (FR-A17-402, 403; SC-A17-402) — Verified 2026-11-16: 2026-11-16: VisualCoreMath AnchoredLabelLayout (candidates by priority then id, projection with clip-space culling, box 6 points up-right inside the canvas, positive-area overlaps skipped, budget) with AnchoredLabelLayoutTests; written by an agent, retested in .autonomy/checks/A17-P04.math-host.json exit 0 (161 VisualCoreMath tests); README row and paragraph; API baseline updated, .autonomy/checks/A17-P04.public-api.json and A17-P04.documented-api-math.json exit 0

## Phase 3: Core (stories 2–4)

- [ ] T-A17-403 [P] [US3] `Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyLayerSign,AnatomyLabels}.swift` (signs "●", "◆", "▲" with words and material colours, `stateSignProblems == []`; candidates of the solid parts, selection priority 0, others 1 + index, box "7 points per character plus 8, by 18") with `CoreTests/{LayerSignTests,LabelCandidateTests}.swift`; core depends on `VisualCoreSimulation` (FR-A17-402, 404; SC-A17-403)
- [ ] T-A17-404 [P] [US4] `Core/{AnatomyContentPack,AnatomyProvenance}.swift`, the resource `Core/Content/knee-right.pack.json` replacing `knee-right.json` (kind `a17.content-pack`, schema 2; "1 → 2 wraps the bare region; ≤ 262,144 bytes; damaged, too large, newer refused"; digest SHA-256 of the sorted-key region), `AnatomyContent.bundledRightKnee()` reading the pack, with `CoreTests/{ContentPackTests,ProvenanceTests,NoNetworkTests}.swift` (stable digest; bare region migrates; three refusals; provenance complete and each missing field caught; no `URLSession`, `URLRequest`, `NWConnection`, `import Network` or `http` literal in the Interactive Anatomy sources) and `docs/apps/interactive-anatomy/content-sources.md` pointing to the pack (FR-A17-407, 408; SC-A17-404)

## Phase 4: The experience (stories 1–3)

- [ ] T-A17-405 [US1] Create `Packages/ExperiencesCreative/InteractiveAnatomy/Experience/{AnatomyGestures,AnatomyOverlay}.swift` and update `AnatomyPresenter.swift`, `AnatomyControls.swift`, `Adapter/AnatomyCore.swift`: drag and pinch through `GestureArbiter` ("drag 0.3°/point (turn every 50 points, tilt every 33.3), pinch at 1/0.85 and 0.85, ≤ 64 steps per event"; "pinch 3, drag 2, tap 1"); refused steps show "The camera is at its limit."; labels laid out with `AnchoredLabelLayout` after each frame and drawn by `makeCanvasOverlay` (hit testing off); list rows "<sign> <English name>" spoken "<English name>, <layer words>"; announcements "<English name> selected." / "Selection cleared." through `AnnouncementPlanner(minimumInterval: 0.5)` and an injectable sink that speaks only while VoiceOver runs; camera changes never animated (FR-A17-401, 402, 404–406)
- [ ] T-A17-406 [US1] Write `Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/{AnatomyGestureTests,AnatomyLabelTests,AnatomyAnnouncementTests}.swift`: drag and pinch tables give the stated steps; a short tap still picks; pinch with drag steps once; limits refused with the sentence; labels never overlap and the selection is labelled over a grid of cameras at aspects 0.5 and 2, at most 16; no label for ghosted or hidden parts; five quick selections give at most the planned announcements and the last one; with Reduce Motion on, selecting a part frames it within the same frame (nothing animated); manifest unchanged or regenerated (SC-A17-401–403, 405)

## Phase 5: Records and evidence

- [ ] T-A17-407 Contract `docs/apps/interactive-anatomy/visualcore-contract.json`: G-LABELS (promoted to VisualCoreMath as `AnchoredLabelLayout`), G-A11Y and G-PACK closed by "A17-P04"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app interactive-anatomy --render`)
- [ ] T-A17-408 Tests: VisualCoreMath host (`--name math-host -- swift test --package-path Packages/VisualCore --filter VisualCoreMathTests`), Interactive Anatomy on sim-27.2 (`--name ia-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`), public API and documented API for both source folders
- [ ] T-A17-409 App build and unit, runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a17.interactive-anatomy --runtime 27`), packages, catalog check, compliance (`--name compliance -- python3 scripts/check_compliance.py`) and script tests
- [ ] T-A17-410 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A17-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A17-401 → 402 → {403, 404} (different files) → 405 → 406 → 407 → 408 → 409 → 410.

## Parallel examples

Agent V: T-A17-402. Agent C: T-A17-403 and 404. Agent E, after V and C: T-A17-405. Agent T, with E: T-A17-406. Lead:
Package.swift, API baseline, README, contract, runs, commits.

## Implementation strategy

MVP: the gestures (405) with the pack's provenance fixture (404). Labels (402, 403) and accessibility (403, 405) close
the phase. Review checkpoints after 404 (core) and at 408.
