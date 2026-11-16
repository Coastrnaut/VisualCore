# Tasks: Molecular Explorer — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A15-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may present the document
picker or any system prompt. Precedent: `specs/108-sse-p06-release/tasks.md`.

## Phase 1: Setup

- [ ] T-A15-601 Baseline: cite the A15-P05 evidence on the unchanged sources (`.autonomy/checks/A15-P05.{me-ios27-4,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Story 1 — nothing leaves the device

- [ ] T-A15-602 [P] [US1] Write `docs/apps/molecular-explorer/privacy-and-credits.md` per research D1 (stored: `recent.json`, `settings.json`, `import.xyz`, `import-title.txt` in the experience's folder and the app's session state; the picked file read once and copied; nothing sent; deletion; credits for PubChem and the element data sources of `data-sources.md` with their licenses) (FR-A15-604)
- [ ] T-A15-603 [US1] Write `specs/115-me-p06-release/scan-sources-release.sh` refusing the uses of Clarifications Q3 in `Packages/ExperiencesCreative/MolecularExplorer` and run it (`--name me-no-network -- sh specs/115-me-p06-release/scan-sources-release.sh`) (FR-A15-601, 602; SC-A15-601)

## Phase 3: Story 2 — saved data and failures

- [ ] T-A15-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/MolecularExplorer/Experience/MoleculePresenter.swift` (the next `draw` throws once and clears the flag) with `ExperienceTests/MoleculeRecoveryDrawTests.swift` (import a fixture into a temporary storage, set the seam, draw so the session fails, `import.xyz`, `recent.json` and `settings.json` byte-identical, a new session over the same storage draws the import) (FR-A15-611)
- [ ] T-A15-605 [P] [US2] Commit `ExperienceTests/Fixtures/{recent,settings}-{valid,newer,damaged,oversized}.json` and `import-{valid,damaged,oversized}.xyz` ("valid loads; others refused with their reason and stay byte-identical"; for the import: valid opens, damaged is a parser refusal with its sentence, oversized is refused before reading; recent ids outside the library are already proved dropped by `RecentStoreTests` of A15-P04), the `Fixtures` resource of `MolecularExplorerExperienceTests` in `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredFileSampleTests.swift` (each sample answered by `RecentStore`, `SettingsStore` or `MoleculeImporter` as specified and byte-identical afterwards) (FR-A15-610; SC-A15-602)
- [ ] T-A15-606 [US2] Add `MoleculeCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()` (stored payloads of schemas 1–3 in envelopes with the digest their migration to 4 gives) in `Packages/ExperiencesCreative/MolecularExplorer/Experience/Adapter/MoleculeCore.swift`, pass them to the a15 registration in `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:`), with `ExperienceTests/MoleculeSchemaExampleTests.swift` (each restores in schema 4 with its digest) (FR-A15-612)

## Phase 4: Story 3 — truthful release documents

- [ ] T-A15-607 [P] [US3] Write `docs/apps/molecular-explorer/{store-listing.md (text + Claim | Proving test table; no measured or refused claim), release-checklist.md (Item | Area | Status | Evidence; statuses `verified`, `pending-campaign-ii` for ME-D1–ME-D6, `owner-action` for signing set-up, archive and upload with the steps of `docs/release/build-and-archive.md`; the artifact inventory of FR-A15-620; the accessibility facts proved and the audits pending), device-campaign.md (ME-D1–ME-D6 per research D5), release.json (per contracts/release.md)}` and a Molecular Explorer section in `docs/release/known-limitations.md` (device-only items; five library molecules; bonds inferred from covalent radii plus 0.4 Å; import limits 64 KB, 500 atoms) (FR-A15-620, 622, 623)
- [ ] T-A15-608 [US3] Write `specs/115-me-p06-release/scan-claims-release.sh` (the words of Clarifications Q2 over the store text and the controls and presenter Swift; every test named in the claim table exists) and run it (`--name me-claims -- sh specs/115-me-p06-release/scan-claims-release.sh`) (FR-A15-621; SC-A15-603)

## Phase 5: Story 4 — the interface end to end

- [ ] T-A15-609 [P] [US4] Write `Apps/VisualCore/Tests/UI/MolecularExplorer/{MESupport,MEExploreUITests,MELibraryUITests}.swift` per Clarifications Q4 and add the serial chunk `"w2": ["MEExploreUITests", "MELibraryUITests"]` to `scripts/release_check.py` (with `w2` in `SERIAL_CHUNKS`) (FR-A15-630)
- [ ] T-A15-610 [US4] Molecular Explorer suites on sim-27.2 (`--name me-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`) (FR-A15-632; SC-A15-605)
- [ ] T-A15-611 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml`, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-w2`) and the runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`) (SC-A15-604, 605)
- [ ] T-A15-612 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a15 copy-claims-a15`) (FR-A15-603, 631; SC-A15-603, 604)

## Phase 6: Records

- [ ] T-A15-613 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A15-614 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P06 (owner and device items stay open as BLOCKED_OWNER_ACTION and pending-campaign-ii); update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A15-601 → {602, 603, 604, 605, 606, 609} (independent files; only 605 touches Package.swift);
{602, 604, 605, 606} → 607 → 608; {604, 605, 606, 609} → 610 → 611 → 612 → 613 → 614.

## Parallel examples

Agent A: T-A15-602, 603, 607 (documents and scripts; 608 after 607). Agent B: T-A15-609 (interface tests). Agent C:
T-A15-604–606 test files and fixtures. Lead: seam, examples, registry, Package.swift, release_check chunk, runs, commits.

## Implementation strategy

MVP: privacy (602, 603) and data (604–606); then documents (607, 608) and the interface (609); evidence 610–613.
Review checkpoints after 606 (package tests) and at 611.
