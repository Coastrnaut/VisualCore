# Tasks: Shader Studio — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A22-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P06 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/157-au-p06-release/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A22-601 Baseline: cite the A22-P05 evidence (`.autonomy/checks/A22-P05.{ss-ios27,app-unit,app-ui,verify-27}.json`) — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.{ss-ios27,app-unit,app-ui,verify-27}.json exit 0 at 22b2b89f; Packages, Apps, project.yml unchanged since
  on the tree recorded at A22-P05 (`22b2b89f`), whose Packages, Apps and project.yml are unchanged since (owner ruling
  of 2026-11-14)

## Phase 2: Story 1 — nothing leaves the device (P1) 🎯

- [X] T-A22-602 [P] [US1] Write `docs/apps/shader-studio/privacy-and-credits.md` (FR-A22-601), after — Verified 2026-11-18: 2026-11-18: docs/apps/shader-studio/privacy-and-credits.md names the snapshot, project-<n>.json and library.json, their place and removal, nothing is sent, no permission is asked, GPU code is not a sandbox, the licences; validate_docs passes
  `docs/apps/aurora/privacy-and-credits.md`:
  - the stored data (the snapshot; `project-<n>.json`; `library.json`), its place (the experience's own storage) and
    its removal (Remove in the library, or deleting the app);
  - "nothing is sent", "no permission is asked" and "GPU code is not a sandbox";
  - the licence inventory (link `licenses.md`).
- [X] T-A22-603 [US1] Write `specs/164-ss-p06-release/scan-sources-release.sh`, after — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P06.scan-sources.json exit 0 (no scanned use in 52 Swift files of Packages/ExperiencesCreative/ShaderStudio)
  `specs/157-au-p06-release/scan-sources-release.sh`, with the APIs of clarification Q3 (plus `UIPasteboard` and
  `ShareLink`) over `Packages/ExperiencesCreative/ShaderStudio`; run it (`--name scan-sources`) (FR-A22-602, SC-A22-601).

## Phase 3: Story 2 — recover without losing the projects (P1)

- [X] T-A22-604 [US2] Add the recovery seam and its test (FR-A22-603, SC-A22-602): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P06.ss-recovery-samples.json exit 0 (ShaderStudioCoreTests 76, ShaderStudioExperienceTests 95 on sim-27.2); StudioRecoveryDrawTests: an injected draw failure fails the session with its message, every storage file byte-identical, a new session lists and opens both projects
  - `Experience/StudioPresenter.swift`: an internal, test-only `failNextDraw`; the next draw throws
    `StudioDrawError.injected` once and clears it;
  - `ExperienceTests/StudioRecoveryDrawTests.swift`: save two projects, set the seam and draw; the session fails with
    the message; every storage file is byte-identical; a new session over the same storage lists and opens both.
- [X] T-A22-605 [P] [US2] Commit the stored samples and test them (FR-A22-604): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P06.ss-recovery-samples.json exit 0 (ShaderStudioCoreTests 76, ShaderStudioExperienceTests 95 on sim-27.2); StoredSampleTests 9 over ten committed samples generated through the real encoders
  - `ExperienceTests/Fixtures/` holds the ten files of data-model.md, generated once through the real encoders
    (`StudioCore.snapshotPayload`, `ProjectLibrary.encode`) and then committed;
  - add the resources to `Packages/ExperiencesCreative/Package.swift` if the test target needs them;
  - `ExperienceTests/StoredSampleTests.swift`: each file opens or is refused as listed, and every file is
    byte-identical after reading.

## Phase 4: Story 3 — honest copy and a complete checklist (P1)

- [X] T-A22-606 [US3] Write the release documents (FR-A22-605, 606): — Verified 2026-11-18: 2026-11-18: store-listing.md, release-checklist.md (36 rows), release.json and the A22 section of docs/release/known-limitations.md; check_experience_release.py PASS (7 documents, 36 rows) and check_copy_claims.py PASS (7 files)
  - `docs/apps/shader-studio/store-listing.md`: says "not a sandbox"; every claim names a proving test; no shared
    denylist word;
  - `docs/apps/shader-studio/release-checklist.md`: the statuses of clarification Q1; device rows name SS-D1 …
    SS-D6; accessibility is `verified` (automated) with the audits `pending-campaign-ii`; signing, archive and upload
    are `owner-action`;
  - `docs/apps/shader-studio/release.json`, after Aurora's (`copyCheck.swift`: StudioControls, StudioEditor,
    StudioInspector, StudioLibraryView, StudioPresenter, Adapter/StudioCore; `allow: []`);
  - an A22 section in `docs/release/known-limitations.md` (no sandbox; GLSL ES 3.00 fragment shaders only; no sharing
    or export; device rows pending).
- [ ] T-A22-607 [US3] Write `specs/164-ss-p06-release/scan-claims-release.sh` with the words of clarification Q2, then
  run it (`--name scan-claims`); it requires "not a sandbox" and that every named test exists (SC-A22-603).

## Phase 5: Story 4 — a first session in the app (P2)

- [X] T-A22-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/ShaderStudio/SSReleaseUITests.swift` per clarification Q5, and — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P06.app-ui.json exit 0 (build for testing, unit, chunk d3: SSReleaseUITests 28.8 s and the five earlier tests pass on the iOS 27.2 phone)
  add it to the chunk `d3` in `scripts/release_check.py` (lead) (FR-A22-607)

## Phase 6: Evidence

- [ ] T-A22-609 Shader Studio tests on sim-27.2 (`--name ss-ios27`; each under 10 s) and the documented API, isolation
  and core purity
- [ ] T-A22-610 App build, unit tests and the interface chunk: `xcodegen generate --spec project.yml`, then
  `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d3`
- [ ] T-A22-611 Release build checks, as a review checkpoint: `--name release-checks -- python3 scripts/release_check.py
  --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
  experience-release-a22 copy-claims-a22`
- [ ] T-A22-612 Contract: close G-RELEASE with "A22-P06" (all 13 gaps closed, M29 available; the iOS 26.x runner half
  is cited at X-A22) (`--name contract`), and the catalog, packages, script tests and runner (`--name catalog`,
  `realcatalog`, `experience-packages`, `script-tests`, `verify-27`)
- [ ] T-A22-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

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
