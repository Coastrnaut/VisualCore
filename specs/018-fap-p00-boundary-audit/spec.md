# Feature Specification: Fluid Art Playground — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `018-fap-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P00 · ID namespace FR-A02-0##, SC-A02-0##, T-A02-0##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation). Canonical overrides:
- The app lives in this monorepo at `Apps/FluidArtPlayground/`, not in a separate repository (constitution 1.3.0,
  A02 rules).
- Phase 00 is audit-only and modifies neither VisualCore nor ProjectM.
- Its gap register classifies each needed capability as available, requires adaptation or upstream gap, and names
  the VisualCore module that will own each reusable gap later (Principle II, "Maximize reuse").
- It reuses the app-neutral contract checker built in A01-P00.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each case.

- Q: Where do the inventory, matrix and gap register live, and how are citations checked? → A: In
  `docs/apps/fluid-art-playground/visualcore-contract.json` (machine-readable, the same schema as A01) rendered to
  `visualcore-contract.md`, and checked by the shared `scripts/check_app_contract.py --app fluid-art-playground`. The
  release check's `app-contracts` step picks it up automatically.
- Q: What exactly is the app shell? → A: A thin SwiftUI app target `FluidArtPlayground` in the root `project.yml`
  (sources in `Apps/FluidArtPlayground/App/`), plus a UI smoke-test target. It has a titled home screen only, with no
  rendering code and no app-local package. The domain package arrives in Phase 01 (manual §5 file policy: no empty
  files).
- Q: Which ProjectM regression steps form the baseline? → A: The same 7 steps as A01: `engine-xcframework`,
  `build-projectm-ios-sim`, `test-anglerendering-ios27`, `test-anglerendering-ios26`, `check_reference_clean.py`, and
  the ProjectMReference harness tests on both runtimes.
- Q: How does the audit treat half-float render targets, which the solver's velocity and pressure fields need? → A:
  As `requires adaptation`. `TextureFormat.rgba16f` exists and `makeRenderTarget` already throws
  `incompleteFramebuffer` when a format is not renderable. There is no capability query, though, and the only
  consumer is the HDR bloom pass. The register assigns a support query and a documented RGBA8 fallback to
  VisualCoreRendering in the phase that first renders the solver, and the matrix assumes no support.
- Q: Does the shell need permissions, and are performance targets set? → A: No permission, usage description or
  networking. No performance target is set or measured. Simulation budgets come in later phases as quality-profile
  data, and device measurement is campaign II.

## User Scenarios & Testing *(mandatory)*

Users: the engineer (agent) who implements Fluid Art Playground phases 01–06, the owner reviewing the stop/go
decision, and the developers of other apps who reuse what this audit puts into VisualCore (for example, ping-pong
simulation targets for A16 Simulation Lab or A11 Physics Playground).

### User Story 1 - Evidence-backed integration matrix (Priority: P1) 🎯

Before writing any fluid code, the implementer can read one matrix that maps every capability the app needs to real
VisualCore files, symbols and package products, each with a status and an example consumer.

**Why this priority**: The manual's first acceptance gate, and its required capability audit (§6). Every later phase
relies on it to avoid inventing APIs.

**Independent Test**: Open the matrix. Every row cites existing files, public symbols and package products, and the
shared contract check confirms that each citation resolves in the current tree.

**Acceptance Scenarios**:

1. **Given** the six brainstorm capabilities (ping-pong framebuffers, texture feedback, GPU simulation techniques,
   shader-based advection and diffusion, touch input as simulation forces, color blending and post-processing),
   **When** the matrix is read, **Then** each has a row with a status, evidence and an example consumer.
2. **Given** the matrix, **When** the citation check runs, **Then** every cited file and symbol resolves. A renamed or
   removed symbol fails the check and is named.

---

### User Story 2 - Inventory of the host, thread, build and regression baseline (Priority: P1)

The implementer knows how VisualCore renders, how it is built and tested, which sources own what, and which ProjectM
regression tests protect the shared seam. This covers what matters to a GPU fluid solver: render-target formats,
pooled targets, framebuffer completeness, the effect graph's feedback history, frame pacing and thermal state.

**Why this priority**: Without it, later phases risk a second GL lifecycle, read/write feedback on one texture, or
breaking the reference.

**Independent Test**: Read the inventory. Each build or test command it lists runs once in this phase, and its
recorded result matches.

**Acceptance Scenarios**:

1. **Given** the inventory, **When** read, **Then** it names, each with file references:
   - the render host entry point, its main-thread rule and context-loss behavior;
   - the resource registry, its budgets, render-target formats and pool;
   - shader loading and diagnostics;
   - the effect graph with its feedback pass;
   - pointer input;
   - frame pacing and thermal policy;
   - offscreen export.
2. **Given** the listed ProjectM regression steps, **When** they run, **Then** they pass, and their results are
   recorded as this phase's baseline.

---

### User Story 3 - Compilable empty app shell (Priority: P1)

An empty Fluid Art Playground app builds and launches on the simulator before any fluid code exists. It proves the
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
named VisualCore module for reusable work, the app for fluid-specific work) and the phase that builds it.

**Why this priority**: The manual's third acceptance gate. It also applies the reuse rule and the A02 domain rule
(the solver is app-domain with a CPU reference) before any code is written.

**Independent Test**: Every `upstream gap` or `requires adaptation` row has a register entry with an owner module, a
phase and a test intent. The decision states go or stop with reasons.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** read, **Then** every gap names an owning VisualCore module (existing or new) or
   justifies keeping it in the app, and names the phase (01–06) that closes it.
