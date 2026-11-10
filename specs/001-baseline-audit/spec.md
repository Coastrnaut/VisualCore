# Feature Specification: Phase 0 — Repository Integration and Baseline Audit

**Feature Branch**: `001-baseline-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F00 (ID namespace FR-F0##, SC-F0##, T-F0##; ADR-0004)

**Input**: User description: archived `sources/README.md` §10.2 Phase 0 prompt, quoted verbatim in
the `/speckit-specify` invocation, plus the canonical override: host/simulator smoke only, no
physical-device install/launch/test before IMPLEMENTATION-LOCK, read-only device inventory, and
reuse of existing F00 outputs (`docs/architecture/F00-reference-audit.md`,
`docs/architecture/projectm-reference-audit.json`, `docs/verification/environment-F00.json`,
`docs/verification/devices-observed.json`, `scripts/audit_projectm_reference.py`,
`scripts/inventory_devices.py`, `scripts/verify_environment.py`).

## Clarifications

### Session 2026-11-10

Answered by the agent under the owner's delegated implementation intent (recommended option chosen).

- Q: Who may change the reference pin (the superproject gitlink or nested projectM/ANGLE pins) during this feature? → A: Nobody. Pins are read-only in Phase 0; a future change needs an owner-approved ADR plus an upstream-ready patch log, never an agent decision.
- Q: Where may baseline build output be written? → A: Only into the reference's own gitignored outputs, produced by its own scripts (`Build/ProjectM.xcframework`, `Build/ANGLEFrameworks`, the gitignored generated `.xcodeproj`). Xcode DerivedData and result bundles go to VisualCore's gitignored `Build/` and `.autonomy/` directories.
- Q: Which evidence declares the baseline verified? → A: All of the following, each run through `desktop_runbook.py run-check` with a hashed log: (1) the engine framework built with `scripts/build_projectm_xcframework.py`; (2) `xcodegen generate` for `project.yml` and `RendererLab.yml`; (3) simulator builds of `projectM-iOS`, `CaptureLab` and `RendererLab` plus a generic-iOS unsigned build of `projectM-iOS`; (4) the reference's existing `ANGLERendering` package tests on an iOS simulator; (5) a clean-tree check of the reference before and after.
- Q: Which simulator runtimes does the baseline smoke cover? → A: iOS 27.2 for the full smoke and iOS 26.5 for the `ANGLERendering` tests, because D3's iOS 26 path is the compatibility floor.
- Q: Is the existing ANGLE framework reused or rebuilt? → A: Reused when the audit confirms it was built from the pinned ANGLE commit (F00 confirmed this). A rebuild uses only the reference's `scripts/build_angle_xcframework.py`, and only if the audit fails.

## User Scenarios & Testing *(mandatory)*

The users are the VisualCore framework engineers and the 25 app teams. Before anyone changes
production code, they need a verified, cited understanding of the existing ProjectM-iOS renderer.

### User Story 1 - Verified reference pin and inventory (Priority: P1)

An engineer opens the audit and sees exactly which ProjectM-iOS, projectM engine and ANGLE commits
the suite is built against, and a complete inventory of the reference: source folders, build
targets, package manifests, project generation files, scripts, tests, CI, dependencies and licenses.

**Why this priority**: Every later phase cites these facts; a wrong pin invalidates all evidence.

**Independent Test**: Rerun the inventory script on a clean checkout and compare its output with
the committed audit; every listed path exists and every pin matches `git submodule status`.

**Acceptance Scenarios**:

1. **Given** the repository with its submodule, **When** the audit runs, **Then** it records the
   superproject gitlink, the reference HEAD, the projectM and ANGLE pins with their fork URLs and
   branches, and fails if the reference checkout is modified.
2. **Given** the inventory, **When** an engineer looks up any package, target or script, **Then**
   it names the real path and its role (ProjectM-specific, reusable candidate or tooling).

---

### User Story 2 - Traced rendering pipeline (Priority: P1)

An engineer reads one document that traces, with file and symbol citations, app startup to
renderer creation; EGL display, context and surface creation; how GL calls reach ANGLE and its
Metal backend; and how presentation, frame scheduling, threading, synchronization, resize,
orientation, teardown and recreation work.

**Why this priority**: The VisualCore render host (F02) must reproduce this sequence exactly.

**Independent Test**: Every claim in the trace cites a path and symbol that a reviewer can open in
the pinned checkout and confirm.

**Acceptance Scenarios**:

1. **Given** the trace, **When** a reviewer follows each citation, **Then** the cited symbol exists
   at the cited path in the pinned reference commit.
2. **Given** a behavior the source does not settle (for example context-loss handling), **When**
   the trace reaches it, **Then** it is labelled *unknown* with a follow-up task ID.

---

### User Story 3 - Reusable-component inventory and gap analysis (Priority: P2)

An engineer sees which reference modules are ProjectM-specific, which are reusable candidates for
VisualCore, how shaders, textures, framebuffers and resource ownership are handled, and which
capabilities VisualCore still needs.

**Why this priority**: It stops speculative extraction and drives Phases 1–5.

**Independent Test**: Each inventory row cites its source files and states a classification with
a reason.

**Acceptance Scenarios**:

1. **Given** the inventory, **When** a module mixes ProjectM types into rendering, **Then** it is
   classified as ProjectM-specific, and the reusable portion is described separately.

---

### User Story 4 - Reproducible baseline build and smoke test (Priority: P2)

An engineer runs one documented command sequence on the project Mac that builds the unmodified
reference at the pinned commit and runs its existing automated tests on a simulator. The result is
recorded in a baseline report with the exact commit and toolchain.

**Why this priority**: Later regression checks (F07) need a known-good baseline.

**Independent Test**: Run the documented commands; the build log and test results match the report.

**Acceptance Scenarios**:

1. **Given** the pinned reference, **When** the baseline commands run, **Then** the engine and app
   builds succeed for the simulator and generic iOS, existing package tests pass on a simulator, and
   the reference checkout is still unmodified afterwards.
2. **Given** a baseline step that cannot run on this Mac, **When** it is attempted, **Then** the
   report records it as blocked with the observed error, not as passed.

### Edge Cases

- Reference checkout has local modifications: audit fails and names the files; nothing is reset.
- Generated build output would be written inside the reference: only its own gitignored outputs
  (`Build/`, generated `.xcodeproj`) are allowed; DerivedData goes to VisualCore's `Build/`.
- Prebuilt ANGLE frameworks built from a different commit than the pin: audit fails.
- Missing projectM engine framework: built with the reference's own script, never a new build system.
- Simulator-only results: recorded as functional evidence only, never as performance or device evidence.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F001**: The audit MUST record the superproject gitlink, reference HEAD, every nested
  submodule pin, fork URL and branch, and verify the projectM and ANGLE forks are the owner's on `ios`.
- **FR-F002**: The audit MUST fail if the reference checkout has tracked modifications before or
  after any audit or baseline step.
- **FR-F003**: The repository audit MUST inventory source folders, build targets, package
  manifests, project generation files, scripts, tests, CI workflows, dependencies and licenses of
  the reference, each with its path.
- **FR-F004**: The rendering-pipeline trace MUST cite path and symbol for app startup to renderer
  initialization, EGL context/surface creation, GL entry-point resolution into ANGLE, the Metal
  backend configuration and the presentation path.
- **FR-F005**: The trace MUST cover render scheduling, threading, synchronization, resize,
  orientation, teardown and recreation, labelling anything not settled by source as *unknown*
  with a follow-up task ID.
- **FR-F006**: The resource inventory MUST list shaders, textures, framebuffers and their
  ownership and cleanup paths in the reference renderer.
- **FR-F007**: The reusable-component inventory MUST classify every reference package as
  ProjectM-specific, reusable candidate or tooling, with a reason, and a gap analysis MUST list
  capabilities VisualCore needs that the reference does not provide.
- **FR-F008**: A baseline report MUST record a reproducible host/simulator build and smoke test of
  the unmodified reference at the pinned commit: engine framework build via the reference's own
  script, project generation, simulator builds of its three apps, a generic-iOS unsigned build of
  the visualizer app, and its renderer package tests on iOS 27.2 and 26.5 simulators, with
  toolchain versions, commands, exit codes and log hashes.
- **FR-F009**: The baseline MUST NOT install, launch or test anything on a physical device; the
  device inventory is read-only and identifiers stay out of committed files.
- **FR-F010**: No production source and no submodule revision may change in this feature.

### Key Entities

- **Reference pin set**: superproject gitlink, reference HEAD, nested submodule commits and remotes.
- **Inventory row**: path, kind (package/target/script/test/CI/dependency/license), role, citation.
- **Trace step**: stage, cited path and symbol, behavior, known/unknown, follow-up task.
- **Baseline record**: commit, toolchain, command, exit code, log path and hash, result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F001**: 100% of pins in the audit match `git submodule status` in a fresh check.
- **SC-F002**: 100% of trace citations resolve to an existing path and symbol at the pinned commit.
- **SC-F003**: Every reference package and app target (8 packages, 3 apps) appears in the inventory
  with a classification.
- **SC-F004**: All 5 baseline evidence items (engine build, project generation, 3 simulator app
  builds + 1 generic-iOS build, renderer package tests on 2 simulator runtimes, clean-tree check)
  exit 0, or each failure is recorded with its observed error and the gate stays unverified.
- **SC-F005**: Zero tracked-file changes in the reference checkout after the feature completes.
- **SC-F006**: Every *unknown* in the audit has a follow-up task ID.

## Assumptions

- The project Mac's toolchain matches the reference pins (verified 2026-11-10: Xcode 27.2 27B52,
  Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5).
- Writing generated output into the reference's gitignored `Build/` directory with the
  reference's own scripts is not a modification of its source (CLAUDE.md §4).
- XcodeGen output for the reference is written outside the reference checkout, or into its
  gitignored paths only.
- The already sealed F00 checks remain valid for what they measured; this feature adds the
  missing deliverables (ADR-0004).
