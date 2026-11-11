# Feature Specification: Generative Art Studio — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `011-gas-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: A01-P00 · ID namespace FR-A01-0##, SC-A01-0##, T-A01-0##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: the app lives in this monorepo at `Apps/GenerativeArtStudio/`, not in a
separate repository. Phase 00 is audit-only and modifies neither VisualCore nor ProjectM. Its gap register classifies
each needed capability as available / requires adaptation / upstream gap, and names the VisualCore module that will
own each reusable gap later (constitution 1.2.0, Principle II "Maximize reuse"). Evidence is host and simulator only
(constitution V).

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each case.

- Q: Where do the inventory, matrix and gap register live, and how are citations checked? → A: In
  `docs/apps/generative-art-studio/visualcore-contract.md` (human-readable) generated from
  `visualcore-contract.json` (machine-readable rows). A new, app-neutral `scripts/check_app_contract.py --app <slug>`
  verifies every cited file and symbol. It is reusable by all 25 apps (Principle II, "Maximize reuse").
- Q: What exactly is the app shell in Phase 00? → A: A thin SwiftUI app target `GenerativeArtStudio` in the root
  `project.yml` (sources in `Apps/GenerativeArtStudio/App/`), plus a UI smoke-test target. It has a titled home
  screen only, with no rendering code and no app-local package yet. Domain and reusable packages are created in the
  phase that first needs them, so no empty files are pre-created (manual §5 file policy).
- Q: Which ProjectM regression steps form the baseline? → A: The reference steps `engine-xcframework`,
  `build-projectm-ios-sim`, `test-anglerendering-ios27` and `test-anglerendering-ios26`; `check_reference_clean.py`;
  and the `ProjectMReference` harness tests on both simulator runtimes. These are the same steps the release check
  runs.
- Q: Does the shell need any permission or privacy declaration? → A: No. It requests no permission and declares no
  usage description and no networking. The Photos add-only permission needed for still export is decided in
  Phase 04 and disclosed before use (A01 offline-first rule).
- Q: Are any performance targets set or measured in Phase 00? → A: No. The phase records only the existing host and
  simulator baselines as context. Frame and export budgets are set in Phases 02/04 and measured on devices only in
  campaign II (constitution V); the matrix may not claim device performance.

## User Scenarios & Testing *(mandatory)*

Users: the engineer (agent) who implements Generative Art Studio phases 01–06, the owner reviewing the stop/go
decision, and the developers of the other 24 apps who reuse what this audit puts into VisualCore.

### User Story 1 - Evidence-backed integration matrix (Priority: P1) 🎯

Before writing any graphics code, the implementer can read one matrix that maps every capability the app needs to
real VisualCore files, symbols and package products, each with a status and a working example.

**Why this priority**: The manual's first acceptance gate requires it. Every later phase relies on it to avoid
inventing APIs.

**Independent Test**: Open the matrix. Every row cites an existing file path, a public symbol and a package product,
and an automated check confirms that each cited path and symbol exists in the current tree.

**Acceptance Scenarios**:

1. **Given** the six brainstorm capabilities (shader pipelines and asset management, animation and time parameters,
   render targets and framebuffers, procedural textures and geometry, presets and adjustable parameters, touch
   interaction and gestures), **When** the matrix is read, **Then** each has a row with the status `available`,
   `requires adaptation` or `upstream gap`, evidence (file, symbol, product) and an example consumer.
2. **Given** the matrix, **When** the citation check runs, **Then** every cited file and symbol resolves. A renamed or
   removed symbol fails the check and is named.

---

### User Story 2 - Inventory of the host, thread, build and regression baseline (Priority: P1)

The implementer knows exactly how VisualCore renders and how it is built and tested: the EGL host and its thread, the
shader and resource APIs, the Xcode/XcodeGen build steps, which sources own what, and which ProjectM regression tests
protect the shared seam.

**Why this priority**: Without this, later phases risk creating a second GL lifecycle or breaking the reference.

**Independent Test**: Read the inventory. Each listed build or test command is executed once in this phase, and its
recorded result matches.

**Acceptance Scenarios**:

1. **Given** the inventory, **When** read, **Then** it names the render host entry point, its thread rule (main
   thread), context-loss behavior, the resource registry and its budgets, shader loading with diagnostics, and the
   effect graph, each with file references.
2. **Given** the listed ProjectM regression steps, **When** they are run, **Then** they pass, and their results are
   recorded as this phase's baseline.

---

### User Story 3 - Compilable empty app shell (Priority: P1)

An empty Generative Art Studio app builds and launches on the simulator before any custom graphics exist. It proves the
target, bundle identity and package wiring.

**Why this priority**: The manual's second acceptance gate.

**Independent Test**: Build for both simulator runtimes and run a smoke UI test that finds the app's title.

**Acceptance Scenarios**:

1. **Given** the shell, **When** built for the iOS 27.2 and 26.5 simulators, **Then** it compiles without signing and
   launches to a titled home screen with a spoken label.
2. **Given** the shell, **When** its dependencies are audited, **Then** it links no ProjectM engine, preset or
   bridge module.

---

### User Story 4 - Gap register and stop/go decision (Priority: P2)

The owner reads a written stop/go decision. It lists everything missing upstream and where each missing piece will
be built: a named VisualCore module for reusable work, or the app for product-only work. It also lists the phase that
builds it.

**Why this priority**: The manual's third acceptance gate. It also applies the owner's reuse rule before any app
code is written.

**Independent Test**: Every `upstream gap` or `requires adaptation` row in the matrix has a register entry with an
owner module, a phase and a test intent. The decision states go or stop with reasons.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** read, **Then** every gap names an owning VisualCore module (existing or new)
   or justifies keeping it app-local, and names the phase (01–06) that closes it.
