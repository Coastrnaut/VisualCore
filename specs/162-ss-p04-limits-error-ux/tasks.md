# Tasks: Shader Studio — Phase 04 Resource limits and error UX

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/limits.md](contracts/limits.md), [quickstart.md](quickstart.md). Gate A22-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P04 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/161-ss-p03-editor-inspector/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [ ] T-A22-401 Baseline: cite the A22-P03 evidence (`.autonomy/checks/A22-P03.{ss-ios27,app-unit,app-ui-2,verify-27}.json`)
  on the tree recorded at A22-P03 (`1f688366`), whose Packages, Apps and project.yml are unchanged since (owner ruling
  of 2026-11-14)

## Phase 2: Foundational — guidance and the watchdog (core)

- [ ] T-A22-402 [P] Create `Packages/ExperiencesCreative/ShaderStudio/Core/{Guidance,FrameWatchdog}.swift` per
  data-model.md, with `///` on every declaration:
  - `Guidance.forIssue(_:)` gives one distinct sentence per refusal code, with the line where known;
  - `Guidance.forDiagnostic(message:)` covers "undeclared identifier", "syntax error", and "cannot convert" / "wrong
    operand types" / "no matching overloaded function", with the fallback "Check this line for a typing mistake.";
  - `FrameWatchdog` has "limit 0.25 s", "window 8", `record`, `rearm` and `reset`, with states `watching` and
    `stopped` (FR-A22-401, 402, 403).
- [ ] T-A22-403 [P] Write the core tests (SC-A22-401, 402):
  - `CoreTests/GuidanceTests.swift`: every code, distinct sentences, the line named, the `#version` and
    undeclared-uniform sentences;
  - `CoreTests/GuidanceCompileTests.swift`: compile real broken shaders through `CompileSupport` (compile only) on
    ANGLE, and each of the three patterns matches the real message;
  - `CoreTests/FrameWatchdogTests.swift`: 8 slow intervals stop it; 7 slow then 1 normal do not; non-finite values
    are ignored; the interval after `rearm` is skipped; `reset` returns to watching.

## Phase 3: Story 1 — errors that say what to change (P1) 🎯

