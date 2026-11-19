# Tasks: Graphics Benchmark Lab — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A24-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P06 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/171-vpl-p06-release/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A24-601 Baseline: cite the A24-P05 evidence (`.autonomy/checks/A24-P05.{gbl-ios27-3,app-ui-3,verify-27}.json`) — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P05.{gbl-ios27-3,app-ui-3,verify-27}.json exit 0; Packages/ExperiencesCreative, Apps and project.yml unchanged since 975f9aa4
  on the tree recorded at A24-P05, whose `Packages/ExperiencesCreative`, `Apps` and `project.yml` are unchanged since
  the A24-P05 record `975f9aa4` (owner ruling of 2026-11-14)

## Phase 2: Story 1 — nothing leaves the device without the person's tap (P1) 🎯

- [X] T-A24-602 [P] [US1] Write `docs/apps/graphics-benchmark-lab/privacy-and-credits.md` and — Verified 2026-11-19: 2026-11-19 privacy-and-credits.md and licenses.md name state.json, result-<n>.json, results.json and the export files, their place and removal, nothing sent automatically, no permission, public device facts, the licences; validate_docs PASS
  `docs/apps/graphics-benchmark-lab/licenses.md` (FR-A24-601), after `docs/apps/visual-programming-lab/`:
  - the stored data (the session snapshot; `result-<n>.json`, at most 12; `results.json`; export files in the temporary
    folder `GraphicsBenchmarkLab-Export`), its place and its removal (Remove in the results list; exports when the
    session closes or the experience opens again; deleting the app);
  - "nothing is sent automatically": a result leaves the device only through the share sheet the person opens;
  - "no permission is asked"; the report's device facts (model identifier, OS version, bundle version, thermal state,
    Low Power Mode) come from public APIs only, with no vendor or advertising identifier and not the device's name;
  - the licence inventory (every workload picture made in code; no bundled asset).
- [X] T-A24-603 [US1] Write `specs/178-gbl-p06-release/scan-sources-release.sh`, after — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.scan-sources.json exit 0 (no scanned use in 55 Swift files; ShareLink only in Experience/ResultsView.swift)
  `specs/171-vpl-p06-release/scan-sources-release.sh`, with the APIs of clarification Q3 over
  `Packages/ExperiencesCreative/GraphicsBenchmarkLab`; `ShareLink` is refused everywhere except
  `Experience/ResultsView.swift`, where it must appear; run it (`--name scan-sources`) (FR-A24-602, SC-A24-601).

## Phase 3: Story 2 — recover without losing the results (P1)

- [X] T-A24-604 [US2] Add the recovery seam and its test (FR-A24-603, SC-A24-602): — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.gbl-recovery-samples.json exit 0 (75 experience, 95 core tests); BenchRecoveryDrawTests: an injected draw failure fails the session, every storage file byte-identical, a new session lists and opens both results
  - `Experience/BenchPresenter.swift`: an internal, test-only `failNextDraw`; the next draw throws
    `BenchDrawError.injected` once and clears it;
  - `ExperienceTests/BenchRecoveryDrawTests.swift`: save two results, set the seam and draw; the session fails with
    the message; every storage file is byte-identical; a new session over the same storage lists and opens both.
- [X] T-A24-605 [P] [US2] Commit the stored samples and test them (FR-A24-604): — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.gbl-recovery-samples.json exit 0; ReleaseSampleTests 10 over nine committed samples plus a 2,162,689-byte result refused too-large and kept; every file byte-identical
  - `ExperienceTests/Fixtures/` holds the nine files of data-model.md, generated once through the real encoders
    (`BenchCore` snapshot, `ResultLibrary` save) and then committed; `Packages/ExperiencesCreative/Package.swift`
    copies the folder as a resource of `GraphicsBenchmarkLabExperienceTests` (lead);
  - `ExperienceTests/ReleaseSampleTests.swift`: each file opens or is refused as listed, a 2,162,689-byte result file
    written into the temporary storage is listed as `too-large` and kept, and every file is byte-identical after
    reading.

