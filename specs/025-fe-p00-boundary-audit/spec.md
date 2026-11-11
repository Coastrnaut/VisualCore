# Feature Specification: Fractal Explorer — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `025-fe-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P00 · ID namespace FR-A03-0##, SC-A03-0##, T-A03-0##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- The app lives in this monorepo at `Apps/FractalExplorer/`, not in a separate repository (constitution 1.4.0, A03
  rules).
- Phase 00 is audit-only and modifies neither VisualCore nor ProjectM.
- Its gap register classifies each needed capability as available, requires adaptation or upstream gap, and names the
  VisualCore module that will own each reusable gap later (Principle II, "Maximize reuse"). For this app that covers
  complex-plane viewports, precision, palettes, camera math, bookmarks and capture.
- It reuses the app-neutral contract checker built in A01-P00, as A02 did.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each
case. Facts were checked in code:
- `Camera2D` (VisualCoreMath) clamps zoom to 0.1…100;
- `vcglGetShaderPrecisionFormat` exists in the C GL table, but no public Swift precision query exists in
  `RenderCapabilities`;
- `Palette` (VisualCoreParameters), `PinchRecognizer` and `DragRecognizer` (VisualCoreScenes) exist;
- `FullScreenShaderScene` and `FieldPass` exist (VisualCoreRendering);
- `DocumentStore` and `TemporaryFolder` exist (VisualCorePersistence).

- Q: Where do the inventory, matrix and gap register live, and how are citations checked? → A: In
  `docs/apps/fractal-explorer/visualcore-contract.json` (the A01/A02 schema), rendered to `visualcore-contract.md`
  and checked by `scripts/check_app_contract.py --app fractal-explorer`. The release check's `app-contracts` step
  picks it up automatically.
- Q: What exactly is the app shell? → A: A thin SwiftUI app target `FractalExplorer` in the root `project.yml`
  (sources in `Apps/FractalExplorer/App/`), plus a UI smoke-test target. It has a titled home screen only, with no
  rendering code and no app-local package. The domain package arrives in Phase 01 (manual §5 file policy: no empty
  files).
- Q: Which ProjectM regression steps form the baseline? → A: The same 7 steps as A01 and A02, in two `run-check`
  chunks: engine xcframework, reference app build and read-only check; then ANGLERendering and ProjectMReference
  tests on both runtimes.
- Q: How does the audit classify precision management and deep-zoom coordinates? → A: Both are `requires
  adaptation`:
  - **Precision**: the C GL table can query shader precision, but no public Swift API reports the fragment `highp`
    range and mantissa bits. The register assigns a precision query on `RenderCapabilities` (VisualCoreRendering)
    and a pure precision advisor (VisualCoreMath) to Phase 02, which renders first.
  - **Coordinates**: `Camera2D` caps zoom at 100× and is for point-space scenes. A generic double-precision
    complex-plane viewport, with screen↔plane transforms and anchored pinch, goes to VisualCoreMath in Phase 01.
  - The matrix assumes 32-bit shader floats and no double support.
- Q: Does the shell need permissions, and are performance or precision targets set? → A: No permission, usage
  description or networking. No performance or precision target is set or measured. Iteration caps and precision
  limits come in later phases as data, and device measurement is campaign II.

## User Scenarios & Testing *(mandatory)*

Users:
- the engineer (agent) who implements Fractal Explorer phases 01–06;
- the owner reviewing the stop/go decision;
- the developers of other apps who reuse what this audit puts into VisualCore. For example, complex-plane viewports
  and precision advice for A16 Simulation Lab or A22 Shader Studio, and bookmarks for any app with saved views.

### User Story 1 - Evidence-backed integration matrix (Priority: P1) 🎯

Before writing any fractal code, the implementer can read one matrix that maps every capability the app needs to real
VisualCore files, symbols and package products, each with a status and an example consumer.

**Why this priority**: The manual's first acceptance gate and its required capability audit (§6). Every later phase
relies on it to avoid inventing APIs.

**Independent Test**: Open the matrix. Every row cites existing files, public symbols and package products, and the
shared contract check confirms that each citation resolves in the current tree.

**Acceptance Scenarios**:

1. **Given** the five brainstorm capabilities (high-resolution fragment shaders, coordinate transforms, precision
   management, parameter animation, color mapping and palette systems), **When** the matrix is read, **Then** each
   has a row with a status, evidence and an example consumer.
2. **Given** the matrix, **When** the citation check runs, **Then** every cited file and symbol resolves. A renamed or
   removed symbol fails the check and is named.

---

### User Story 2 - Inventory of the host, thread, build and regression baseline (Priority: P1)

The implementer knows how VisualCore renders, how it is built and tested, which sources own what, and which ProjectM
regression tests protect the shared seam. This covers what matters to a fractal explorer:
- full-screen fragment passes and their uniforms (float precision on the ANGLE path);
- offscreen high-resolution capture;
- palette and color utilities;
- pinch and pan recognizers;
- document persistence;
- frame pacing and thermal state.