2. **Given** a missing capability that would need a second renderer, a VisualCore fork or unsupported GPU features,
   **When** the decision is made, **Then** it is recorded as a blocker (stop), never worked around.

### Edge Cases

- A capability exists only inside the ProjectM reference: it counts as unavailable to the app and goes into the
  register as a gap.
- Half-float render targets depend on the GPU and ANGLE extensions. The matrix MUST say how support is detected and
  what the fallback is. It must not assume support.
- A citation that points only to test code: evidence must include a public, non-test symbol. A test may serve as the
  example consumer.
- The reference build or its regression fails: the phase is blocked and recorded, never waived.
- A performance figure from a simulator or host run: context only, never a device or budget claim.
- A matrix row with no consumer anywhere in the repository: `requires adaptation` until an example exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-001**: The phase MUST produce a read-only repository inventory. It lists:
  - the VisualCore package products and their modules;
  - the render host entry point and thread rule;
  - shader and resource APIs, including render-target formats and pooling;
  - the effect graph and its feedback history;
  - pointer input, frame pacing and thermal policy, and offscreen export;
  - build steps (XcodeGen specs, schemes, scripts) and the source ownership of each area.

  Each entry cites a file path.
- **FR-A02-002**: The phase MUST produce an integration matrix covering the six brainstorm capabilities plus four
  version 0.1 needs: bounded quality with thermal downgrade; pause, reset and a deterministic seeded test mode; still
  capture; float render-target support with fallback. Each row has the status `available` / `requires adaptation` /
  `upstream gap`, the evidence (file, public symbol, package product) and an example consumer.
- **FR-A02-003**: Matrix citations MUST pass the shared, app-neutral contract checker
  (`scripts/check_app_contract.py --app fluid-art-playground`). Every cited file must exist and every cited symbol
  must be declared in it.
- **FR-A02-004**: The phase MUST record the baseline ProjectM regression with the commands run and their results:
  the reference engine build and app build, its renderer tests on both simulator runtimes, the read-only check, and
  the ProjectMReference harness tests on both runtimes.
- **FR-A02-005**: The phase MUST create a compilable, empty app shell under `Apps/FluidArtPlayground/` with bundle
  identity `dev.visualcore.FluidArtPlayground`. It builds unsigned for both simulator runtimes, shows a titled home
  screen with an accessibility label, and passes a launch smoke test. It requests no permission and declares no usage
  description or networking. It creates no render host and no GPU resources.
- **FR-A02-006**: The shell MUST NOT link ProjectM engine, preset or bridge modules. The dependency audit build phase
  MUST cover the new target.
- **FR-A02-007**: The phase MUST NOT modify any VisualCore package source, the ProjectM reference or its pins. This is
  verified by a diff check of those paths for this phase's commits.
- **FR-A02-008**: The phase MUST produce a gap register. Each `requires adaptation` or `upstream gap` entry names:
  - the owning VisualCore module (existing or proposed), or a justification for keeping it in the app;
  - the phase (01–06) that closes it;
  - the test that will prove it.

  Reusable work goes to VisualCore by default (Principle II). The fluid equations themselves stay app-domain with a
  CPU reference (A02 rule).
- **FR-A02-009**: The phase MUST record a stop/go decision with reasons. A second renderer, a fork of VisualCore or
  ProjectM, private APIs, networking, or a dependency on an unverified GPU feature without a fallback are stop
  conditions.
- **FR-A02-010**: The phase MUST record traceability from the brainstorm concept, the version 0.1 features (01–06) and
  the journeys (1–3) to matrix rows and planned phases. Each feature and journey maps to at least one phase.
- **FR-A02-011**: The phase MUST record negative requirements for the app, each with the source that forbids it:
  - no physically accurate water surface;
  - no 3D fluid dynamics;
  - no unbounded particle emission or background compute;
  - no networking;
  - no ProjectM linkage;
  - no second EGL path;
  - no physical-accuracy claims;
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

- **SC-A02-001**: 100% of matrix citations resolve in the automated check, with 0 unresolved.
- **SC-A02-002**: 10 of 10 capability rows (6 brainstorm plus 4 version 0.1 needs) carry a status, evidence and an
  example consumer or a justified gap.
- **SC-A02-003**: The empty app shell builds and passes its launch smoke test on both simulator runtimes (2 of 2).
- **SC-A02-004**: The baseline ProjectM regression passes all its recorded steps, with 0 failures.
- **SC-A02-005**: 100% of gaps name an owner and a closing phase, and reusable gaps are assigned to a VisualCore
  module.
- **SC-A02-006**: 0 changes to VisualCore package sources or the ProjectM reference in this phase's commits.
- **SC-A02-007**: 6 of 6 version 0.1 features and 3 of 3 journeys trace to at least one phase.

## Assumptions

- The VisualCore packages as of gate A01-P06 (Generative Art Studio complete), including offscreen export,
  accessibility settings, the shared automation view and the release tooling, are the audited baseline. The reference
  stays pinned at `d93edd1`.
- The app shell uses existing VisualCore products only as dependencies. No VisualCore code is written in Phase 00.
- The iOS 27.2 and 26.5 simulator runtimes are available. Device evidence is out of scope until campaign II.
- The manual's separate-repository layout is replaced by the monorepo layout `Apps/FluidArtPlayground/`
  (CLAUDE.md §4). Its file names guide later phases.
