# Feature Specification: Graphics Benchmark Lab — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `172-gbl-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P00 (legacy ledger) · ID namespace FR-A24-0##, SC-A24-0##, T-A24-0##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Graphics Benchmark Lab (`a24.graphics-benchmark-lab`) is an experience of the VisualCore
  app, built in `Packages/ExperiencesCreative/GraphicsBenchmarkLab` (Auto-Creator.md §16 layout). It never gets a
  standalone target, bundle identifier, in-app product or store listing. The manual's gate "the app can compile an
  empty SwiftUI shell" is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A23. The contract lives in `docs/apps/graphics-benchmark-lab/`.
- **Visuals are code:** every workload scene (textured quads, shader ALU stress, particles) and every texture is
  generated in code; no purchased, generated or photographic image.
- **Constitution:** 2.20.0 adds the A24 experience rules (committed at the start of this gate, `6c0a7d35`).
- **Synthetic candidate:** the app's tests use `a24.graphics-benchmark-lab` as the synthetic not-yet-integrated id
  (since X-A23); this phase keeps it, and A24-P02 moves it on when A24 becomes a real candidate.
- Follow `specs/165-vpl-p00-boundary-audit`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Graphics Benchmark Lab gets a map of what VisualCore already provides for each capability
the experience needs (GPU timing, diagnostics, profiling, benchmark scenes, and device and configuration reporting)
and for each version 0.1 feature. Every entry has real files, declared names and package products, and is marked
available, requires adaptation, or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Graphics Benchmark Lab work, and the starting
commit is recorded, so later phases can prove what they changed upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Graphics Benchmark Lab absent.
Phase 01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Graphics Benchmark Lab is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Graphics Benchmark Lab can proceed, what is missing upstream, and which
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** drawing a bounded workload in the host's context or reading a monotonic frame
   time were missing and could not be built over the existing renderer, **Then** the decision is "stop" and names
   the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example frame times exist but no percentile statistics): marked "requires
  adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's particle system or
  export): not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **No supported GPU timer** (the manual's risk 2): the audit records whether a timer query is reachable through the
  host and, if not, that GPU time is never shown and CPU time is never labelled GPU time.
- **Thermal throttling and display refresh skewing results** (risk 1): the audit records which public signals
  (thermal state, Low Power Mode, display refresh) are reachable and where they are recorded with a result.
- **A stress run overheating the device** (risk 3): the audit records where duration caps, cool-down and an immediate
  stop are owned.
- **A result file that is damaged, newer or holds non-finite numbers:** the audit records the versioned envelope and
  refusal support and where the result format's policy is owned.
- **A context loss or resize during a run:** the audit records that the run is marked interrupted and its resources
  are rebuilt from CPU state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (programs, full-screen passes, render targets and their budget, read-back, the GLSL
  library), the frame clock and frame information, diagnostics and resource statistics, the experience host, the
  build and release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A24-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A24-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the benchmark case, run, frame sample and summary models, versioned and validated, with documented caps;
  - percentile statistics (p50, p95, p99) with warm-up excluded and sample counts;
  - the three workload scenes (textured quads, shader ALU stress, particles) with fixed, versioned configurations;
  - the run phases (warm-up, measurement, cool-down), a capped duration and an immediate stop;
  - frame-time and CPU submit-time capture from a monotonic clock;
  - a GPU timer only where supported, detected by a capability probe;
  - the device, OS, build, quality-tier and thermal-context report from public APIs only;
  - local result storage with versioned files, and refusal of damaged or newer files;
  - export as versioned JSON or CSV through a system sheet the person opens;
  - an in-app explanation of limits and variability;
  - resize, orientation and context-loss handling during a run.
- **FR-A24-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A24-005**: The one app MUST build for testing with Graphics Benchmark Lab absent. The experience package check
  MUST pass. Graphics Benchmark Lab MUST stay unregistered and unavailable; its targets come with A24-P01's first
  rules.
- **FR-A24-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking or upload, no private
    API or private hardware identifier, no CPU time labelled as GPU time, no device ranking or scientific claim, no
    invented or published benchmark number, no unbounded stress run, and no purchased, generated or photographic
    images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: thermal and
    refresh skew, GPU timer availability, and device overheating from stress runs;
  - a stop/go decision with reasons.
- **FR-A24-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A24-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A24-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A24-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A24-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (23 registered experiences, none of them A24).
- **SC-A24-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A24-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (the render host, field passes, render targets, read-back,
  the GLSL library, experience storage, versioned envelopes and the frame clock): the audit confirms each from the code
  and records what is missing.
- The workload definitions, statistics, copy and interface are app-local; generic pieces (for example a GPU timer
  query or a frame-interval recorder) are assessed for VisualCore ownership.
- Later phases (A24-P01 to A24-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A24-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A24-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A24-005, US3 |
| Review gate: written stop/go decision | FR-A24-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A24-008 |
| Brainstorm capabilities (GPU timing, diagnostics, profiling, benchmark scenes, device and configuration reporting) | FR-A24-002 |
| Manual non-goals and risks 1–3 | FR-A24-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string; no benchmark number.
