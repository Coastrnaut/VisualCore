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

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Programs:** `FieldPass(registry:fragment:inputs:label:library:)` compiles a fragment program with
  `FullScreenShaderScene.vertexSource`, which gives `in vec2 v_uv` at texel centres when output and input sizes match;
  inputs are `sampler2D` uniforms bound in order; uniforms are `FieldUniform` float, vec2, vec4 and int.
- **Test-image upload:** `RenderTarget.upload(rgbaFloats:)` stores each value of an `.rgba8` target as n/255 after
  clamping, so a picture made of n/255 values uploads exactly; `RenderTarget.readPixels()` reads the RGBA bytes back
  (rows bottom-up).
- **Host:** `RenderHost(scene:)` runs a `RenderScene` off screen; `ResourceRegistry.stats` gives `liveCount` per kind
  and `totalBytes` (as the A24-P01 host-count test uses).
- **Fingerprint and migration:** `DigestBuilder(domain:)` and `MigrationChain(currentVersion:steps:)`, as in A24-P01.
- **Package layout:** a pending core `EffectsComposerCore` with `EffectsComposerCoreTests`, no experience target; the
  tests may depend on VisualCoreRendering.

- Q: What are the five effects and their formulas? → A: Version 1 of each, on stored values x in 0…1 at texture
  coordinate uv, sampling with clamp to edge; every result is clamped to 0…1:

  | Id | Parameters (range; default) | Formula |
  |---|---|---|
  | `grade` | `exposure` (−2…2; 0), `contrast` (0.5…2; 1), `saturation` (0…2; 1) | y = x·2^exposure; y = (y − 0.5)·contrast + 0.5; L = 0.2126 r + 0.7152 g + 0.0722 b of y; y = L + (y − L)·saturation |
  | `blur` | `radius` (0…8 whole pixels; 2) | the mean of the (2·radius + 1)² texel centres around the pixel |
  | `distort` | `amplitude` (0…0.05 of the size; 0.01), `frequency` (1…16 cycles; 4) | sample at uv + amplitude·(sin(2π·frequency·uv.y), sin(2π·frequency·uv.x)) |
  | `vignette` | `amount` (0…1; 0.5), `radius` (0.2…1; 0.75), `softness` (0.05…1; 0.3) | d = 2·‖uv − 0.5‖/√2; rgb·(1 − amount·smoothstep(radius − softness, radius, d)) |
  | `posterize` | `levels` (2…32 whole; 8) | y = floor(x·(levels − 1) + 0.5)/(levels − 1) |

  Alpha is kept. The values of a node are a dictionary from parameter name to a finite number; whole-number
  parameters refuse fractions. Each definition's fingerprint is a `DigestBuilder` in the domain `a25.effect.v1` over
  the id, the version and every parameter's name, range and default.
- Q: What are the chain's caps and its edit history? → A: At most 8 nodes; node identifiers are whole numbers 1…65,535,
  unique in a chain, and a new node takes the smallest unused one. The edits are add (an effect at a position, with
  its defaults), remove, move (from, to), set enabled and set a value. Each validated edit is pushed on the undo stack;
  undo applies its inverse and pushes it on the redo stack; any new edit clears the redo stack. The history keeps at
  most 64 edits and drops the oldest. The chain's fingerprint is a `DigestBuilder` in the domain
  `a25.effect-chain.v1` over the nodes in order (identifier, effect id and version, enabled, values in name order).
- Q: How is a chain stored? → A: The envelope `{"body", "kind": "a25.effect-chain", "version": 1}` with the body
  `{"nodes": [{"id", "effect", "enabled", "values"}]}`, sorted keys, at most 65,536 bytes, read through a
  `MigrationChain`. Refusal codes: `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range` (with the
  field), `unknown-effect`, `unknown-parameter`, `missing-parameter`, `too-many-nodes` and `duplicate-node`.
- Q: What is the test image, and how are pictures compared? → A: A 64 × 64 picture made in code: red rises with x,
  green with y (each n/255 with n = ⌊255·i/63⌋), blue 255 on 8 × 8 checker squares and 0 elsewhere, alpha 255. Each
  effect's program is drawn into an `.rgba8` target of the same size inside a `RenderHost` scene and read back. A
  checked pixel matches its CPU reference when every channel differs by at most 2/255 (`grade`, `blur`, `vignette`,
  `posterize`) or 4/255 (`distort`, which samples between texel centres); `posterize` is checked away from level
  edges. The order fixture draws `grade` (contrast 2) then `posterize` (4 levels) and the reverse; the pictures
  differ, and the picture after the swap is undone equals the first byte for byte.
- Q: How is "no graphics work in the core" proved? → A: As in A24-P01: a test runs a scene on `RenderHost` and, inside
  its callbacks, validates every definition, edits and undoes a chain and encodes it, then compares
  `ResourceRegistry.stats` before and after; they are equal. The core target depends only on the pure
  VisualCoreExperience and VisualCorePersistence products; programs are strings in the core, compiled only by tests
  and later by the experience.

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
