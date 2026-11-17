# Tasks: Living Wallpapers — Phase 04 Save, share and permission paths

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/save.md](contracts/save.md), [quickstart.md](quickstart.md). Gate A19-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/134-ac-p04-night-power/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A19-401 Baseline: cite the A19-P03 evidence (`.autonomy/checks/A19-P03.{lw-ios27,app-unit,verify-27}.json`) on the tree recorded at A19-P03 (`eab4605a`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A19-P03 evidence cited: .autonomy/checks/A19-P03.lw-ios27.json, A19-P03.app-unit.json and A19-P03.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A19-P03 record commit eab4605a

## Phase 2: Story 3 foundation — the history model (P2, needed by Story 2)

- [X] T-A19-402 [P] [US3] Core: `Packages/ExperiencesCreative/LivingWallpapers/Core/ExportHistory.swift` per data-model.md ("schema 1, kind `a19.export-history`, ≤ 16,384 bytes; entries newest first, bound 20; Entry scene, template, orientation, format, width, height, madeAt finite"; `adding(_:)`, `cleared()`; `HistoryRefusal` damaged, newer-version, too-large with code and sentence); `CoreTests/ExportHistoryTests.swift` (bound and order, exact round trip, each refusal, cleared) (FR-A19-404; SC-A19-403) — Verified 2026-11-17: 2026-11-17: Core/ExportHistory.swift (schema 1, kind a19.export-history, 16,384 bytes, bound 20 newest first, adding and cleared, Entry with finite madeAt and positive size, HistoryRefusal damaged, newer-version, too-large); ExportHistoryTests (5) pass in .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2); written by an agent, retested

## Phase 3: Story 1 — share without broad permission (P1) 🎯

- [X] T-A19-403 [US1] Experience: `Experience/WallpaperExportFile.swift` (`Transferable`, `FileRepresentation` with the plan's content type; the file name "<Scene> <Device> <W>x<H>.<ext>"); the controls show a `ShareLink` only while the written file exists; `ExperienceTests/ShareFileTests.swift` (content type per format, name, no item without a file, the item's file is the written one) (FR-A19-401) — Verified 2026-11-17: 2026-11-17: Experience/WallpaperExportFile.swift (Transferable with FileRepresentation per format, file name '<Scene> <Device> <W>x<H>.<ext>', item only while the file exists); StillExport writes the documented name; the controls show ShareLink only while shareItem exists; ShareFileTests (4) pass in .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2); written by an agent, retested
- [X] T-A19-404 [US1] Registration `Catalog/registrations.json` a19 permissions ["photo-library-add"] and `python3 scripts/build_catalog.py` (lead); write `specs/141-lw-p04-save-share/scan-photos.sh` (refuses `import Photos`, `PHPhotoLibrary`, `PHAsset`, `UIImageWriteToSavedPhotosAlbum` in `Packages/ExperiencesCreative/LivingWallpapers`) and run it (`--name photos-scan`) (FR-A19-402) — Verified 2026-11-17: 2026-11-17: Catalog/registrations.json a19 permissions [photo-library-add], build_catalog.py (catalog and fixture copies); specs/141-lw-p04-save-share/scan-photos.sh; .autonomy/checks/A19-P04.photos-scan.json, A19-P04.catalog.json exit 0; .autonomy/checks/A19-P04.usage.json exit 0 (app-release-build and app-usage-descriptions pass with the add-only key declared)

## Phase 4: Story 2 — the export job (P1)

- [X] T-A19-405 [US2] Experience: `Experience/ExportJob.swift` per data-model.md (steps plan, render on the main actor, encode and verify in a detached task, write; progress 0.2, 0.4, 0.7, 0.85, 1.0; `cancel()` honoured at the next step boundary; a cancelled or failed job removes its file; `retry()` uses the offered plan after does-not-fit); the controls show progress, cancel and retry; `StillExport` becomes the job's step code or is replaced so exactly one shipping path remains (FR-A19-403) — Verified 2026-11-17: 2026-11-17: Experience/ExportJob.swift (steps plan, render on the main actor, encode and verify in Task.detached, write; progress 0.2, 0.4, 0.7, 0.85, 1.0; cancel at step boundaries removes the file; retry with the offered plan; announces once; records history after a written export); StillExport keeps the single step implementations; the controls start the job with progress, cancel, retry; EditorModel maps job states; exercised in .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2); written by an agent, retested
- [X] T-A19-406 [US2] Tests: `ExperienceTests/ExportJobTests.swift` on the real host (progress values on success; a cancel after each step leaves 0 files and the host's live counts unchanged and the live picture renders; a failure names its reason and `retry` succeeds with the offered plan; the job announces its outcome once) (SC-A19-402) — Verified 2026-11-17: 2026-11-17: ExportJobTests (4: every progress value on success; a cancel after each step leaves no file and unchanged live counts with the live picture rendering; a failure names its reason and retry succeeds with the offered plan; one announcement per outcome) pass on the real host in .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2)

## Phase 5: Story 3 — the stored history (P2)

- [X] T-A19-407 [US3] Experience: `Experience/HistoryStore.swift` (reads `history.json` through `ExperienceStorage` when the experience opens; writes after each written export with the injected `ClockSource`; a refused file gives an empty history and one problem); the controls list the newest entries and offer Clear; `LivingWallpapersExperience.make` passes the storage and `SystemClock`; `ExperienceTests/HistoryStoreTests.swift` (temporary storage, `FixedClock`: written after export, newest first, bound, clear, damaged and newer files reported, round trip across two sessions) (FR-A19-404; SC-A19-403) — Verified 2026-11-17: 2026-11-17: Experience/HistoryStore.swift (reads history.json once, records after each written export with the injected clock, clear removes the file, refused files reported with an empty history); WallpaperPresenter and LivingWallpapersExperience.make pass the storage and SystemClock; HistoryStoreTests (6, temporary storage, FixedClock) pass in .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2); written by an agent, retested

