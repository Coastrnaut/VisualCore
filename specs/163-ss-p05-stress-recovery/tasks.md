# Tasks: Shader Studio — Phase 05 Stress-test shader failures and device recovery

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/recovery.md](contracts/recovery.md), [quickstart.md](quickstart.md). Gate A22-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P05 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/162-ss-p04-limits-error-ux/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A22-501 Baseline: cite the A22-P04 evidence (`.autonomy/checks/A22-P04.{ss-ios27,app-unit,app-ui-4,verify-27}.json`) — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P04.{ss-ios27,app-unit,app-ui-4,verify-27}.json exit 0 at 2bcb4693; Packages, Apps, project.yml unchanged since
  on the tree recorded at A22-P04 (`2bcb4693`), whose Packages, Apps and project.yml are unchanged since (owner ruling
  of 2026-11-14)

## Phase 2: Story 1 — many runs, no build-up (P1) 🎯

- [X] T-A22-502 [P] [US1] Write `Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/StressCycleTests.swift` — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-stress-recovery.json exit 0 (ShaderStudioCoreTests and ShaderStudioExperienceTests on sim-27.2); StressCycleTests 3 tests: levels flat after 50 mixed cycles, 20 template changes, 10 stop-and-reset cycles
  (FR-A22-501, SC-A22-501), with the resource level being `ResourceRegistry.stats.liveCount` for every kind plus
  `totalBytes`, read after the first cycle and after the last:
  - 50 cycles of a new source that compiles (a unique constant per cycle), a source that fails to compile and a
    refused source (a `#version` line), each run and drawn once at 32 × 24;
  - 20 template changes across all four templates, with textures;
  - 10 stop-and-reset cycles through the watchdog seam;
  - the level after the last cycle equals the level after the first;
  - each test under 10 s.
- [X] T-A22-503 [US1] Fix any leak that T-A22-502 finds in `Experience/{PreviewPipeline,StudioPresenter,TexturedPreview}.swift`: — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-stress-recovery.json exit 0 (ShaderStudioCoreTests and ShaderStudioExperienceTests on sim-27.2); no leak found by T-A22-502, so no source change was needed
  - release replaced scenes and programs that are neither live nor the fallback;
  - drop queued requests at teardown;
  - if no leak is found, record that in the task's evidence.

## Phase 3: Story 2 — recovery after the graphics are taken away (P1)

- [X] T-A22-504 [P] [US2] Write `ExperienceTests/RecoveryTests.swift` (FR-A22-502, SC-A22-502): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-stress-recovery.json exit 0 (ShaderStudioCoreTests and ShaderStudioExperienceTests on sim-27.2); RecoveryTests 7 tests: 10 rebuilds in 5 states byte-identical with a flat level and leaked 0; pending request dropped; an accepted Run compiles once after a rebuild (decision recorded in the spec)
  - in each of the states running, failed, refused, stopped and textured, 10 `recreateContext` calls;
  - each gives a byte-identical still (`StudioTest.still`), an unchanged resource level and `leaked` 0.
  - a request waiting in the pipeline is dropped by a rebuild; a Run accepted before a rebuild compiles exactly once
    after it; the level is unchanged.
- [X] T-A22-505 [US2] Fix anything T-A22-504 finds in the presenter, pipeline and textured preview (rebuild of the live, — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-stress-recovery.json exit 0 (ShaderStudioCoreTests and ShaderStudioExperienceTests on sim-27.2); RecoveryTests found no rebuild defect, so no source change was needed
  fallback and stopped scenes and the texture targets); if nothing is found, record that.

## Phase 4: Story 3 — my project is still there tomorrow (P1)

- [X] T-A22-506 [US3] Bind the core's bounds to the live project (FR-A22-503): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-shape.json exit 0 (ShaderStudioCoreTests 76, ShaderStudioExperienceTests 85 on sim-27.2); restore no longer requires values past the shape to be 0 (values kept by position)
  - in `Experience/Adapter/StudioCore.swift`: `shape [uniforms 0…16, inputs 0…2]` (optional in the payload; when
    absent, the template's counts) and the action `document.shape [0…16, 0…2]`, both whole (`a22.not-whole`);
  - `uniform.set k` needs k < `shape[0]` and `texture.set i` needs i < `shape[1]`; `template.select` sets the
    template's shape;
  - values are kept by position, and the digest covers `shape`;
  - in `Experience/StudioPresenter.swift`: send `document.shape` whenever the document's counts change (an edit, an
    open, a template choice, a restore), never compiling.