2. **Given** a missing capability that would require a second renderer or a VisualCore fork, **When** the decision is
   made, **Then** it is recorded as a blocker (stop), never worked around.

### Edge Cases

- A capability exists only inside the ProjectM reference: it counts as unavailable to the app. The app may not link
  it, so the register lists it as a gap.
- A VisualCore placeholder module (audio, persistence, UI, test support) only *appears* to provide a capability. It is
  classified `upstream gap`, not `available`.
- A citation that points to test code only: evidence must include a public, non-test symbol. A test may serve as the
  example consumer.
- The reference build or its regression fails: the phase is blocked and recorded, never waived.
- A performance figure from a simulator or host run: may be cited as context only, never as a device or budget claim.
- A matrix row with no consumer anywhere in the repository: classified `requires adaptation` until an example
  exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-001**: The phase MUST produce a read-only repository inventory that lists VisualCore package products and
  their modules, the render host entry point and thread rule, shader and resource APIs, the effect graph, build
  steps (XcodeGen specs, schemes, scripts) and the source ownership of each area. Each entry cites a file path.
- **FR-A01-002**: The phase MUST produce an integration matrix covering the six brainstorm capabilities plus the
  version 0.1 needs:
  - seeded reproducibility;
  - versioned local documents;
  - offscreen still export with color space;
  - pause, time scrubbing and reduced motion.

  Each row has the status `available` / `requires adaptation` / `upstream gap`, the evidence (file, public symbol,
  package product) and an example consumer.
- **FR-A01-003**: Matrix citations MUST be machine-checked by an app-neutral contract checker. Every cited file must
  exist and every cited symbol must be declared in it. A failure names the row and the citation.
- **FR-A01-004**: The phase MUST record the baseline ProjectM regression with the commands run and their results:
  the reference engine build and app build, its renderer tests on both simulator runtimes, the read-only check, and
  the ProjectMReference harness tests on both runtimes.
- **FR-A01-005**: The phase MUST create a compilable, empty app shell under `Apps/GenerativeArtStudio/` with bundle
  identity `dev.visualcore.GenerativeArtStudio`. It builds unsigned for both simulator runtimes, shows a titled
  home screen with an accessibility label, and passes a launch smoke test. The shell requests no permissions and declares no usage descriptions or networking.
- **FR-A01-006**: The shell MUST NOT link ProjectM engine, preset or bridge modules. The existing dependency audit
  MUST cover the new target.
- **FR-A01-007**: The phase MUST NOT modify any VisualCore package source, the ProjectM reference or its pins. This is
  verified by a diff check of those paths for this phase's commits.
- **FR-A01-008**: The phase MUST produce a gap register. Each `requires adaptation` or `upstream gap` entry names:
  - the owning VisualCore module (existing or proposed), or a justification for keeping it app-local;
  - the phase (01–06) that closes it;
  - the test that will prove it.

  Reusable work is assigned to VisualCore by default (constitution Principle II, "Maximize reuse").
- **FR-A01-009**: The phase MUST record a stop/go decision with reasons. Anything that would need a second renderer, a
  fork of VisualCore or ProjectM, private APIs or networking is a stop condition, recorded as such.
- **FR-A01-010**: The phase MUST record traceability from the brainstorm concept and the version 0.1 features (01–06)
  and journeys (1–3) to matrix rows and planned phases. Each feature and journey maps to at least one phase.
- **FR-A01-011**: The phase MUST record negative requirements for the app, each with the source that forbids it:
  - no user-authored GLSL in the MVP;
  - no accounts, cloud sharing or subscriptions;
  - no timeline or multi-pass user graphs;
  - no networking;
  - no ProjectM linkage;
  - no second EGL path;
  - no device-performance claims before campaign II.

### Key Entities

- **Inventory entry**: area, description, file path(s), owner (package/module or script), notes.
- **Matrix row**: capability, source (brainstorm or v0.1 feature), status, evidence (file, symbol, product), example
  consumer, notes.
- **Gap entry**: capability, gap type (adaptation or upstream), owning module (VisualCore module or app-local with
  justification), closing phase, test intent.
- **Decision record**: go/stop, date, blockers, assumptions, evidence links.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-001**: 100% of matrix citations resolve in the automated check, with 0 unresolved.
- **SC-A01-002**: 10 of 10 capability rows (6 brainstorm plus 4 version-0.1 needs) carry a status, evidence and an
  example consumer.
- **SC-A01-003**: The empty app shell builds and passes its launch smoke test on both simulator runtimes (2 of 2).
- **SC-A01-004**: The baseline ProjectM regression passes all its recorded steps, with 0 failures.
- **SC-A01-005**: 100% of gaps name an owner and a closing phase, and reusable gaps are assigned to a VisualCore module.
- **SC-A01-006**: 0 changes to VisualCore package sources or the ProjectM reference in this phase's commits.
- **SC-A01-007**: 6 of 6 version-0.1 features and 3 of 3 journeys trace to at least one phase.

## Assumptions

- The repository's existing VisualCore packages, Showcase and harnesses (features 001–010, gate F09 sealed) are the
  audited baseline; the reference stays pinned at `d93edd1`.
- The app shell may use existing VisualCore products only as dependencies; no VisualCore code is written in Phase 00.
- Simulator runtimes iOS 27.2 and 26.5 are available; device evidence is out of scope until campaign II.
- The manual's separate-repository layout is replaced by the monorepo layout `Apps/GenerativeArtStudio/` (CLAUDE.md §4);
  its file names guide later phases.
