# Feature Specification: Phase 1 — Architecture Constitution and Integration Contracts

**Feature Branch**: `002-architecture-contracts` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F01 (sealed before this rework, ADR-0004) · ID namespace FR-F1##, SC-F1##, T-F1##

**Input**: User description: archived `sources/README.md` §10.3 Phase 1 prompt (verbatim in the
invocation), with the canonical override: the Phase 0 audit documents are the source of truth;
ADR-0002, ADR-0003 and constitution v1.1.0 are validated and corrected, not duplicated.

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), recommended option chosen.

- Q: Which thread owns the EGL context that renders the visible frame? → A: The main thread, as in the audited reference (`ANGLERenderer` is `@MainActor`). Any secondary context (e.g. warm-up) lives on its own dedicated thread, is unshared, and is created and destroyed on that thread; GPU objects never cross contexts.
- Q: How stable is the public API before the first release? → A: Each package follows semantic versioning starting at 0.x. Until the F09 stabilization gate, breaking changes are allowed only with an ADR and a migration note; from 1.0, breaking changes require a MAJOR bump.
- Q: How many packages does the audit justify? → A: Two SwiftPM packages, each with one product per module (ADR-0003). The pure, host-testable `VisualCore` package holds math, simulation, scenes, shader source, effect-graph model, diagnostics, audio DSP, persistence and test support. The iOS-only `VisualCoreRendering` package holds the EGL/GL shims, render host, resources, GPU effects, SwiftUI view, audio engine bridge and automation. The split is forced by the iOS-only ANGLE binary targets (audit: XCFramework slices are iOS device and simulator only). The ten-package README §4 layout maps onto these modules.
- Q: How do apps observe lifecycle transitions? → A: Synchronously on the main thread through an observer callback `(old, new, generation)`, plus a bounded transition history for tests and diagnostics. Rejected transitions are recorded, not thrown.
- Q: How is the dependency direction enforced in this phase? → A: `scripts/check_dependencies.py` inspects package manifests, `project.yml` dependencies and Swift/C imports, and fails on ProjectM modules outside the reference harness, package cycles, or shared code importing app targets. A built-binary symbol scan is added in F09.

## User Scenarios & Testing *(mandatory)*

Users: the engineers of VisualCore, the ProjectM reference adapter and the 25 suite apps. Each
needs written, enforceable contracts before writing renderer code.

### User Story 1 - Enforceable package ownership and dependency direction (Priority: P1)

An engineer adding code knows which package owns it, what it may depend on, and that a checker
rejects violations (ProjectM types in VisualCore, cycles, app-to-shared imports).

**Why this priority**: Wrong boundaries are the most expensive mistake to undo across 25 apps.

**Independent Test**: Introduce a forbidden import in a scratch copy; the dependency checker fails
and names the rule.

**Acceptance Scenarios**:

1. **Given** the package map, **When** a module imports a reference ProjectM module outside the
   reference harness, **Then** the checker fails citing the rule.
2. **Given** two packages, **When** a dependency cycle is introduced, **Then** the checker fails.
3. **Given** every proposed package, **When** its justification is traced, **Then** it cites a Phase 0
   audit finding or gap (no unsupported boundaries).

---

### User Story 2 - Lifecycle, threading and resource contracts (Priority: P1)

An engineer implementing the render host or a scene follows one contract that defines lifecycle
states and transitions, the owning thread, context generations, and who creates and destroys each
GPU resource and when.

**Why this priority**: F02/F03 code is written against these contracts.

**Independent Test**: The lifecycle transition table is executable as a host test (allowed and
rejected transitions), and every reference behavior in the Phase 0 trace maps to a contract clause.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the reference trace's surface-recreation and teardown order are
   compared, **Then** each step has a matching contract clause or a documented intentional difference.
2. **Given** a resource created in context generation N, **When** used after recreation to N+1,
   **Then** the contract says it is rejected and counted.

---

### User Story 3 - Shader, diagnostics, error and logging contracts (Priority: P2)

An engineer knows how shader sources are organized, how compile errors are reported with original
file/line, which errors are recoverable, and how diagnostics and logs are structured, privacy-safe
and testable.

**Independent Test**: The contracts list every error category with its recovery behavior and every
diagnostic field with its unit.

**Acceptance Scenarios**:

1. **Given** a shader compile error, **When** reported, **Then** the contract defines the fields
   (file, line, message, stage) and that the previous working program stays active.

---

### User Story 4 - ProjectM adapter, submodule policy and regression requirements (Priority: P2)

The owner and engineers know what the reference adapter may do, how the submodule pin may change
(never silently; owner-approved ADR), and which regression checks must pass when a shared seam
changes.