- [X] T-A22-507 [US3] Write `ExperienceTests/ShapeTests.swift`: — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P05.ss-shape.json exit 0 (ShaderStudioCoreTests 76, ShaderStudioExperienceTests 85 on sim-27.2) (ShapeTests 6)
  - a project with more uniforms and inputs than its template opens with every value and texture choice, and each
    can be changed;
  - an A22-P04 snapshot without `shape` reads the template's counts;
  - a shape change keeps values by position;
  - out-of-range shapes are refused;
  - reopening the library from a new `ExperienceStorage` on the same root lists and opens the project;
  - update `StudioCoreTests` (controls, digest, restore) and `PresenterLibraryTests` (the A22-P04 limitation is gone).
- [ ] T-A22-508 [P] [US3] Write `Apps/VisualCore/Tests/UI/ShaderStudio/SSRecoveryUITests.swift` (FR-A22-504, 506):
  - launch with `-vcResetData`, save "Waves", terminate, and launch without `-vcResetData`;
  - `project-0` is "Waves" and opens with the saved source;
  - under 60 s;
  - add `SSRecoveryUITests` to the chunk `d3` in `scripts/release_check.py` (lead).

## Phase 5: Story 4 — a plan for the devices (P2)

- [X] T-A22-509 [P] [US4] Write `docs/apps/shader-studio/device-campaign.md` after `docs/apps/aurora/device-campaign.md` — Verified 2026-11-18: 2026-11-18: docs/apps/shader-studio/device-campaign.md with 18 pending rows (SS-D1 to SS-D6 on D1 to D3), linked from the README; validate_docs passes
  (FR-A22-505, SC-A22-504):
  - rows SS-D1 to SS-D6 for each of D1 iPhone 15 (iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5,
    18 rows in all;
  - each row has its steps, expected result, owner actions and state `pending`;
  - the rows are: a slow template stopped within 3 s and recovered; a compile error on the right line; a hardware
    keyboard (typing, ⌘R, ⌘'); a project surviving a relaunch; the compatibility profile; background and back with no
    leak;
  - link it from `docs/apps/shader-studio/README.md`.

## Phase 6: Interface and evidence

- [ ] T-A22-510 [P] Update `Experience/Adapter/StudioManifest.swift` and `ExperienceTests/StudioManifestTests.swift`:
  - add the fixture `fixture-shape` (`document.shape [3, 1]`, then `uniform.set [2, 0.5]`);
  - add `document.shape` refusals to the rejection scenario;
  - regenerate `scenario-manifest.json`.
- [ ] T-A22-511 Review checkpoint:
  - Shader Studio tests on sim-27.2 (`--name ss-ios27`);
  - the documented API, isolation and core purity.
- [ ] T-A22-512 Contract: close G-DEVICE with "A22-P05" (the plan exists; its rows stay pending); M28 stays
  "requires adaptation" with a note pointing to the plan, because its evidence is device evidence (`--name contract`)
- [ ] T-A22-513 The catalog, app and runner checks, with the packages and script tests:
  - the catalog (`--name catalog`);
  - `xcodegen generate --spec project.yml`;
  - the app unit tests (`--name app-unit`);
  - the app interface tests (`--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-d3`);
  - the runner (`--name verify-27`).
- [ ] T-A22-514 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → {502, 504, 508, 509} → 503 → 505 → 506 → 507 → 510 → 511 → 512 → 513 → 514.
- **Shared files:** 503, 505 and 506 touch the presenter and pipeline, so they run in sequence.
- **Independent files:** 502, 504, 508 and 509 are new files.

## Parallel examples

- **Agent S:** 502 and 504 (stress and recovery tests).
- **Agent E:** 503, 505, 506, 507 and 510, in sequence.
- **Agent U:** 508.
- **Agent D:** 509.
- **Lead:** `release_check.py`, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the leak fixture (502, 503).
- **Then:** recovery (504, 505), shape (506, 507), the relaunch test (508) and the plan (509).
- **Review checkpoint:** at 511.
- **Commits:** one per task.