- [ ] T-A22-404 [US1] Show the guidance (FR-A22-401, 402):
  - in `Experience/StudioPresenter.swift` (mirror `guidance`, the refusal's sentence or the first diagnostic's);
  - in `Experience/StudioControls.swift` (a `guidance` text under the status, with a spoken label);
  - in `Experience/StudioEditor.swift` (each diagnostic entry's label adds its guidance).
- [ ] T-A22-405 [US1] Write `ExperienceTests/GuidanceDisplayTests.swift`:
  - a `#version` source shows its sentence and line;
  - a source using `u_speed` undeclared shows "Declare u_speed …";
  - a broken compile's entries carry their guidance;
  - the preview is unchanged and nothing compiles for a refusal.

## Phase 4: Story 2 — a slow shader never locks the studio (P1)

- [ ] T-A22-406 [US2] Add the watchdog to the experience (FR-A22-403, 404):
  - `Experience/Adapter/StudioCore.swift`: `resets` (optional in the payload, default 0), the action
    `preview.reset [1…1]`, and the digest over `resets`;
  - `Experience/PreviewPipeline.swift`: the fallback (the previous live scene not stopped) is kept built, torn down
    with the pipeline and rebuilt after a context loss; Reset swaps it back with no compile, or queues the
    template's starter when there is none;
  - `Experience/StudioPresenter.swift`: feed `frame.delta`; `rearm` at setup, resize, Run and Reset; while stopped,
    clear to (0.05, 0.05, 0.07) and draw no shader; the status is "Stopped: frames took longer than 0.25 s";
  - `Experience/StudioControls.swift`: `preview-reset`;
  - an internal test seam feeds intervals.
- [ ] T-A22-407 [US2] Write `ExperienceTests/WatchdogTests.swift` (SC-A22-402):
  - injected slow intervals stop the preview, and the read-back is the flat colour;
  - normal intervals never stop it;
  - Reset restores the fallback's picture with `compileCount` unchanged;
  - with no fallback, Reset queues the starter;
  - after `recreateContext` while stopped, it stays stopped;
  - an A22-P03 snapshot without `resets` restores with 0.

## Phase 5: Story 3 — keep projects between visits (P2)

- [ ] T-A22-408 [P] [US3] Create `Experience/ProjectLibrary.swift` per data-model.md (FR-A22-405, 406):
  - files `project-<n>.json` ("at most 131,072 bytes", kind `a22.saved-project`, version 1, body `{name, order,
    project, values[16], textures[2]}`) and the index `library.json` (kind `a22.project-library`);
  - caps: "24 projects" counting unreadable files, names "trimmed, 1…40 characters", the same name ignoring case;
  - messages: "The library holds 24 projects.", "A name has 1 to 40 characters." and "A project is already called
    <name>.";
  - unreadable files are listed with their code, never opened, renamed or deleted automatically; a newer index makes
    the library read-only; a failed write keeps the previous file.
- [ ] T-A22-409 [P] [US3] Write `ExperienceTests/LibraryTests.swift` (SC-A22-403):
  - save, open, rename and remove round trips;
  - every cap refuses with its message and leaves the storage unchanged;
  - damaged, oversized and newer files are listed and still on disk after the listing and the attempts to open them;
  - a full quota (a filler file) refuses and keeps the previous file;
  - the order is newest first.
- [ ] T-A22-410 [US3] Wire the library (FR-A22-405, 407):
  - `Experience/ShaderStudioExperience.swift` passes `storage`;
  - `Experience/StudioLibraryView.swift` (new) shows the list with `library`, `save`, `project-<k>`, `open`, `rename`
    and `remove`, with spoken labels, and opens in the controls;
  - opening sets the document, values and textures, then queues a Run; the inspector lists the opened uniforms;
  - add a presenter test of opening in `LibraryTests.swift`.

## Phase 6: Interface and evidence

- [ ] T-A22-411 [P] Update `Experience/Adapter/StudioManifest.swift` and `ExperienceTests/StudioManifestTests.swift`:
  - add the fixtures `fixture-version-line-guidance` and `fixture-reset`;
  - regenerate `scenario-manifest.json`;
  - update `StudioCoreTests` for `preview.reset`.
- [ ] T-A22-412 [P] Write `Apps/VisualCore/Tests/UI/ShaderStudio/SSLibraryUITests.swift`, using `SSSupport` (FR-A22-407):
  - a `#version` line shows its guidance;
  - save "Waves", change the source, open "Waves", and the source is back;
  - each test under 60 s;
  - add `SSLibraryUITests` to the chunk `d3` in `scripts/release_check.py` (lead).
- [ ] T-A22-413 Review checkpoint:
  - Shader Studio tests on sim-27.2 (`--name ss-ios27`);
  - the documented API, isolation and core purity.
- [ ] T-A22-414 Contract: close G-LIBRARY and G-WATCHDOG with "A22-P04"; rows whose gaps are all closed become
  available with evidence (`--name contract`)
- [ ] T-A22-415 The catalog, app and runner checks, with the packages and script tests:
  - the catalog (`--name catalog`);
  - `xcodegen generate --spec project.yml`;
  - the app unit tests (`--name app-unit`);
  - the app interface tests (`--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-d3`);
  - the runner (`--name verify-27`).
- [ ] T-A22-416 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → {402, 403, 408, 409} → 404 → 405 → 406 → 407 → 410 → {411, 412} → 413 → 414 → 415 → 416.
- **Shared files:** 404, 406 and 410 touch the presenter and controls, so they run in sequence.
- **Independent files:** 408 and 409 (library) are new and run beside the core work.

## Parallel examples

- **Agent X:** 402 and 403 (core).
- **Agent L:** 408 and 409 (library and its tests).
- **Agent E:** 404–407, 410 and 411, in sequence.
- **Agent U:** 412.
- **Lead:** `release_check.py`, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the guidance (402–405).
- **Then:** the watchdog (406, 407), the library (408–410), and the interface and evidence.
- **Review checkpoint:** at 413.
- **Commits:** one per task.