**Independent Test**: The policy names the exact regression command set from the Phase 0 baseline.

**Acceptance Scenarios**:

1. **Given** a change to the render host, **When** it is committed, **Then** the policy requires
   rerunning the reference baseline renderer tests and the adapter harness.
2. **Given** a proposed pin update, **When** it is not owner-approved, **Then** policy forbids it.

---

### User Story 5 - Independent second-app usability (Priority: P3)

A second app can depend on VisualCore without any ProjectM module, proven by a contract-level
public API list that contains no ProjectM types.

**Independent Test**: The public API inventory and package manifests contain no ProjectM module or type.

### Edge Cases

- An audit finding is *unknown* (U-F001 context loss, U-F002 memory pressure, U-F003 GPU memory):
  contracts state the intended behavior and the gate that verifies it.
- A contract conflicts with the reference behavior: the difference is explicit, with a reason.
- The reference changes upstream: no effect until an owner-approved pin change; contracts cite the
  pinned commit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F101**: The architecture MUST define each package, its owner responsibility, public/internal
  surface and allowed dependencies, each traced to a Phase 0 audit finding or gap.
- **FR-F102**: The dependency direction MUST be apps/Showcase → VisualCore UI/effects/rendering →
  pure VisualCore modules → ANGLE binaries, with the reference harness the only consumer of ProjectM
  modules; no cycles; shared packages never import app targets.
- **FR-F103**: A public-versus-internal API policy MUST define what is public, how it is versioned,
  and that ProjectM/MilkDrop types never appear in public API.
- **FR-F104**: The rendering lifecycle contract MUST define states, allowed transitions, observers,
  context generations, the owning thread, frame pacing caps and the teardown order, reconciled with
  the Phase 0 trace.
- **FR-F105**: The resource contract MUST define ownership, creation, cleanup, budgets, leak
  counters and stale-generation rejection for textures, buffers, framebuffers and programs.
- **FR-F106**: The shader contract MUST define source organization, include rules and limits,
  diagnostics fields with original file/line, caching and failure behavior.
- **FR-F107**: The error and logging contract MUST define error categories, recoverability,
  structured diagnostic fields with units, and privacy rules (no user content or identifiers in logs).
- **FR-F108**: Test boundaries MUST state which modules are host-tested, which simulator-tested,
  and which require physical devices (campaign II only).
- **FR-F109**: The ProjectM adapter contract MUST define its responsibilities (drive the unmodified
  engine through the VisualCore host, harness-only) and prohibitions.
- **FR-F110**: The submodule policy MUST state pin ownership, update procedure (owner-approved ADR,
  upstream-ready patches, patch log) and the read-only rule, consistent with constitution II/II-a.
- **FR-F111**: Compatibility and regression requirements MUST name the exact regression checks
  (Phase 0 baseline renderer tests on iOS 27.2 and 26.5, adapter harness) and when they rerun.
- **FR-F112**: A dependency checker (`scripts/check_dependencies.py`) MUST mechanically enforce
  FR-F102 on package manifests, `project.yml` dependencies and Swift/C imports; built-binary symbol
  scans follow in F09.
- **FR-F114**: The visible render context MUST be owned by the main thread; secondary contexts MUST be
  unshared and confined to their own dedicated thread for their whole life.
- **FR-F115**: Public API MUST follow per-package semantic versioning from 0.x; breaking changes
  before 1.0 (F09) need an ADR and migration note.
- **FR-F113**: Existing ADR-0002/ADR-0003 MUST be validated against the audit and corrected where
  they diverge.

### Key Entities

- **Package**: name, platform, responsibility, public products, allowed dependencies, audit trace, version (0.x until F09).
- **Contract clause**: id, subject, rule, rationale, verifying gate/test.
- **Error category**: name, recoverable?, user-visible behavior, diagnostic fields.
- **Regression check**: command, trigger, expected result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F101**: 100% of packages trace to at least one Phase 0 audit finding or gap item.
- **SC-F102**: The dependency checker rejects 100% of seeded violations (ProjectM import, cycle,
  app import from shared package) and passes on the clean repository.
- **SC-F103**: 100% of reference trace stages (startup, EGL setup, presentation, scheduling,
  threading, resize, teardown, recreation) map to a lifecycle contract clause or documented difference.
- **SC-F104**: Every unknown U-F001..U-F003 has an intended behavior and verifying gate.
- **SC-F105**: Zero ownership ambiguities remain between VisualCore and ProjectM (archived Phase 1 exit gate).

## Assumptions

- Phase 0 outputs (feature 001) are complete and converged.
- Contracts are documents plus an executable checker; renderer code starts in F02.
- The ProjectM reference adapter lives under `Harnesses/` with its own project spec.
