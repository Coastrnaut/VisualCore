# Tasks: Solar System Explorer — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A14-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; reference regression and iOS 26 at
X-A14. Precedent: `specs/101-lm-p06-release/tasks.md`.

## Phase 1: Setup

- [X] T-A14-601 Baseline: cite the A14-P05 evidence on the unchanged tree (`.autonomy/checks/A14-P05.{sse-ios27,app-unit-2,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A14-P05.sse-ios27.json, A14-P05.app-unit-2.json and A14-P05.verify-27.json (exit 0) on the tree recorded at A14-P05, unchanged since apart from spec documents (no rerun)

## Phase 2: Story 1 — privacy

- [X] T-A14-602 [P] [US1] Write `docs/apps/solar-system-explorer/privacy-and-credits.md` per research D1 (stored: `view.json` in the experience's folder and the app's session state; nothing sent; deletion; credits for NASA NSSDCA fact sheets, the IAU 2015 B3 constant, E. M. Standish / JPL elements, the USNO and NASA event dates, each with its licence) (FR-A14-604) — Verified 2026-11-15: docs/apps/solar-system-explorer/privacy-and-credits.md: stored view.json and session state, nothing sent, deletion paths, no permission, required-reason APIs and credits with licences; every cited test exists (12 of 12 found by grep) and the manifest reasons CA92.1, 35F9.1, C617.1 match PrivacyInfo.xcprivacy
- [X] T-A14-603 [US1] Write `specs/108-sse-p06-release/scan-sources-release.sh` refusing the uses of Clarifications Q3 in `Packages/ExperiencesCreative/SolarSystemExplorer` and run it (`--name sse-no-network -- sh specs/108-sse-p06-release/scan-sources-release.sh`) (FR-A14-601, 602; SC-A14-601) — Verified 2026-11-15: 2026-11-15: specs/108-sse-p06-release/scan-sources-release.sh refuses the uses of clarification Q3; .autonomy/checks/A14-P06.sse-no-network.json exit 0 (no scanned use in 68 Swift files); the a14 registration declares no permission

## Phase 3: Story 2 — data and recovery

- [X] T-A14-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/SolarSystemExplorer/Experience/SolarPresenter.swift` (the next `draw` throws once and clears the flag) with `ExperienceTests/SolarRecoveryDrawTests.swift` (save a view in a temporary storage, start a tour, set the seam, draw so the session fails, `view.json` byte-identical, a new session draws) (FR-A14-611) — Verified 2026-11-15: 2026-11-15: failNextDraw seam (SolarDrawError.injected once, clears itself) in SolarPresenter; SolarRecoveryDrawTests (saved view, tour running, forced failure fails the session, view.json byte-identical, a new session draws and restores) passes in .autonomy/checks/A14-P06.sse-ios27.json exit 0 on sim-27.2 (first run failed because the test view had no size and drew no frame; fixed in the test)
- [X] T-A14-605 [P] [US2] Commit `ExperienceTests/Fixtures/view-{valid,newer,damaged,oversized}.json` (valid: the exact bytes of a `SavedView.encoded()`; newer: schema 2; damaged: truncated JSON; oversized: over 4,096 bytes), the `Fixtures` resource in the `SolarSystemExplorerExperienceTests` target of `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/SavedViewSampleTests.swift` (each answered as specified through `ViewStore`, byte-identical afterwards; with no `view.json` the answer is `missing` — already covered by A14-P04's `ViewStoreTests`, re-run here) (FR-A14-610; SC-A14-602) — Verified 2026-11-15: 2026-11-15: Fixtures view-valid (exact SavedView.encoded bytes), view-newer, view-damaged, view-oversized (5,128 bytes) bundled with the experience tests; SavedViewSampleTests (valid loads, the others refused newer-version, damaged, oversized, all byte-identical, an empty storage answers missing) pass in .autonomy/checks/A14-P06.sse-ios27.json exit 0 on sim-27.2
- [X] T-A14-606 [US2] Add `SolarCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()` (stored payloads of schemas 1–3 in envelopes with the digest their migration to 4 gives) in `Experience/Adapter/SolarCore.swift`, pass them to the candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, with `ExperienceTests/SolarSchemaExampleTests.swift` (each restores through the migration chain to the stated digest) (FR-A14-612) — Verified 2026-11-15: SolarCore.schemaOneExample/Two/Three (stored payloads of schemas 1-3 with the digests their migration to 4 gives) passed to the candidate in ExperienceRegistry; SolarSchemaExampleTests (3 tests) pass in .autonomy/checks/A14-P06.sse-ios27-2.json exit 0 on sim-27.2 (109 core and 107 experience tests, 0 failures)

## Phase 4: Story 3 — release documents

- [ ] T-A14-607 [P] [US3] Write `docs/apps/solar-system-explorer/{store-listing.md (text + Claim | Proving test table; no measured or refused claim), release-checklist.md (Item | Area | Status | Evidence; statuses `verified`, `pending-campaign-ii` for SSE-D1–SSE-D6, `owner-action` for signing set-up, archive and upload with the steps of `docs/release/build-and-archive.md`; the accessibility facts proved and the audits pending), release.json (per contracts/release.md)}` and a Solar System Explorer section in `docs/release/known-limitations.md` (device-only items; the approximate model, epoch J2000.0, 1950–2050) (FR-A14-620, 622, 623)
- [X] T-A14-608 [US3] Write `specs/108-sse-p06-release/scan-claims-release.sh` (the words of Clarifications Q2 over the store text and the controls and presenter Swift; every test named in the claim table exists) and run it (`--name sse-claims -- sh specs/108-sse-p06-release/scan-claims-release.sh`) (FR-A14-621; SC-A14-603) — Verified 2026-11-15: 2026-11-15: specs/108-sse-p06-release/scan-claims-release.sh (the refused words of clarification Q2 over the store text and the controls and presenter Swift, 'not an ephemeris' allowed; every claim-table test exists); a presenter comment using 'precision' in the floating-point sense was reworded; .autonomy/checks/A14-P06.sse-claims.json exit 0 (86 proving tests found)

## Phase 5: Story 4 — interface and build

- [X] T-A14-609 [P] [US4] Write `Apps/VisualCore/Tests/UI/SolarSystemExplorer/{SSESupport,SSEViewUITests,SSETourUITests}.swift` per Clarifications Q4 and add the serial chunk `"v2": ["SSEViewUITests", "SSETourUITests"]` to `scripts/release_check.py` (FR-A14-630) — Verified 2026-11-15: SSESupport, SSEViewUITests (focus Earth, year step, play and pause; scale switch) and SSETourUITests with the serial chunk v2 in release_check.py; first run app-ui exit 1 (Body menu never settled: SolarControls stored closures, so the per-frame host rebuild recreated it), fixed by passing the presenter reference, guarded by SolarControlsIdentityTests (passed on sim-27.2); .autonomy/checks/A14-P06.app-ui-2.json exit 0 (build, unit and v2 in 127 s)
- [X] T-A14-610 [US4] Solar System Explorer suites on sim-27.2 (`--name sse-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`) (FR-A14-632; SC-A14-605) — Verified 2026-11-15: .autonomy/checks/A14-P06.sse-ios27-3.json exit 0 on sim-27.2: 109 core tests in 21 suites and 108 experience tests with 0 failures, SolarControlsIdentityTests and SolarSchemaExampleTests included
- [X] T-A14-611 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml`, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-v2`) and the runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`) (FR-A14-630; SC-A14-604, 605) — Verified 2026-11-15: .autonomy/checks/A14-P06.app-ui-2.json exit 0 (app build-for-testing, unit tests and interface chunk v2 on the iOS 27.2 phone) and .autonomy/checks/A14-P06.verify-27.json exit 0 (verify_experiences a14 on runtime 27)
- [X] T-A14-612 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a14 copy-claims-a14`) (FR-A14-603, 620, 621, 631) — Verified 2026-11-15: .autonomy/checks/A14-P06.release-checks.json exit 0: app-release-build, app-release-symbols, app-privacy-manifest, app-no-tracking, app-licenses, app-usage-descriptions, experience-release-a14 and copy-claims-a14 all pass

## Phase 6: Records

- [ ] T-A14-613 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A14-614 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P06 (owner and device items stay open as BLOCKED_OWNER_ACTION and pending-campaign-ii); update README.md (rule 16) and `docs/automatedtesting.md` if a tool, rule or lesson changed (rule 17)

## Dependencies

T-A14-601 → (602 ∥ 605 ∥ 607 ∥ 609) → 603 → 604 → 606 → 608 → 610 → 611 → 612 → 613 → 614.

## Parallel examples

Agent A: T-A14-602, 607 (documents). Agent B: T-A14-609 (interface tests). Lead: 603–606, 608, 610–614.

## Implementation strategy

Privacy first (602–603), then data and recovery (604–606), then documents and claims (607–608), then interface and
build (609–612). Review checkpoints after 606 and at 612.
