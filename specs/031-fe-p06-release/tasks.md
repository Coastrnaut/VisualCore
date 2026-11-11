---

description: "Task list for feature 031 — Fractal Explorer Phase 06 final verification, privacy, packaging and release (ledger gate A03-P06)"
---

# Tasks: Fractal Explorer — Phase 06 Final verification, privacy, packaging and release

**Input**: `/specs/031-fe-p06-release/`: the spec (3 clarifications plus checklist amendments), the plan, research
R1–R4, the data model, the contract and the quickstart.

**Tests are required**: app unit/UI on iOS 27.2 and 26.5 under the guard; host tests; Release build checks; isolation.

**Conventions**: IDs `T-A03-6##`, one commit per task through `scripts/tick_task.py`; commands through
`run-check --stage A03-P06`. No device action; owner steps are `BLOCKED_OWNER_ACTION`.

## Phase 1: User Story 1 — privacy (P1) 🎯

- [ ] T-A03-601 [US1] Build Release (generic iOS, unsigned) and run `check_privacy_manifest.py --app` to list required-reason APIs; write `Apps/FractalExplorer/Resources/PrivacyInfo.xcprivacy` (tracking false, no domains, no collected data, exactly the scanned categories with their reasons per research R1); `project.yml` adds the Resources folder, `ITSAppUsesNonExemptEncryption` stays false. Add `Apps/FractalExplorer/Tests/Unit/PrivacyTests.swift`: the only usage description is NSPhotoLibraryAddUsageDescription with the documented text; a session (explore, bookmark, capture, tour, close) leaves 0 app keys in the app's defaults domain and no capture file, only the saved bookmark. Re-run the scan (PASS) and both runtimes (FR-A03-601, SC-A03-601).
- [ ] T-A03-602 [P] [US1] Run `check_app_isolation.py --app Apps/FractalExplorer --built-app <Release app> --allow-usage NSPhotoLibraryAddUsageDescription` (no networking) (FR-A03-606).

## Phase 2: User Story 2 — store assets and credits (P1)

- [ ] T-A03-603 [US2] Icon per clarification 1: `Apps/FractalExplorer/Tests/Unit/IconRenderTests.swift` (writes with `FE_WRITE_ICON=1`, else compares mean ≤ 1/255, opaque, not blank) and `Resources/Assets.xcassets/AppIcon.appiconset`; version 1.0.0 (1) in `project.yml`. Both runtimes (FR-A03-602).
- [ ] T-A03-604 [US2] Acknowledgements: `bundle_licenses.py` post-build phase in `project.yml`, home link `fe.home.acknowledgements` → `AcknowledgementsView(identifierPrefix: "fe.acknowledgements")` in `FractalExplorerApp.swift`; `Tests/UI/AcknowledgementsUITests.swift` (ANGLE license with its full text reachable); audit includes the screen. Both runtimes (FR-A03-602).

## Phase 3: User Story 3 — data migration and crash recovery (P1)

- [ ] T-A03-605 [US3] Golden fixture per clarification 3: `Apps/FractalExplorer/Tests/Fixtures/bookmark-v1.json` (written once with `FE_WRITE_FIXTURE=1` through `BookmarkLibrary`, Julia mode, non-default seed/cap/palette/precision); `MigrationTests` (fixture loads with every field; a schema-2 file is reported as newer and left) and `CrashRecoveryTests` (stale captures removed by the launch cleanup; a store leftover `.x.tmp-1` removed on load; an unrelated file left; intact bookmarks load). Both runtimes (FR-A03-603, SC-A03-603).

## Phase 4: User Story 4 — copy, documents and verification (P1)

- [ ] T-A03-606 [US4] Home description lists only implemented features; `Tests/Unit/CopyTests.swift` (home text and `docs/apps/fractal-explorer/store-listing.md` contain no forbidden claim per research R4 and name only implemented features). Write `docs/apps/fractal-explorer/{release.json,privacy-and-credits.md,store-listing.md,build-and-archive.md,release-checklist.md}` (owner-only items `BLOCKED_OWNER_ACTION`; D1–D3 rows pending: automation modes, container and defaults privacy, VoiceOver pass). Run `release_check.py --only app-release-fractal-explorer`, whose `check_app_release.py` also verifies the export-compliance key, the usage descriptions and the compiled icon, and whose symbol check confirms 0 automation symbols (analyze G1) (FR-A03-604, FR-A03-605).
- [ ] T-A03-607 Final verification: full FractalExplorer suites on 27.2 and 26.5 under the guard, host tests, `release_check.py` fast checks + `app-release-fractal-explorer`; contract gate A03-P06; lessons (FR-A03-606, SC-A03-604).

## Dependencies

- 601 first (Release build and resources); 602 after 601's build.
- 603, 604, 605 independent after 601 (project.yml edits are sequential).
- 606 after 601–605; 607 last.

## Implementation strategy

Privacy first (it shapes the bundle), then assets and credits, data, copy and documents, final verification.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- G1: export compliance is verified by `check_app_release.py` in T-A03-606.
- 0 critical issues.
