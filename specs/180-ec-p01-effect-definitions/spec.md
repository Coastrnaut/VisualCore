# Feature Specification: Effects Composer — Phase 01 Effect definitions and render contracts

**Feature Branch**: `180-ec-p01-effect-definitions` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P01 (legacy ledger) · ID namespace FR-A25-1##, SC-A25-1##, T-A25-1##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: a linear chain editor with five built-in effects and bounded parameters. Here it is the chain itself, as pure
    data with its editing operations and the five effect definitions; the chain is drawn as a preview in A25-P02 and
    edited through an interface in A25-P03;
  - regression fixture: the order of the effects changes the output, and the change can be undone precisely;
  - graphics context ownership stays solely in the audited VisualCore host: the core issues no graphics call, and the
    effects' programs are compiled and drawn only inside the host's scene callbacks.
- **Gaps built here:** G-MODEL and G-EFFECTS of `docs/apps/effects-composer/visualcore-contract.json`, as a pending core
  in `Packages/ExperiencesCreative/EffectsComposer/Core` until A25-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/173-gbl-p01-measurement-statistics`.
- **Visuals are code:** the built-in test image and every effect are generated in code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Five effects with bounded parameters (Priority: P1) 🎯

An engineer reads the five built-in effects, each with a stable identifier, a version, its named parameters with
ranges and defaults, and a picture-level description, so a chain built from them is always valid and every value a
person can set is bounded.

**Why this priority**: the manual's MVP is built from these five effects.

**Independent Test**: list the five effects; validate each default; give a value outside a range and see it refused.

**Acceptance Scenarios**:

1. **Given** the five effects, **When** their definitions are read, **Then** each has finite parameter ranges with the
   default inside.
2. **Given** a parameter value outside its range, not finite, or for an unknown parameter, **When** validated, **Then**
   it is refused naming the effect and the parameter.

---

### User Story 2 - A chain that can be edited and undone exactly (Priority: P1)

An engineer builds a chain of effects (add, remove, move, enable or disable, set a parameter). Every edit can be undone
and redone, and undoing returns exactly the earlier chain, so a person never loses a look by experimenting.

**Why this priority**: the manual's regression fixture.

**Independent Test**: apply a sequence of edits, undo them all, and compare with the starting chain.

**Acceptance Scenarios**:

1. **Given** a chain, **When** two effects are swapped and the swap is undone, **Then** the chain equals the original,
   with the same fingerprint.
2. **Given** an edit that would break a cap (one effect too many, a value out of range), **When** applied, **Then** it
   is refused with a reason and the chain and its history are unchanged.

---

### User Story 3 - The order of the effects changes the picture (Priority: P1)

A reviewer applies two effects in both orders to the built-in test image and sees different pictures, and after the
order is undone the picture is byte-identical to the first one.

**Why this priority**: the regression fixture's second half and the render contract.

**Independent Test**: draw the test image through two effects in both orders inside the host; compare the read-backs.

**Acceptance Scenarios**:

1. **Given** the test image and two effects, **When** drawn in both orders, **Then** the two pictures differ.
2. **Given** the swap is undone, **When** drawn again, **Then** the picture equals the first byte for byte.

---

### User Story 4 - Each effect draws what its description says (Priority: P2)

A reviewer draws the test image through each effect inside the host and compares chosen pixels with a reference
computed on the CPU, so each effect's program matches its definition.

**Independent Test**: compile each effect's program inside the host, draw, read back and compare with the reference
within a stated tolerance.

**Acceptance Scenarios**:

1. **Given** each of the five effects at its defaults and at a non-default value, **When** drawn, **Then** every
   checked pixel matches the CPU reference within the tolerance.

---

### User Story 5 - A chain is stored as a versioned file (Priority: P2)

A chain encodes to a versioned file and decodes back unchanged; a damaged, newer, oversized or invalid file is refused
with a code and never partly read.

**Independent Test**: round-trip chains; feed damaged, newer, oversized and out-of-range files.

**Acceptance Scenarios**:

1. **Given** a valid chain, **When** encoded and decoded, **Then** it is equal and the bytes are identical on a second
   encoding.
2. **Given** a file of a newer version or with a value out of range, **When** decoded, **Then** it is refused with a
   code.

### Edge Cases

- **An empty chain:** valid; it draws the source unchanged.
- **A chain at the length cap:** valid; one more effect is refused.
- **All effects disabled:** valid; it draws the source unchanged.
- **The same effect twice:** allowed, each with its own identifier and values.
- **Undo with nothing to undo, or redo after a new edit:** refused without change.
- **A history at its depth cap:** the oldest step is dropped, stated by the history.
- **A parameter at exactly its minimum or maximum:** valid.
- **Effects that commute for some values (for example two disabled effects):** the order test uses values that do not.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-101**: The core MUST define five built-in effects, each with a stable identifier, a version, named
  parameters with finite ranges and defaults inside them, and a fingerprint over the definition.
- **FR-A25-102**: A chain MUST be an ordered list of effect nodes (identifier, effect, enabled, values) with a length
  cap, unique node identifiers and every value inside its range; validation MUST refuse anything else, naming the field.
- **FR-A25-103**: Edits (add, remove, move, enable or disable, set a value) MUST be validated before they apply; an
  edit history MUST undo and redo them exactly, with a bounded depth.
- **FR-A25-104**: Each effect MUST have a fragment program generated in code and a CPU reference of the same formula;
  drawn inside the host, chosen pixels MUST match the reference within a stated tolerance.
- **FR-A25-105**: Drawing two effects in both orders MUST give different pictures, and undoing the order MUST give a
  byte-identical picture.
- **FR-A25-106**: A chain MUST encode to a versioned file and decode back unchanged; damaged, newer, oversized,
  non-finite and out-of-range files MUST be refused with a code.
- **FR-A25-107**: The core MUST create no graphics resource; programs are compiled and drawn only inside the host's
  scene callbacks.
- **FR-A25-108**: Every public name MUST carry documentation; the contract's G-MODEL and G-EFFECTS MUST be closed with
  evidence.

### Key Entities

- **Effect definition**: identifier, version, title, parameters (name, range, default), fingerprint.
- **Effect node**: node identifier, effect, enabled, values.
- **Effect chain**: ordered nodes, length cap, fingerprint, file version.
- **Edit and history**: the edit kinds, undo and redo stacks with a depth cap.
- **Test image**: a picture generated in code at a fixed size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-101**: 100% of the five effects validate at their defaults, and 100% of out-of-range values tried are
  refused.
- **SC-A25-102**: Undoing every edit of a recorded sequence returns the starting chain exactly (equal and the same
  fingerprint).
- **SC-A25-103**: Two effects in both orders give different pictures; undoing gives a byte-identical picture.
- **SC-A25-104**: Every checked pixel of every effect matches its CPU reference within the stated tolerance.
- **SC-A25-105**: Chains round-trip byte-identically; 100% of the damaged, newer, oversized and invalid files tried are
  refused with a code.
- **SC-A25-106**: The host's live resource counts and bytes are unchanged after the core runs inside a scene; each test
  finishes in under 10 seconds.

## Assumptions

- The pending-core layout of A24-P01 applies: `EffectsComposerCore` and `EffectsComposerCoreTests`, with no experience
  target yet; the tests may use VisualCoreRendering to draw inside the host.
- The effects work on stored (sRGB-encoded) values in this phase; linear-light boundaries are G-COLOR (A25-P05).
- The test image is small and generated in code; imported images are A25-P03.

## Traceability

| Source | Requirement |
|---|---|
| MVP: linear chain editor with five built-in effects and bounded parameters | FR-A25-101, 102, 103 |
| Regression fixture: effect order changes output and can be undone precisely | FR-A25-103, 105 |
| EGL/context ownership solely in the VisualCore host | FR-A25-104, 107 |
| Brainstorm: shader library, effect parameters, preset serialization | FR-A25-101, 104, 106 |
| Contract G-MODEL, G-EFFECTS | FR-A25-101–108 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface; no bundled image; no import or
  export; no user-written code; no graphics call in the core.