## Phase 4: Story 3 — honest copy and a complete checklist (P1)

- [X] T-A24-606 [US3] Write the release documents (FR-A24-605, 606): — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.experience-release.json exit 0 (7 documents, 35 rows); copy-claims PASS (15 files, allow share); known-limitations A24 section
  - `docs/apps/graphics-benchmark-lab/store-listing.md`: says "does not rank devices"; every claim names a proving
    test; no shared denylist word except "share"; names no frame rate, timing or benchmark number;
  - `docs/apps/graphics-benchmark-lab/release-checklist.md`: the statuses of clarification Q1; device rows name
    GBL-D1 … GBL-D6; accessibility is `verified` (automated) with the audits `pending-campaign-ii`; signing, archive
    and upload are `owner-action`;
  - `docs/apps/graphics-benchmark-lab/release.json`, after Visual Programming Lab's (`copyCheck.swift`: every Swift
    file of `Experience/` and `Experience/Adapter/`, the explanation included, unlike the experience's own claims
    scan of T-A24-607, research R2; `allow: ["share"]`);
  - an A24 section in `docs/release/known-limitations.md` (three cases; a run of at most its plan; at most 12 saved
    results; GPU time only where the timer exists; simulator numbers are not device evidence; a hot device ends a
    run; no ranking or comparison; device rows pending).
- [X] T-A24-607 [US3] Write `specs/178-gbl-p06-release/scan-claims-release.sh` with the words of clarification Q2, then — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.scan-claims.json exit 0 (no refused word, does not rank devices present, 64 proving tests found)
  run it (`--name scan-claims`); it requires "does not rank devices" and that every named test exists (SC-A24-603).

## Phase 5: Story 4 — a first session in the app (P2)

- [X] T-A24-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab/GBLReleaseUITests.swift` per — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A24-P06.app-ui.json exit 0 (chunk f3 3/3: GBLReleaseUITests and the two GBLRunUITests on the iOS 27.2 phone)
  clarification Q5, and add it to the chunk `f3` in `scripts/release_check.py` (lead) (FR-A24-607)

## Phase 6: Evidence

- [ ] T-A24-609 Graphics Benchmark Lab tests on sim-27.2 (`--name gbl-ios27`; each under 10 s) and the documented API,
  isolation and core purity
- [ ] T-A24-610 App build, unit tests and the interface chunk: `xcodegen generate --spec project.yml`, then
  `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-f3`
- [ ] T-A24-611 Release build checks, as a review checkpoint: `--name release-checks -- python3 scripts/release_check.py
  --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
  experience-release-a24 copy-claims-a24`
- [ ] T-A24-612 Contract: close G-RELEASE with "A24-P06" (all 12 gaps closed; the iOS 26.x runner half is cited at
  X-A24) (`--name contract`), and the catalog, packages, script tests and runner (`--name catalog`, `realcatalog`,
  `experience-packages`, `script-tests`, `verify-27`)
- [ ] T-A24-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

601 → {602, 603, 604, 605, 606, 608}; 606 → 607; {602 … 608} → 609 → 610 → 611 → 612 → 613.
- **Shared files:** 604 touches the presenter; 605 and 608 need lead edits of `Package.swift` and `release_check.py`.
- **Independent files:** 602, 603, 605 and 608 write their own files.

## Parallel examples

- **Agent R:** 602 and 606 (documents).
- **Agent K:** 603 and 607 (scans; 607 after 606).
- **Agent E:** 604 and 605.
- **Agent U:** 608.
- **Lead:** Package.swift, release_check.py, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** privacy and the source scan (602, 603).
- **Then:** recovery and samples, copy and checklist, the journey, and the evidence.
- **Review checkpoint:** at 611.
- **Commits:** one per task.