**Why this priority**: Without it, later phases risk a second GL lifecycle, a silent Metal shortcut for precision, or
breaking the reference.

**Independent Test**: Read the inventory. Each build or test command it lists runs once in this phase, and its
recorded result matches.

**Acceptance Scenarios**:

1. **Given** the inventory, **When** read, **Then** it names, each with file references:
   - the render host entry point, its main-thread rule and context-loss behavior;
   - shader loading, uniforms and diagnostics, including the shader precision qualifiers in use;
   - the full-screen pass helpers;
   - palettes and color utilities;
   - pinch and pan input;
   - document persistence and temporary files;
   - frame pacing and thermal policy;
   - offscreen export.
2. **Given** the listed ProjectM regression steps, **When** they run, **Then** they pass, and their results are
   recorded as this phase's baseline.

---

### User Story 3 - Compilable empty app shell (Priority: P1)

An empty Fractal Explorer app builds and launches on the simulator before any fractal code exists. It proves the
target, the bundle identity and the package wiring.

**Why this priority**: The manual's second acceptance gate.

**Independent Test**: Build for both simulator runtimes and run a smoke UI test that finds the app's title.

**Acceptance Scenarios**:

1. **Given** the shell, **When** built for the iOS 27.2 and 26.5 simulators, **Then** it compiles without signing and
   launches to a titled home screen with a spoken label.
2. **Given** the shell, **When** its dependencies are audited, **Then** it links no ProjectM engine, preset or bridge
   module.

---

### User Story 4 - Gap register and stop/go decision (Priority: P2)

The owner reads a written stop/go decision. It lists everything missing upstream, where each piece will be built (a
named VisualCore module for reusable work, the app for fractal-specific work) and the phase that builds it.

**Why this priority**: The manual's third acceptance gate. It also applies the reuse rule and the A03 precision rule
(precision is a stated limit of the OpenGL ES shader path, never solved with a silent Metal renderer) before any code
is written.

**Independent Test**: Every `upstream gap` or `requires adaptation` row has a register entry with an owner module, a
phase and a test intent. The decision states go or stop with reasons.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** read, **Then** every gap names an owning VisualCore module (existing or new) or
   justifies keeping it in the app, and names the phase (01–06) that closes it.
2. **Given** a missing capability that would need a second renderer, a VisualCore fork, double-precision GPU support
   not offered by the path, or private APIs, **When** the decision is made, **Then** it is recorded as a blocker
   (stop) or as a bounded limitation with a visible clamp, never worked around silently.

### Edge Cases

- A capability exists only inside the ProjectM reference: it counts as unavailable to the app and goes into the
  register as a gap.
- Shader float precision depends on the GPU and the ANGLE translation. The matrix MUST say how precision is
  determined (`highp` availability, measured mantissa) and what the clamp is. It must not assume double precision.
- A citation that points only to test code: evidence must include a public, non-test symbol. A test may serve as the
  example consumer.
- The reference build or its regression fails: the phase is blocked and recorded, never waived.
- A performance or precision figure from a simulator or host run: context only, never a device or budget claim.
- A matrix row with no consumer anywhere in the repository: `requires adaptation` until an example exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-001**: The phase MUST produce a read-only repository inventory. Each entry cites a file path. It lists:
  - the VisualCore package products and their modules;
  - the render host entry point and thread rule;
  - the shader, uniform and precision APIs, and the full-screen pass helpers;
  - palettes and color utilities;
  - pinch and pan input;
  - document persistence and temporary files;
  - frame pacing and thermal policy;
  - offscreen export;
  - build steps (XcodeGen specs, schemes, scripts) and the source ownership of each area.
- **FR-A03-002**: The phase MUST produce an integration matrix covering the five brainstorm capabilities plus five
  version 0.1 needs:
  - continuous pinch/pan camera;
  - location bookmarks with precision mode;
  - an iteration cap with a render-cost estimate;
  - still capture with guided tours;
  - visible precision limits with graceful clamping.

  Each row has the status `available` / `requires adaptation` / `upstream gap`, the evidence (file, public symbol,
  package product) and an example consumer.
- **FR-A03-003**: Matrix citations MUST pass the shared, app-neutral contract checker
  (`scripts/check_app_contract.py --app fractal-explorer`). Every cited file must exist and every cited symbol must be
  declared in it.
- **FR-A03-004**: The phase MUST record the baseline ProjectM regression with the commands run and their results:
  the reference engine build and app build, its renderer tests on both simulator runtimes, the read-only check, and
  the ProjectMReference harness tests on both runtimes.
