# Tasks: Visual Programming Lab — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A23-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P06 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/164-ss-p06-release/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-601 Baseline: cite the A23-P05 evidence (`.autonomy/checks/A23-P05.{vpl-ios27-2,app-unit-2,verify-27}.json`) — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P05.{vpl-ios27-2,app-unit-2,verify-27}.json exit 0; Packages/ExperiencesCreative, Apps and project.yml unchanged since 4318a204
  on the tree recorded at A23-P05, whose `Packages/ExperiencesCreative`, `Apps` and `project.yml` are unchanged since
  `4318a204` (owner ruling of 2026-11-14)

## Phase 2: Story 1 — nothing leaves the device (P1) 🎯

- [X] T-A23-602 [P] [US1] Write `docs/apps/visual-programming-lab/privacy-and-credits.md` (FR-A23-601), after — Verified 2026-11-19: 2026-11-19: docs/apps/visual-programming-lab/privacy-and-credits.md names state.json, graph-<n>.json and library.json, their place and removal, nothing is sent, no permission is asked, the licences (facts checked against LabCore and ExperienceStorage); validate_docs passes
  `docs/apps/shader-studio/privacy-and-credits.md`:
  - the stored data (the session snapshot; `graph-<n>.json`; `library.json`), its place (the experience's own
    storage) and its removal (Remove in the library, or deleting the app);
  - "nothing is sent" and "no permission is asked";
  - the licence inventory (link `licenses.md`).
- [X] T-A23-603 [US1] Write `specs/171-vpl-p06-release/scan-sources-release.sh`, after — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P06.scan-sources.json exit 0 (no scanned use in 62 Swift files of Packages/ExperiencesCreative/VisualProgrammingLab)
  `specs/164-ss-p06-release/scan-sources-release.sh`, with the APIs of clarification Q3 over
  `Packages/ExperiencesCreative/VisualProgrammingLab`; run it (`--name scan-sources`) (FR-A23-602, SC-A23-601).

## Phase 3: Story 2 — recover without losing the graphs (P1)

- [X] T-A23-604 [US2] Add the recovery seam and its test (FR-A23-603, SC-A23-602): — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P06.vpl-recovery-samples.json exit 0 (162 core and 83 experience tests on sim-27.2); LabRecoveryDrawTests: an injected draw failure fails the session with its message, every storage file byte-identical, a new session lists and opens both graphs
  - `Experience/LabPresenter.swift`: an internal, test-only `failNextDraw`; the next draw throws
    `LabDrawError.injected` once and clears it;
  - `ExperienceTests/LabRecoveryDrawTests.swift`: save two graphs, set the seam and draw; the session fails with the
    message; every storage file is byte-identical; a new session over the same storage lists and opens both.
- [X] T-A23-605 [P] [US2] Commit the stored samples and test them (FR-A23-604): — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P06.vpl-recovery-samples.json exit 0; ReleaseSampleTests 9 over eight committed samples generated through the real encoders plus an 81,921-byte graph refused too-large and kept; every file byte-identical
  - `ExperienceTests/Fixtures/` gains the eight files of data-model.md (beside `graph-sample.json`), generated once
    through the real encoders (`LabCore.snapshotPayload`, `GraphLibrary.encode`) and then committed;
  - `ExperienceTests/ReleaseSampleTests.swift`: each file opens or is refused as listed, an 81,921-byte graph file
    written into the temporary storage is listed as `too-large` and kept, and every file is byte-identical after
    reading.

## Phase 4: Story 3 — honest copy and a complete checklist (P1)

- [X] T-A23-606 [US3] Write the release documents (FR-A23-605, 606): — Verified 2026-11-19: 2026-11-19: store-listing.md, release-checklist.md (35 rows), release.json and the A23 section of docs/release/known-limitations.md; check_experience_release.py PASS (7 documents, 35 rows); copy-claims PASS (6 files)
  - `docs/apps/visual-programming-lab/store-listing.md`: says "no code to type"; every claim names a proving test; no
    shared denylist word; names no frame rate or timing (the 30-a-second cap is not measured on a device);
  - `docs/apps/visual-programming-lab/release-checklist.md`: the statuses of clarification Q1; device rows name
    VPL-D1 … VPL-D6; accessibility is `verified` (automated) with the audits `pending-campaign-ii`; signing, archive
    and upload are `owner-action`;
  - `docs/apps/visual-programming-lab/release.json`, after Shader Studio's (`copyCheck.swift`: LabControls,
    CanvasOverlay, LabLibraryView, LabPresenter, Adapter/LabCore; `allow: []`);
  - an A23 section in `docs/release/known-limitations.md` (seven node kinds; at most 32 nodes and 64 connections; at
    most six preview textures; no typed code; no sharing or export; device rows pending).
- [X] T-A23-607 [US3] Write `specs/171-vpl-p06-release/scan-claims-release.sh` with the words of clarification Q2, then — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A23-P06.scan-claims.json exit 0 (no refused word in the store text and five interface Swift files; no code to type present; 59 proving tests found)
  run it (`--name scan-claims`); it requires "no code to type" and that every named test exists (SC-A23-603).

## Phase 5: Story 4 — a first session in the app (P2)

- [ ] T-A23-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/VisualProgrammingLab/VPLReleaseUITests.swift` per
  clarification Q5, and add it to the chunk `e3` in `scripts/release_check.py` (lead) (FR-A23-607)

## Phase 6: Evidence

- [ ] T-A23-609 Visual Programming Lab tests on sim-27.2 (`--name vpl-ios27`; each under 10 s) and the documented API,
  isolation and core purity
- [ ] T-A23-610 App build, unit tests and the interface chunk: `xcodegen generate --spec project.yml`, then
  `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-e3`
- [ ] T-A23-611 Release build checks, as a review checkpoint: `--name release-checks -- python3 scripts/release_check.py
  --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
  experience-release-a23 copy-claims-a23`
- [ ] T-A23-612 Contract: close G-RELEASE with "A23-P06" (all 9 gaps closed; the iOS 26.x runner half is cited at
  X-A23) (`--name contract`), and the catalog, packages, script tests and runner (`--name catalog`, `realcatalog`,
  `experience-packages`, `script-tests`, `verify-27`)
- [ ] T-A23-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

601 → {602, 603, 604, 605, 606, 608}; 606 → 607; {602 … 608} → 609 → 610 → 611 → 612 → 613.
- **Shared files:** 604 touches the presenter.
- **Independent files:** 602, 603, 605 and 608 write their own files.

## Parallel examples

- **Agent R:** 602 and 606 (documents).
- **Agent K:** 603 and 607 (scans; 607 after 606).
- **Agent E:** 604 and 605.
- **Agent U:** 608.
- **Lead:** release_check.py, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** privacy and the source scan (602, 603).
- **Then:** recovery and samples, copy and checklist, the journey, and the evidence.
- **Review checkpoint:** at 611.
- **Commits:** one per task.
