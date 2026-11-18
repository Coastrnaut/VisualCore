# Feature Specification: Shader Studio — Phase 05 Stress-test shader failures and device recovery

**Feature Branch**: `163-ss-p05-stress-recovery` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A22-P05 (legacy ledger) · ID namespace FR-A22-5##, SC-A22-5##, T-A22-5##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: local project save and open with versioned shader files. It was built in A22-P04 (`ProjectLibrary`) and is
    proved again here across a relaunch;
  - regression fixture: repeated compile and run cycles do not leak shader or program objects;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-DEVICE of `docs/apps/shader-studio/visualcore-contract.json`: a device-campaign plan whose
  rows stay pending until the campaign after `ImplementationLock-100` (CLAUDE.md rule 5).
- **A22-P04 deferral:** the core's uniform and texture bounds follow the live project, not the selected template, so
  an opened or edited project with its own uniforms keeps every value.
- **Still a candidate.** No VisualCore or ProjectM change. Follow `specs/156-au-p05-sound-device` (device plan) and
  `specs/162-ss-p04-limits-error-ux`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Resource level:** `ResourceRegistry.stats` (a `ResourceLedger.Snapshot`) gives `liveCount` and `liveBytes` per
  `ResourceKind`, `totalBytes`, `peakBytes` and `leaked`, the objects still live when a context was destroyed or
  recreated.
- **Context rebuild:** `ExperienceSession.recreateContext()` and `RenderHost.recreateContext()` rebuild the context;
  the presenter tears down and sets up again (A22-P02 `RebuildTests`).
- **Bounds:** `StudioCore` bounds `uniform.set` and `texture.set` by
  `uniformCount(template:)` and `textureInputCount(template:)` (`a22.no-uniform`, `a22.no-texture`).
- **Device plan:** Aurora's `docs/apps/aurora/device-campaign.md` is the pattern; D1 iPhone 15 (iOS 27), D2 iPad Pro
  13-inch (M5), D3 iPad (A16) on iPadOS 26.5.

- Q: What is the "resource level" and when is it taken? → A: `liveCount` for every kind plus `totalBytes` of the
  host's registry, read after the first cycle (the warm-up) and after the last; the two MUST be equal, and `leaked`
  MUST stay 0 across rebuilds.
- Q: How does the core learn the live project's shape? → A:
  - **Action:** the core action `document.shape [0…16, 0…2]`, both whole. The presenter sends it whenever the
    document's uniform count or texture-input count changes (an edit, an open, a template choice, a restore). It is
    deterministic and replayable, and the core still reads no source.
  - **Bounds:** `uniform.set k` needs k < the shape's uniforms; `texture.set i` needs i < the shape's inputs.
  - **Snapshot:** `shape` is an optional field. Without it, a snapshot reads the template's counts, so A22-P04
    snapshots restore. The digest covers it.
  - **Values:** values are kept by position. A uniform at position k keeps value k across a shape change, and
    positions past the new count are ignored until they return.
- Q: How is the stress run kept short? → A:
  - **Cycles:** 50 cycles of three runs each (a new source that compiles, a source that fails to compile, a refused
    source), then 20 template changes, 10 stop-and-reset cycles, and 10 rebuilds in each of 5 states.
  - **Drawing:** each run draws one frame at 32 × 24, so the counts are bounded by arithmetic.
  - **Placement:** the tests are split into several so that each finishes in under 10 s on the simulator.
- Q: How is "survives a relaunch" proved? → A: An interface test, `SSRecoveryUITests` in the serial chunk `d3`:
  1. launch with `-vcResetData` and save "Waves";
  2. terminate the app and launch it again without `-vcResetData`;
  3. open the library: `project-0` is "Waves", and opening it gives the saved source.

  An experience test also reopens the library from a new `ExperienceStorage` on the same root.
- Q: Which rows does the device plan hold? → A: `docs/apps/shader-studio/device-campaign.md`, with rows SS-D1 to
  SS-D6 per device, all pending:
  - **SS-D1:** a slow template is stopped by the watchdog within 3 s, and Reset recovers;
  - **SS-D2:** a compile error is marked on the line the person wrote;
  - **SS-D3:** a hardware keyboard: typing, ⌘R and ⌘'. On D1 this needs a keyboard connected by the owner;
  - **SS-D4:** a saved project survives a relaunch;
  - **SS-D5:** the compatibility profile (GLES version, fragment `highp`, maximum texture size) is recorded;
  - **SS-D6:** moving to the background and back keeps the picture, with no leak.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Many runs, no build-up (Priority: P1) 🎯

A person spends an evening iterating: hundreds of edits, failed runs, successful runs, template changes and slow
shaders that get stopped. The studio uses the same graphics resources at the end as after the first few runs.

**Why this priority**: it is the manual's regression fixture for this phase; a leak would end in a crash on a device.

**Independent Test**: run a fixed cycle of failing, refused, succeeding and stopped shaders many times and compare the
live graphics objects and bytes after the warm-up with those at the end.

**Acceptance Scenarios**:

1. **Given** 50 cycles of a successful run of a new source, a failing run and a refused run, **Then** the live
   programs, textures and bytes after the last cycle equal those after the first cycle.
2. **Given** 20 template changes across all four templates (with textures), **Then** the same holds.
3. **Given** a slow shader stopped and reset 10 times, **Then** the same holds.

---

### User Story 2 - Recovery after the system takes the graphics away (Priority: P1)

The system takes the graphics context away (memory pressure, the app moving to the background, a display change). When
Shader Studio comes back, the person's shader, its values, its textures and the stopped or running state are as
before, and nothing is left behind.