## Phase 6: Records and evidence

- [X] T-A19-408 Tests on sim-27.2 (`--name lw-ios27`), documented API, isolation, and the scans (`--name platform-claims`, `--name help-claims`, `--name photos-scan`) (FR-A19-405, 406; SC-A19-404) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P04.lw-ios27.json exit 0 (52 core and 61 experience tests on sim-27.2), .autonomy/checks/A19-P04.documented-api.json, A19-P04.isolation.json, A19-P04.platform-claims.json and A19-P04.help-claims.json exit 0 (the short-loop decision unchanged and its scan green), each read before this tick
- [X] T-A19-409 Contract: G-SAVE, G-EXPORTJOB and G-HISTORY closed by "A19-P04"; rows whose gaps are all closed become available with evidence (`--name contract`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P04.contract.json exit 0 (PASS: 26 rows, 136 citations, 14 gaps); G-SAVE, G-EXPORTJOB and G-HISTORY closed by A19-P04; M05, M10, M17 and M18 available; M16 stays open for G-RELEASE (A19-P06)
- [X] T-A19-410 Catalog, app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`), the release steps (`--name usage -- python3 scripts/release_check.py --only app-release-build app-usage-descriptions`), runner (`--name verify-27`), packages and script tests (SC-A19-401) — Verified 2026-11-17: 2026-11-17: xcodegen generate; .autonomy/checks/A19-P04.app-unit.json (app-build-for-testing-ios27, app-unit-ios27), A19-P04.usage.json (app-release-build, app-usage-descriptions; committed with T-A19-404), A19-P04.verify-27.json (nine standard scenarios on 27.2, 0 failures), A19-P04.experience-packages.json and A19-P04.script-tests.json, all exit 0, each read before this tick
- [X] T-A19-411 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17) — Verified 2026-11-17: 2026-11-17: /speckit-converge round 1 appended T-A19-412, implemented; round 2 appended nothing (6 FR, 4 SC, 3 stories checked); .autonomy/evidence/A19-P04.json sealed; VERIFIED-GATE A19-P04 (141 pass); README and docs/automatedtesting.md updated; build_catalog.py --check, validate_autocreator.py and validate_docs.py PASS

## Dependencies

401 → 402 → 403 → 404 → 405 → 406 → 407 → 408 → 409 → 410 → 411. 402 (core) runs beside 403 (experience); 403,
405 and 407 are one experience writer.

## Parallel examples

Agent K: T-A19-402. Agent E: T-A19-403, 405, 406, 407. Lead: registration and scan (404), runs, contract, commits.

## Implementation strategy

MVP: the share file and the permission (403, 404). The job (405, 406) and the history (402, 407) close the phase.
Review checkpoints after 404 and at 410.

## Phase 7: Convergence

- [X] T-A19-412 Record the as-built design in `specs/141-lw-p04-save-share/data-model.md`: the controls start only `ExportJob` (the shipping path); `StillExport` keeps the single implementation of each step (`formatStep`, `encodeStep`, `verifyStep`, `writeStep`) and its synchronous `run` plus `presenter.export` compose the same steps for the A19-P02 and A19-P03 tests; JPEG files use the extension `.jpg`; `/` and `:` in a file name become `-`; `WallpaperExportFile` declares one `FileRepresentation` per format with an exporting condition; the controls list the 5 newest history entries; a missing `history.json` is an empty history with no problem per clarification Q1–Q3 (unrequested) — Verified 2026-11-17: 2026-11-17: data-model.md 'As built' records the job as the shipping path with StillExport's single step implementations, the .jpg extension and name sanitising, the per-format FileRepresentation with exporting conditions (WallpaperExportFile.swift), the 5 newest history lines (HistoryStore.shown) and the missing-file rule, as tested in .autonomy/checks/A19-P04.lw-ios27.json exit 0