- **FR-A03-005**: The phase MUST create a compilable, empty app shell under `Apps/FractalExplorer/` with bundle
  identity `dev.visualcore.FractalExplorer`.
  - It builds unsigned for both simulator runtimes.
  - It shows a titled home screen with an accessibility label and passes a launch smoke test.
  - It requests no permission and declares no usage description or networking.
  - It creates no render host and no GPU resources.
- **FR-A03-006**: The shell MUST NOT link ProjectM engine, preset or bridge modules. The dependency audit build phase
  MUST cover the new target.
- **FR-A03-007**: The phase MUST NOT modify any VisualCore package source, the ProjectM reference or its pins. This is
  verified by a diff check of those paths for this phase's commits.
- **FR-A03-008**: The phase MUST produce a gap register. Each `requires adaptation` or `upstream gap` entry names:
  - the owning VisualCore module (existing or proposed), or a justification for keeping it in the app;
  - the phase (01–06) that closes it;
  - the test that will prove it.

  Reusable work goes to VisualCore by default (Principle II). The fractal formulas themselves (escape-time iteration
  for Mandelbrot and Julia) stay app-domain with a CPU reference (A03 rule).
- **FR-A03-009**: The phase MUST record a stop/go decision with reasons. These are stop conditions:
  - a second renderer, or a fork of VisualCore or ProjectM;
  - private APIs or networking;
  - a promise of precision beyond what the shader path can verify.
- **FR-A03-010**: The phase MUST record traceability from the brainstorm concept, the version 0.1 features (01–06) and
  the journeys (1–3) to matrix rows and planned phases. Each feature and journey maps to at least one phase.
- **FR-A03-011**: The phase MUST record negative requirements for the app, each with the source that forbids it:
  - no unlimited deep zoom on 32-bit floats;
  - no scientific precision claims beyond verified shader support;
  - no community gallery and no user-coded formulas;
  - no networking;
  - no Metal renderer for precision;
  - no device-performance claims before campaign II.

### Key Entities

- **Inventory entry**: area, description, file path(s), owner (package/module or script), notes.
- **Matrix row**: capability, source (brainstorm or v0.1 feature), status, evidence (file, symbol, product), example
  consumer, notes.
- **Gap entry**: capability, gap type (adaptation or upstream), owning module (VisualCore module or app with
  justification), closing phase, test intent.
- **Decision record**: go/stop, date, blockers, assumptions, evidence links.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-001**: 100% of matrix citations resolve in the automated check, with 0 unresolved.
- **SC-A03-002**: 10 of 10 capability rows (5 brainstorm plus 5 version 0.1 needs) carry a status, evidence and an
  example consumer or a justified gap.
- **SC-A03-003**: The empty app shell builds and passes its launch smoke test on both simulator runtimes (2 of 2).
- **SC-A03-004**: The baseline ProjectM regression passes all its recorded steps, with 0 failures.
- **SC-A03-005**: 100% of gaps name an owner and a closing phase, and reusable gaps are assigned to a VisualCore
  module.
- **SC-A03-006**: 0 changes to VisualCore package sources or the ProjectM reference in this phase's commits.
- **SC-A03-007**: 6 of 6 version 0.1 features and 3 of 3 journeys trace to at least one phase.

## Assumptions

- The audited baseline is the VisualCore packages as of gate A02-P06 (Fluid Art Playground complete). That includes:
  - field passes and ping-pong targets;
  - the synthetic gesture script and the automation hooks;
  - the temporary folder;
  - offscreen export, the effect graph and the release tooling.

  The reference stays pinned at `d93edd1`.
- The app shell uses existing VisualCore products only as dependencies. No VisualCore code is written in Phase 00.
- The iOS 27.2 and 26.5 simulator runtimes are available. Device evidence is out of scope until campaign II.
- The manual's separate-repository layout is replaced by the monorepo layout `Apps/FractalExplorer/` (CLAUDE.md §4).
  Its file names guide later phases.

## Traceability

| Source | Covered by |
|---|---|
| Brainstorm: high-resolution fragment shaders, coordinate transforms, precision management, parameter animation, color mapping and palettes | FR-A03-002 matrix rows |
| v0.1 features 01–06 | FR-A03-002 rows and FR-A03-010 phase mapping |
| Journeys 1–3 (curated start, pinch/pan; Mandelbrot/Julia with seed scrub; bookmark and capture with precision warning) | FR-A03-010 |
| Manual Phase 00 gates (matrix, empty shell, stop/go) | US1, US3, US4 |
| Manual §6 required capability audit | FR-A03-002, FR-A03-003 |
| Manual §13 risks 1–3 (precision, iteration freezes, gesture drift) | FR-A03-008 gap register, FR-A03-011 |

## Negative Requirements

- No modification of VisualCore or the ProjectM reference in this phase.
- No second renderer, no Metal path for precision, no EGL in the app.
- No networking, no permissions, no usage descriptions in the shell.
- No precision, compatibility or performance claims from simulator runs.
