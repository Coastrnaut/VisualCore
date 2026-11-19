# Feature Specification: Effects Composer — Phase 02 Linear pass compiler and preview

**Feature Branch**: `181-ec-p02-pass-compiler-preview` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P02 (legacy ledger) · ID namespace FR-A25-2##, SC-A25-2##, T-A25-2##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: editable reorder, enable and disable, and an immediate preview. Here the chain of A25-P01 is compiled into an
    ordered pass plan and drawn as a preview of the built-in test image in the one app, edited through the
    experience's actions (add, remove, move, enable or disable, set a value, undo, redo) with native controls;
  - regression fixture: a disabled effect is equivalent to the identity within tolerance;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-COMPILER, G-POOL and G-DIAG of `docs/apps/effects-composer/visualcore-contract.json`.
- **The experience arrives:** Effects Composer is drawn in the one app for the first time and registered as a
  candidate; it is not yet available to a person (that is X-A25). The synthetic candidate of the app's tests moves to
  `r02-g01.aurora-loom`.
- **Not here:** the full chain-editing interface, image import and compare (A25-P03), presets and export (A25-P04),
  colour boundaries and robustness (A25-P05).
- **No VisualCore or ProjectM change.** Follow `specs/174-gbl-p02-workload-renderers`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A chain becomes an ordered set of passes (Priority: P1) 🎯

An engineer compiles a chain into a pass plan: the enabled effects in order, each reading the previous result and
writing a new one, never the one it reads, with at most two intermediate pictures alive at once.

**Why this priority**: the compiler is the heart of the preview and of the export later.

**Independent Test**: compile empty, single, all-disabled and full chains and read their plans.

**Acceptance Scenarios**:

1. **Given** a chain with disabled effects, **When** compiled, **Then** the plan holds only the enabled effects, in
   order.
2. **Given** any plan, **When** its passes are read, **Then** no pass reads the picture it writes, each intermediate
   picture ends after its last reader, and at most two are alive at once.

---

### User Story 2 - The preview follows every edit at once (Priority: P1)

A person opens Effects Composer and sees the test image through the chain. Adding, removing, moving, enabling or
disabling an effect, changing a value, and undoing or redoing redraws the preview with the next frame.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: apply each action through the experience and draw the next frame; compare with the chain applied
on the CPU.

**Acceptance Scenarios**:

1. **Given** a chain, **When** an edit is applied and the next frame drawn, **Then** the preview equals the CPU
   reference of the edited chain within the stated tolerance.
2. **Given** an edit then its undo, **When** drawn, **Then** the preview equals the picture before the edit byte for
   byte.

---

### User Story 3 - A disabled effect changes nothing (Priority: P1)

A reviewer disables an effect and sees the same picture as without it.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: draw a chain with one effect disabled and the chain without it; compare.

**Acceptance Scenarios**:

1. **Given** a chain and the same chain with one more effect disabled, **When** both are drawn, **Then** the pictures
   are identical within the tolerance.

---

### User Story 4 - A broken effect program is reported, not fatal (Priority: P2)

When an effect's program cannot be built, the preview keeps the last good picture and names the effect and the line of
the problem.

**Independent Test**: inject a broken program for one effect and read the diagnostics and the preview.

**Acceptance Scenarios**:

1. **Given** a broken program, **When** the chain is drawn, **Then** a diagnostic names the effect and a line, and the
   preview shows the last good picture.

---

### User Story 5 - Intermediate pictures stay bounded (Priority: P2)

Repeated edits and redraws, context rebuilds and size changes leave the number and bytes of live pictures where they
were, and a request above the cap is refused with a reason.

**Independent Test**: edit and redraw many times; rebuild the context; read the resource statistics.

**Acceptance Scenarios**:

1. **Given** 50 edit-and-draw cycles and 10 context rebuilds, **When** the resource statistics are read, **Then** the
   live counts and bytes equal those after the first draw.

### Edge Cases

- **An empty or all-disabled chain:** the preview shows the test image unchanged.
- **A chain at its length cap:** draws with at most two intermediate pictures.
- **A size change during editing:** pictures are rebuilt at the new size; nothing leaks.
- **A context loss:** programs and pictures are rebuilt from the chain; the next frame matches the reference.
- **A refused edit (cap, range, nothing to undo):** the chain, history and preview stay as they were, and the reason is
  shown.
- **A restored session:** the chain comes back from the snapshot; the history starts empty.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-201**: A pure compiler MUST turn a chain into a pass plan holding only enabled effects in order, where no
  pass reads its output, each intermediate picture ends after its last reader, and at most two are alive at once; an
  empty plan draws the source unchanged.
- **FR-A25-202**: The experience MUST draw the plan as a preview of the built-in test image inside the host, with its
  intermediate pictures taken from and returned to a bounded pool.
- **FR-A25-203**: The experience MUST expose the edits of A25-P01 and undo and redo as validated actions, and the next
  frame MUST show their effect.
- **FR-A25-204**: A disabled effect MUST draw the same picture as the chain without it, within the tolerance.
- **FR-A25-205**: A program that cannot be built MUST yield a diagnostic naming the effect and a line, and the preview
  MUST keep the last good picture.
- **FR-A25-206**: Repeated edits, draws, context rebuilds and size changes MUST leave the live picture counts and bytes
  unchanged; a request above the cap MUST be refused with a reason.
- **FR-A25-207**: The experience MUST be registered as a candidate with a scenario manifest, verified by the runner on
  iOS 27.2, and stay unavailable to a person; the app tests' synthetic candidate moves to `r02-g01.aurora-loom`.
- **FR-A25-208**: Every public name MUST carry documentation; G-COMPILER, G-POOL and G-DIAG MUST be closed with
  evidence.

### Key Entities

- **Pass plan**: ordered passes (effect node, input, output), the intermediate pictures and their lifetimes.
- **Composer state**: the chain (the snapshot) and the edit history (not stored).
- **Diagnostic**: effect, line, message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-201**: 100% of compiled plans read no output they write and keep at most two intermediate pictures alive.
- **SC-A25-202**: After each of the edit kinds, the next preview matches the CPU reference within the tolerance; undo
  restores it byte for byte.
- **SC-A25-203**: A disabled effect's picture equals the picture without it within the tolerance.
- **SC-A25-204**: A broken program yields one diagnostic with the effect and a line, and the preview is unchanged.
- **SC-A25-205**: After 50 edit cycles and 10 rebuilds the live counts and bytes are unchanged.
- **SC-A25-206**: The runner passes its scenarios on iOS 27.2; each unit test finishes in under 10 seconds.

## Assumptions

- The preview source is the built-in test image generated in code; imported images are A25-P03.
- Effects keep working on stored values; linear light is A25-P05.
- The interface in this phase is native controls for the actions; the full editing interface is A25-P03.

## Traceability

| Source | Requirement |
|---|---|
| MVP: editable reorder, enable and disable, immediate preview | FR-A25-202, 203 |
| Regression fixture: disabled effect equals identity within tolerance | FR-A25-204 |
| EGL/context ownership solely in the VisualCore host | FR-A25-202, 206 |
| Brainstorm: render graph, framebuffer pipelines, shader library | FR-A25-201, 202, 205 |
| Contract G-COMPILER, G-POOL, G-DIAG | FR-A25-201–208 |

## Negative Requirements

- No VisualCore or ProjectM change; no availability to a person; no import, export or presets; no user-written code; no
  graphics call in the core.