**Why this priority**: device recovery is the phase's title; a lost context is ordinary on iOS.

**Independent Test**: rebuild the context 10 times at each state (running, failed, stopped, textured) and compare the
picture and the live resources.

**Acceptance Scenarios**:

1. **Given** each state, **When** the context is rebuilt, **Then** the picture is the same as before and the live
   resources return to the same count.
2. **Given** 10 rebuilds in a row, **Then** nothing accumulates.

---

### User Story 3 - My project is still there tomorrow (Priority: P1)

A person saves a project, closes the app, and opens it again later. The project is in the library and opens with its
source, values and textures, including uniforms the starter template did not have.

**Why this priority**: the phase's MVP; A22-P04 left values past the template's uniforms at their defaults.

**Independent Test**: save, relaunch the app without resetting data, open, and compare.

**Acceptance Scenarios**:

1. **Given** a saved project, **When** the app is relaunched, **Then** it is listed and opens with the same source.
2. **Given** a project with more uniforms or texture inputs than the selected template, **When** it is opened or
   edited, **Then** every value and texture choice is kept and can be changed in the inspector.

---

### User Story 4 - A plan for the devices (Priority: P2)

The owner has a device plan that lists, per device, what to measure once implementation is locked: a slow template
stopped by the watchdog, a compile error on the right line, a hardware-keyboard run, the library across a relaunch, and
the compatibility profile.

**Why this priority**: G-DEVICE; simulator results are never device evidence.

**Independent Test**: the plan's rows exist per device with their steps and stay pending.

**Acceptance Scenarios**:

1. **Given** the plan, **Then** each of D1, D2 and D3 has rows SS-D1 to SS-D6 with steps and expected results, all
   pending.

### Edge Cases

- **A cycle that ends while a compile is queued:** a request already waiting inside the pipeline is dropped by a
  teardown; a Run the core accepted before a rebuild compiles once after it (decision at T-A22-504: the core has
  counted it, so the preview follows the core); nothing leaks.
- **A context rebuild during a stopped preview:** it stays stopped (A22-P04) and the flat frame is rebuilt.
- **A context rebuild with a library sheet open:** the sheet is native interface, independent of the graphics context,
  so it is unaffected by construction; the picture comes back behind it.
- **A project whose uniforms change on a later edit:** values are kept by position; positions past the new count are
  ignored until a later shape includes them again.
- **A snapshot from A22-P04:** it restores; without `shape` its bounds are the template's counts until the presenter
  sends the document's shape.
- **Memory warnings:** handled by the host's context rebuild; Shader Studio holds no other cache.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-501**: Repeated cycles of successful, failing, refused and stopped runs and of template changes MUST leave
  the live graphics programs, textures and bytes equal to their level after the first cycle.
- **FR-A22-502**: A context rebuild in every state (running, failed, refused, stopped, textured) MUST restore the same
  picture and the same live resource counts; repeated rebuilds MUST NOT accumulate resources.
- **FR-A22-503**: The core's bounds for `uniform.set` and `texture.set` MUST follow the live project's uniform and
  texture-input counts, so that a project with its own uniforms keeps and changes every value.
- **FR-A22-504**: Saved projects MUST survive a relaunch of the app and open with their source, values and textures.
- **FR-A22-505**: A device-campaign plan MUST list, for D1, D2 and D3, the rows SS-D1 to SS-D6 with steps and expected
  results and the owner actions each row needs, every row pending until the campaign after
  `ImplementationLock-100`.
- **FR-A22-506**: Interface tests MUST cover a project surviving a relaunch, in the one app on the iOS 27 phone.

### Key Entities

- **Stress cycle**: a fixed sequence of actions (sources, runs, template changes, stops and resets), repeated a declared
  number of times.
- **Resource level**: the live programs, textures and bytes of the host's resource registry.
- **Project shape**: the live project's uniform count and texture-input count, which bound the core's actions.
- **Device row**: a device, an identifier, steps, the expected result and its state (pending).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-501**: After 50 mixed cycles, 20 template changes and 10 stop-and-reset cycles, the resource level equals the
  level after the first cycle in 100% of runs.
- **SC-A22-502**: 10 context rebuilds in each of 5 states give byte-identical pictures and an unchanged resource level.
- **SC-A22-503**: A project with uniforms beyond its template opens with 100% of its values; a relaunch keeps 100% of
  saved projects.
- **SC-A22-504**: The device plan has 18 pending rows (6 per device); the interface tests each finish in under 60
  seconds and unit tests in under 10 seconds.

## Assumptions

- The A22-P02 pipeline, the A22-P03 textures and the A22-P04 watchdog and library are reused.
- The host's `recreateContext` stands for a lost context in tests; real driver behaviour is measured on devices.
- Cycle counts are short (bounded by arithmetic, not soak runs).
- The experience's storage persists across app launches and is cleared only by `-vcResetData` (the app's test
  argument) or by the person deleting the app.

## Traceability

| Source | Requirement |
|---|---|
| MVP: local project save/open and versioned shader files (A22-P04, proved across a relaunch) | FR-A22-504, 506 |
| Regression fixture: compile/run repeated cycles do not leak shader/program objects | FR-A22-501, SC-A22-501 |
| A22-P04 deferral: bounds follow the live project | FR-A22-503 |
| Risk 1 (driver behaviour), device verification | FR-A22-502, 505 |
| Contract G-DEVICE | FR-A22-505 |

## Negative Requirements

- No VisualCore or ProjectM change; no GL call outside VisualCore's scenes; no compile from a control's action.
- No device install, launch or test before `ImplementationLock-100`; simulator results are never device evidence.
- No soak or long-duration run; no sandbox claim.
- Not available before X-A22.
