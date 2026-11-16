# Feature Specification: Simulation Lab — Phase 05 Numerical validation

**Feature Branch**: `121-sl-p05-validation` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P05 (legacy ledger) · ID namespace FR-A16-5##, SC-A16-5##, T-A16-5##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: the GPU ping-pong path with explicit boundary rules (wrap for the automaton and reaction-diffusion, fixed zero
    for the wave), built in A16-P02 and A16-P03 and re-validated here;
  - regression fixture: a size change reallocates targets without carrying corrupted state;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-VALIDATION of `docs/apps/simulation-lab/visualcore-contract.json` — a generated validation
  report from short runs.
- **Device observations** wait for the device campaign (after ImplementationLock-100). The iOS 26 runtime and the
  reference regression run at X-A16 (owner ruling of 2026-11-14), so the report states which runtime produced it.
- **Release** (licenses, copy, privacy) is A16-P06 (G-RELEASE). Follow `specs/120-sl-p04-ui-presets-capture`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A validation report anyone can regenerate (Priority: P1) 🎯

A reviewer runs one command and gets a report stating, for each family, how far the graphics-processor field is from
the reference after a fixed run, what happens at and beyond the stability limits, the work per frame, the memory the
fields take and a short measurement of steps per second. Every number comes from the run, and the report names the
runtime.

**Why this priority**: the phase's deliverable (G-VALIDATION).

**Independent Test**: run the report test; read the report file; compare it with the asserted bounds.

**Acceptance Scenarios**:

1. **Given** each family, **When** the report runs, **Then** it lists the largest difference from the reference and
   the declared tolerance, and the difference is within it.
2. **Given** the stability limits, **Then** a run at each limit stays finite and a step beyond it is refused with its
   sentence.
3. **Given** a running simulation, **Then** the iterations per frame never exceed the cap, and the fields' memory is
   within the stated budget.

---

### User Story 2 - A size change starts clean (Priority: P1)

A person rotates the device or resizes the window; the simulation continues from the same state, with nothing from
the old size showing through.

**Why this priority**: the phase's regression fixture.

**Independent Test**: resize the canvas and recreate the context mid-run in each family; compare the drawn field and
the graphics-processor field with the reference.

**Acceptance Scenarios**:

1. **Given** any family mid-run, **When** the canvas size changes, **Then** the next frame's field equals the
   reference and the picture fills the new square.
2. **Given** a context recreation, **Then** every target is made new and loaded from the reference state.

### Edge Cases

- **The longest frame:** a frame after a long pause runs at most the per-frame cap of iterations.
- **Non-finite values:** none appear in any family at the stability limits; the report would count them if they did.
- **No floating-point targets:** the report states it and fails rather than reporting an 8-bit run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-501**: A validation report MUST be generated from short runs and committed, naming the runtime, and stating
  per family the largest difference from the reference with the declared tolerance.
- **FR-A16-502**: At each stability limit a run MUST stay finite; one step beyond MUST be refused with its sentence.
- **FR-A16-503**: The iterations per frame MUST never exceed the cap, and the fields' memory MUST stay within the
  stated budget; steps per second MUST be measured in a short run and reported, not asserted.
- **FR-A16-504**: A canvas size change and a context recreation MUST leave the next frame's field equal to the
  reference, with every target of a recreation made new.
- **FR-A16-505**: The boundary rule of every family MUST be asserted on the graphics-processor path (wrap or fixed
  zero).
- **FR-A16-506**: The runner's standard scenarios MUST pass on iOS 27.

### Key Entities

- **Validation report**: runtime, per-family difference and tolerance, limit results, per-frame cap, memory, steps per
  second.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-501**: 3 of 3 families are within their declared tolerance in the report.
- **SC-A16-502**: 0 non-finite cells at the limits; 2 of 2 beyond-limit steps refused.
- **SC-A16-503**: 0 frames above the per-frame cap; memory within the stated budget.
- **SC-A16-504**: After a size change and a recreation, 100 % of cells equal the reference in every family.
- **SC-A16-505**: Every test runs in under 10 s; the runner's standard scenarios pass on iOS 27.

## Assumptions

- The A16-P01 to P04 code is reused; no VisualCore change is planned. The report is produced by a test (as the
  scenario manifest is) and checked for being current.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 MVP: GPU ping-pong path with explicit boundary rules | FR-A16-505 |
| Regression fixture: size change reallocates targets without corrupted state | FR-A16-504, SC-A16-504 |
| Contract G-VALIDATION | FR-A16-501–503 |
| EGL/context ownership in the host | FR-A16-504 |

## Negative Requirements

- No device claim from simulator runs; no wall-clock assertion; no long soak or endurance run; no accuracy claim beyond
  the declared tolerances; no VisualCore change.
