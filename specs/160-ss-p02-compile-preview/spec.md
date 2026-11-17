# Feature Specification: Shader Studio — Phase 02 Compile and last-good-preview path

**Feature Branch**: `160-ss-p02-compile-preview` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A22-P02 (legacy ledger) · ID namespace FR-A22-2##, SC-A22-2##, T-A22-2##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: local GLSL ES fragment shader templates with defined uniforms (and texture inputs, which are declared here
    and bound in A22-P03, the contract's G-TEXTURES);
  - regression fixture: a compilation failure never replaces a working preview;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-PREVIEW and G-RUN of `docs/apps/shader-studio/visualcore-contract.json`.
- **The experience arrives:** Shader Studio is drawn in the one app for the first time and registered as a candidate;
  it is not yet available to a person (that is X-A22). The synthetic candidate of the app's tests moves to
  `a23.visual-programming-lab`.
- **No VisualCore or ProjectM change.** Follow `specs/153-au-p02-scene-controls`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start from a template and run it (Priority: P1) 🎯

A person opens Shader Studio, picks one of the starter templates and sees it running in the preview. They press Run
to compile what they have, and the preview shows the result.

**Why this priority**: the manual's journey 1 (open a starter template) and feature 03 (an explicit Compile and Run).

**Independent Test**: open the experience; pick each template; run; the preview draws it.

**Acceptance Scenarios**:

1. **Given** Shader Studio opens, **Then** the first template is shown and drawn in the preview.
2. **Given** a template is picked, **When** Run is pressed, **Then** the preview draws that template and the status
   says it compiled.

---

### User Story 2 - A broken shader never breaks the preview (Priority: P1)

When the person's shader fails to compile, the preview keeps drawing the last shader that worked, and the person sees
each error with the line they wrote. When they fix it and run again, the preview switches to the new shader.

**Why this priority**: the phase's regression fixture and manual feature 03 (last-known-good preview).

**Independent Test**: run a good shader, then a broken one, then a fixed one; read the picture and the diagnostics
after each.

**Acceptance Scenarios**:

1. **Given** a working preview, **When** a shader that fails to compile is run, **Then** the preview's picture is
   unchanged and the diagnostics name the authored lines.
2. **Given** that failure, **When** a fixed shader is run, **Then** the preview draws the new shader and the
   diagnostics are cleared.
3. **Given** a source that the validator refuses, **When** Run is pressed, **Then** nothing is compiled, the preview is
   unchanged and the refusal is shown.

---

### User Story 3 - Uniforms drive the preview (Priority: P2)

Each template's uniforms have a value within their range; changing a value changes the preview at once, without a
recompile.

**Why this priority**: the manual's journey 2 (modify a uniform and compile) and feature 04's ground work.

**Independent Test**: set a uniform to two values; the pictures differ; a value outside its range is refused.

**Acceptance Scenarios**:

1. **Given** a running template, **When** one of its uniforms is changed within its range, **Then** the picture
   changes and no compile happens.
2. **Given** a value outside the uniform's range, **Then** it is refused and nothing changes.

---

### User Story 4 - It survives the device's interruptions (Priority: P2)

After the drawing surface is rebuilt (a resize, an orientation change, a lost graphics context) the preview comes
back with the last good shader and its uniform values.

**Why this priority**: the manual's renderer-lost state and the contract's context-loss row.

**Independent Test**: rebuild the context and resize; the picture is the same shader.

**Acceptance Scenarios**:

1. **Given** a running shader, **When** the context is rebuilt or the surface resized, **Then** the same shader is
   drawn again with the same uniform values.

### Edge Cases

- **Run pressed several times before the next frame:** only one compile happens, for the newest source.
- **The first run fails** (no good shader yet): the preview shows the first template's picture until a shader works.
- **A shader that compiles but fails to link:** treated as a failure; the preview is unchanged.
- **Switching templates while a compile waits:** the waiting compile is for the newly picked template.
- **The experience is closed with a compile waiting:** nothing is compiled after it closes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-201**: The experience MUST offer the starter templates; picking one MUST make its source and uniforms the
  current ones and run it.
- **FR-A22-202**: Run MUST validate first; a refused source MUST not be compiled and MUST leave the preview unchanged.
- **FR-A22-203**: A compile MUST happen only in the drawing host's context, at its next frame, at most one per frame,
  for the newest request.
- **FR-A22-204**: A failed compile or link MUST leave the preview drawing the last good shader and MUST report every
  diagnostic with the person's line; a successful one MUST replace the preview and clear the diagnostics.
- **FR-A22-205**: Uniform values MUST be bounded by their ranges, refused outside them, and applied to the preview
  without a recompile.
- **FR-A22-206**: After a context rebuild or resize, the last good shader MUST be drawn again with the same values.
- **FR-A22-207**: Shader Studio MUST be registered as a candidate, not available, with its scenario manifest, and the
  experience's controls MUST carry spoken labels.

### Key Entities

- **Studio state**: the selected template, the uniform values, the run count (what a snapshot holds).
- **Compile request**: the source and its uniforms, the newest one only.
- **Preview status**: compiled, failed (with diagnostics), refused (with issues), waiting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-201**: In 100% of failure samples (compile, link, refused) the preview's picture before and after is
  byte-identical.
- **SC-A22-202**: 100% of failure samples report diagnostics on the authored lines; after a fix, 0 diagnostics remain.
- **SC-A22-203**: N run requests before one frame give exactly 1 compile.
- **SC-A22-204**: Every template draws in the app on the iOS 27 simulator; each test runs in under 10 seconds.

## Assumptions

- The A22-P01 core (project, validator, assembly, mapper, templates) is reused unchanged.
- The editor view comes in A22-P03; in this phase the source is the template's or set by a test seam.

## Traceability

| Source | Requirement |
|---|---|
| MVP: templates with defined uniforms (texture inputs declared) | FR-A22-201, 205 |
| Regression fixture: compilation failure never replaces a working preview | FR-A22-204, SC-A22-201 |
| Algorithm rules 3–4 (controlled preview; retain last-good program) | FR-A22-203, 204, 206 |
| Journeys 1–2 | US1, US3 |
| Contract G-PREVIEW, G-RUN | FR-A22-201–207 |

## Negative Requirements

- No VisualCore or ProjectM change; no GL call outside VisualCore's scenes; no compile from a control's action; no
  network; no sandbox claim; not available to a person before X-A22.
