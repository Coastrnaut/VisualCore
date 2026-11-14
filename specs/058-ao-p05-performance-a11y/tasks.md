# Tasks: Audio Odyssey — Phase 05 Long-session performance and accessibility verification

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A07-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A07.

## Phase 1: Setup

- [X] T-A07-501 Baseline: cite `.autonomy/checks/A07-P04.odyssey-ios27.json`, `.autonomy/checks/A07-P04.app-unit.json` and `.autonomy/checks/A07-P04.visualcore-host-ci.json` (tree unchanged since apart from documents) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: Verified 2026-11-14: cited .autonomy/checks/A07-P04.odyssey-ios27.json, A07-P04.app-unit.json and A07-P04.visualcore-host-ci.json (tree unchanged since apart from documents); no rerun (owner ruling 2026-11-14)

## Phase 2: Foundational

- [X] T-A07-502 [P] [US2] VisualCore: `Packages/VisualCore/Sources/VisualCoreScenes/StreamingBudget.swift` (`StreamingLevel`, `StreamingBudget` per contracts/api.md and data-model.md: "levels (1…8, each value non-increasing with the level index)", "drawDistance (> 0, ≤ ahead × pieceLength)", clamped `level(_:)`, `vertexTotal`, `fits`), tests `Packages/VisualCore/Tests/VisualCoreScenesTests/StreamingBudgetTests.swift`; add a 10^9 case to `Packages/VisualCore/Tests/VisualCoreMathTests/CameraRailTests.swift` (pose at 10^9 + x equals pose at the wrapped distance within 1e-6) (FR-A07-501, 510; SC-A07-501, 502) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P05.scenes-host.json exit 0 (StreamingBudgetTests 7: A07 levels at piece length 8, refusals incl. draw distance beyond the window, clamping, vertex total, fits; CameraRailTests 9 incl. pose at 10^9 equal to the wrapped pose within 1e-6); draw distances corrected to 64/48/32 (= ahead x 8) in spec, research and tasks because 110/80/50 exceeded the window
- [X] T-A07-503 [P] [US1] [US3] Core: `Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyAnnouncer,OdysseyQuality}.swift` ("interval 1.5 s", changed text only, latest pending; levels ahead 8/6/4, behind 2/2/1, draw distance 64/48/32, element share 1/0.6/0.35, `starCount = round(48 × elementShare)`); tests `CoreTests/{JourneyAnnouncerTests,LongDistanceTests}.swift` (announcer throttle and pending flush; pieces at index 1.25 × 10^8 join within 1e-6 for every world; OdysseyQuality budget fits `WorldPieces.vertexBudget`) (FR-A07-502, 510, 520) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P05.core-ios27.json exit 0 (90 Core tests on sim-27.2: JourneyAnnouncer throttle 1.5 s, latest pending, repeat suppressed; pieces at index 1.25e8 join within 1e-6 in every world; OdysseyQuality levels ahead 8/6/4, behind 2/2/1, draw 64/48/32, stars 48/29/17, fog start 25.6/19.2/12.8, windows within a 65,536-vertex budget)

## Phase 3: User Stories 1–4

- [X] T-A07-504 [US1] [US2] [US3] Experience: presenter applies the host's quality level (or `forceTierForTesting`) through `OdysseyQuality.budget` (window replacement per plan Lifecycle, fog end = draw distance, fog start = 0.4 × draw distance, star count per level), announces world, source, preset and pause changes once each through an injected `AnnouncementSink` only while VoiceOver runs (injectable `voiceOverRunning`), spoken description includes the response strength; factory passes the sink seam; tests `ExperienceTests/{OdysseyQualityTests,OdysseyLongSessionTests,OdysseyAnnouncementTests,OdysseyPersistenceTests}.swift` (levels shrink window/fog/stars and keep the digest; 3,600 frames offscreen (64 × 64 points, rendered back to back with no waiting between frames so the test stays under 10 s) at 7 units/s with live renderers ≤ 12, ≤ 2 built per frame, ledger snapshot after the run equal to after the first window; restored at distance 10^9 the first frame's camera matches the reference within 1e-3; one announcement per change with VoiceOver, none without, throttled; save preset + snapshot, close, reopen with the same storage restores both) (FR-A07-502, 510, 511, 520, 530) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P05.odyssey-ios27.json exit 0 (91 Core + 29 Swift Testing + 54 XCTest: quality levels 0/1/2 give 8/6/4 ahead, fog 64/48/32 starting at 0.4x, stars 48/29/17 via WorldPieces starCount, digest unchanged, window shrinks at once and grows <= 2 per frame; 3,600 frames back to back at speed 7 in 1.7 s with <= 12 live and <= 2 built per frame and the ledger snapshot equal to the first full window; restored at 1e9 the camera matches within 1e-3; one announcement per world/source/preset/pause change with VoiceOver, none without, throttled 1.5 s; preset and journey restored after close and reopen)
- [X] T-A07-505 [US2] Registration: `Catalog/registrations.json` a07 `quality_tiers` ["level-0", "level-1", "level-2"] (FR-A07-502) — Verified 2026-11-14: Verified 2026-11-14: Catalog/registrations.json a07 quality_tiers level-0/1/2; .autonomy/checks/A07-P05.app-unit.json exit 0

## Phase 4: Polish & evidence

- [X] T-A07-506 VisualCore host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name scenes-host -- swift test --package-path Packages/VisualCore --filter "StreamingBudgetTests|CameraRailTests"`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P05.scenes-host.json exit 0 (16 tests)
- [X] T-A07-507 Audio Odyssey tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name odyssey-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyCoreTests AudioOdysseyExperienceTests`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P05.odyssey-ios27.json exit 0
- [ ] T-A07-508 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A07-509 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27`)
- [ ] T-A07-510 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A07-511 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; `Packages/VisualCore/README.md` (StreamingBudget); contract G-JOURNEYBUDGET and G-JOURNEYA11Y closed by "A07-P05", `check_app_contract.py --app audio-odyssey --render`
- [ ] T-A07-512 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P05 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A07-513 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A07-P05

## Dependencies

T-A07-501 → (502 ∥ 503) → 504 → 505 → Polish.

## Parallel examples

Agent A: T-A07-502. Agent B: T-A07-503. Agent C: T-A07-504 after A and B. Lead: 505, docs, runs, commits.

## Implementation strategy

MVP: precision and the long-session bound (US1) with quality levels (US2); announcements (US3) and persistence (US4);
evidence last.
