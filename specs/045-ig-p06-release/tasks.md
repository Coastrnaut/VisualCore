# Tasks: Infinite Geometry — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A05-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only (owner, 2026-11-14).

## Phase 1: Setup

- [X] T-A05-601 Baseline: ExperiencesCreative on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name baseline -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A05-P06.baseline.json (ExperiencesCreative sim-27.2, exit 0)

## Phase 2: User Story 1 — privacy (P1) 🎯

- [X] T-A05-602 [P] [US1] Write `docs/apps/infinite-geometry/privacy-and-credits.md` (stored data: `composition-<uuid>.json` in the experience's own folder; pictures leave only through the share sheet, held in memory, no metadata; nothing collected; no permission; credits: original code and shaders, no third-party art) (FR-A05-601, 604) — Verified 2026-11-14: 2026-11-14 privacy-and-credits.md written; .autonomy/checks/A05-P06.experience-release.json (5 documents)
- [X] T-A05-603 [US1] No-network scan (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name ig-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CoreMotion|AVFoundation|CoreLocation|AdSupport|AppTrackingTransparency' Packages/ExperiencesCreative/InfiniteGeometry"`) (FR-A05-602) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A05-P06.ig-no-network.json (0 matches, exit 0)

## Phase 3: User Story 2 — data and recovery (P1)

- [ ] T-A05-604 [P] [US2] Add `resources: [.copy("Fixtures")]` to the `InfiniteGeometryExperienceTests` target in `Packages/ExperiencesCreative/Package.swift` and commit five fixtures in `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/Fixtures/Library/` per data-model.md ("listed / newer / newer / unreadable / unreadable"); UUIDs start with 00000000-0000-4000-8000- (FR-A05-610)
- [ ] T-A05-605 [P] [US2] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryLibraryMigrationTests.swift`: fixtures copied into a temporary `ExperienceStorage`, library counts (1 entry, 2 newer, 2 unreadable), the format-1 entry opens and its document reopens with the saved digest through `composition.open`, newer/unreadable files byte-identical after load and after a save (SC-A05-602)
- [ ] T-A05-606 [US2] Add internal `failNextDraw` and `GeometryDrawError.injected` to `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift` and write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryRecoveryTests.swift`: a hosted session with two saved compositions, `failNextDraw = true`, one frame → session failure state; saved files byte-identical; a new session opens and draws (FR-A05-611, SC-A05-603)

## Phase 4: User Story 3 — copy and release documents (P2)

- [ ] T-A05-607 [P] [US3] Write `docs/apps/infinite-geometry/{store-listing.md (text + traceability table to tests), release-checklist.md (Item | Area | Status | Evidence; statuses verified/pending/blocked-owner/device), device-campaign.md (measurements named without values per FR-A05-622), release.json (schema 1, experience a05.infinite-geometry, requiredDocs, checklist, copyCheck text+swift)}` and add the device-only items to `docs/release/known-limitations.md` (FR-A05-620–622)
- [ ] T-A05-608 [US3] Release-document check (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name experience-release -- python3 scripts/check_experience_release.py --config docs/apps/infinite-geometry/release.json`) (SC-A05-604)
- [ ] T-A05-609 [US3] Copy-claim check (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name copy-claims -- python3 scripts/release_check.py --only copy-claims-a05`) (SC-A05-605)

## Phase 5: User Story 4 — interface and builds (P2)

- [ ] T-A05-610 [P] [US4] Write `Apps/VisualCore/Tests/UI/InfiniteGeometry/{IGSupport.swift, IGControlsUITests.swift, IGLibraryExportUITests.swift}` (candidate launch as PUSupport; journeys of spec story 4) and add chunk `"k2": ["IGControlsUITests", "IGLibraryExportUITests"]` to `UI_CHUNKS` in `scripts/release_check.py` (FR-A05-630)
- [ ] T-A05-611 [US4] Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) (FR-A05-632)
- [ ] T-A05-612 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-k2`) (SC-A05-606)
- [ ] T-A05-613 [US4] Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27`)
- [ ] T-A05-614 [US4] Release build checks (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) (FR-A05-603, 631; SC-A05-601)

## Phase 6: Polish & owner/device items

- [ ] T-A05-615 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P06 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A05-616 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Infinite Geometry's store text, per `docs/release/build-and-archive.md` owner steps
- [ ] T-A05-617 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/infinite-geometry/device-campaign.md` on D1–D3
- [ ] T-A05-618 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P06 (owner and device items stay open, as for A04-P06)

## Dependencies

T-A05-601 → (602 ∥ 604/605 ∥ 607 ∥ 610) → 603, 606, 608, 609 → 611 → 612 → 613 → 614 → 615 → 618.

## Parallel examples

Agent A: T-A05-602, 607. Agent B: T-A05-604–606. Agent C: T-A05-610. Lead: checks, runs, commits.

## Implementation strategy

Privacy and data first (US1, US2), then documents (US3) and the interface chunk (US4); evidence last.
