# Tasks: Living Wallpapers — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A19-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only; iOS 26 and the
reference regression wait for X-A19. Precedent: `specs/136-ac-p06-release/tasks.md`. Rollback: revert the commits (no
migration, no VisualCore change).

## Phase 1: Setup

- [ ] T-A19-601 Baseline: cite the A19-P05 evidence (`.autonomy/checks/A19-P05.{lw-ios27,app-ui,verify-27}.json`) on the tree recorded at A19-P05 (`7adeb1f9`), whose Packages, Apps and project.yml are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Story 1 — privacy and credits (P1) 🎯

- [ ] T-A19-602 [P] [US1] Write `docs/apps/living-wallpapers/privacy-and-credits.md`: the session snapshot (scene, preset, edited colours, template, orientation, time, format, motion) and `history.json` (at most 20 exports) in the experience's storage, replaced on each change and removed when the app is deleted; the temporary export folder `LivingWallpapers-Export` (at most one file, replaced by the next export); nothing sent over the network; the add-only usage string "Saves exported artwork to your photo library when you choose Save Image.", asked by the system only when the person chooses Save Image in the share sheet; the experience never reads the library; the license inventory matching `licenses.md` (FR-A19-601)
- [ ] T-A19-603 [US1] Write `specs/143-lw-p06-release/scan-sources-release.sh` refusing the APIs of Clarifications Q3 in `Packages/ExperiencesCreative/LivingWallpapers` (Swift files); run it (`--name lw-no-network -- sh specs/143-lw-p06-release/scan-sources-release.sh`) (FR-A19-602; SC-A19-601)

## Phase 3: Story 2 — recovery and stored files (P1)

- [ ] T-A19-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/LivingWallpapers/Experience/WallpaperPresenter.swift` (the next draw throws `WallpaperDrawError.injected` once and clears the flag) and `ExperienceTests/WallpaperRecoveryDrawTests.swift` (two exports recorded in a temporary storage's history; a failed draw fails the session with the injected message; `history.json` byte-identical after the failure and after close; a new session over the same storage lists both entries) (FR-A19-603; SC-A19-602)
- [ ] T-A19-605 [P] [US2] Commit `ExperienceTests/Fixtures/{snapshot-v1,snapshot-v2,snapshot-newer,snapshot-damaged,history-current,history-newer,history-damaged}.json`, declare the `Fixtures` resource of `LivingWallpapersExperienceTests` in `Packages/ExperiencesCreative/Package.swift` (lead), and add `ExperienceTests/StoredSampleTests.swift` (v1 and v2 restore, v1 migrated; newer (schema 3) and damaged refused; history current loads two, newer (schema 2) reports `newer-version`, damaged reports `damaged`; every sample byte-identical afterwards) (FR-A19-604)

## Phase 4: Story 3 — copy and checklist (P1)

- [ ] T-A19-606 [P] [US3] Write the release documents in `docs/apps/living-wallpapers/`: `store-listing.md` (claims each with a proving test or interface class; the person sets the wallpaper in Settings; stills only), `release-checklist.md` (rows verified, pending-campaign-ii LW-D1–LW-D8, owner-action: signing, archive, upload), `release.json` per data-model.md (`copyCheck.allow` `["share"]`), the A19 section of `docs/release/known-limitations.md`, and the README document table; run `--name experience-release -- python3 scripts/release_check.py --only experience-release-a19 copy-claims-a19` (FR-A19-605, 606)
- [ ] T-A19-607 [US3] Write `specs/143-lw-p06-release/scan-claims-release.sh` (the words of Clarifications Q2, whole words, case-insensitive, over the store text and the interface Swift of data-model.md; every named test exists) and run it (`--name lw-claims -- sh specs/143-lw-p06-release/scan-claims-release.sh`) (FR-A19-605; SC-A19-603)

## Phase 5: Story 4 — interface tests (P2)

- [ ] T-A19-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/LivingWallpapers/LWHistoryUITests.swift` per Clarifications Q5 (with `LWSupport`; export iPhone SE, `history-0` names it, Clear history, no `history-0` and no `clear-history`; under 60 s), and add it to the serial chunk `a3` in `scripts/release_check.py` (lead) (FR-A19-607)

## Phase 6: Records and evidence

- [ ] T-A19-609 Living Wallpapers tests on sim-27.2 (`--name lw-ios27`; each under 10 s) and the documented API (`--name documented-api`) (SC-A19-604)
- [ ] T-A19-610 App build, unit and interface chunk (`xcodegen generate --spec project.yml`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-a3`) and the runner (`--name verify-27`) (SC-A19-604)
- [ ] T-A19-611 Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a19 copy-claims-a19`)
- [ ] T-A19-612 Contract: G-RELEASE closed by "A19-P06"; rows whose gaps are all closed become available with evidence (`--name contract`); packages, catalog and script tests
- [ ] T-A19-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A19-601 → {602, 603} → {604, 605} → {606, 607} → 608 → 609 → 610 → 611 → 612 → 613. 602, 605, 606 and 608 touch
different files and may run in parallel; 606 needs 602's page for `requiredDocs`, and 607 needs 606's store text.

## Parallel examples

Agent D: T-A19-602 and 606 (documents). Agent K: T-A19-604 and 605 (code and samples). Agent U: T-A19-608 (interface
test). Lead: scans (603, 607), Package.swift, release_check.py, runs, contract, commits.

## Implementation strategy

MVP: privacy (602, 603) and recovery (604, 605). Copy and checklist (606, 607) and the interface chunk (608) close the
release. Review checkpoints after 605 and at 611.
