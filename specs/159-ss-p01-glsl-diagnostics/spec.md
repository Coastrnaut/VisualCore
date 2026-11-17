# Feature Specification: Shader Studio — Phase 01 GLSL/diagnostic contract and editor shell

**Feature Branch**: `159-ss-p01-glsl-diagnostics` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A22-P01 (legacy ledger) · ID namespace FR-A22-1##, SC-A22-1##, T-A22-1##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: a code editor with syntax assistance and line-numbered diagnostics. Here it is the editor's pure model:
    syntax tokens, line numbers and diagnostics by line. The editor view comes in A22-P03 and the presenter in
    A22-P02;
  - regression fixture: a compiler error's line points to the line the person wrote, proved by compiling real broken
    shaders off screen in the core's tests;
  - graphics context ownership stays solely in the audited VisualCore host (the core issues no GL call).
- **Gaps built here:** G-MODEL, G-VALIDATE, G-LINES and G-TEMPLATES of
  `docs/apps/shader-studio/visualcore-contract.json`, as a pending core in `Packages/ExperiencesCreative/ShaderStudio/
  Core` until A22-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/152-au-p01-sky-prototype`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A shader project is a small, bounded document (Priority: P1) 🎯

A person's shader project holds a name, their fragment source, the uniforms it exposes with their ranges, and the
limits it runs under. A project that is damaged, of a newer version, or holds impossible values is refused with a
reason instead of being opened half-broken.

**Why this priority**: every later phase (preview, editor, inspector, files) builds on this document.

**Independent Test**: encode and decode projects; feed damaged, newer and out-of-range samples; each is refused with
its reason.

**Acceptance Scenarios**:

1. **Given** a valid project, **When** it is encoded and decoded, **Then** it is identical.
2. **Given** a project of a newer version, a damaged file or a uniform with a non-finite or reversed range, **When**
   it is read, **Then** it is refused with a named reason and nothing is changed.

---

### User Story 2 - Too much is refused before anything compiles (Priority: P1)

Before a shader is ever handed to the graphics driver, its size, line count, uniform count and declared inputs are
checked against documented limits, so an oversized or malformed project never reaches the compiler.

**Why this priority**: the manual's risk 1 and its algorithm rule 2 (prevalidate before any compile).

**Independent Test**: validate sources at and just past each limit.

**Acceptance Scenarios**:

1. **Given** a source at each limit, **Then** it passes; **given** one just past a limit, **Then** it is refused,
   naming the limit and the value.
2. **Given** a source with no `main`, or one that declares its own version line, **Then** it is refused with a reason
   before any compile.

---

### User Story 3 - An error points to the line the person wrote (Priority: P1)

When a shader fails to compile, each error names the line the person wrote, even though the template adds its own
lines (version, precision and shared includes) before theirs.

**Why this priority**: the phase's regression fixture and the manual's algorithm rule 1.

**Independent Test**: compile broken shaders off screen and read each error's line.

**Acceptance Scenarios**:

1. **Given** a source whose line 7 has a type error, **When** it is compiled inside the template, **Then** the error
   names line 7 of the person's source.
2. **Given** an error inside a shared include, **Then** it names that include and its line, not the person's source.
3. **Given** a source that compiles, **Then** there are no diagnostics.

---

### User Story 4 - The editor's model shows lines, colours and errors (Priority: P2)

The editor's model splits the source into numbered lines and syntax tokens (keywords, types, built-ins, numbers,
comments, preprocessor lines, identifiers) and attaches each diagnostic to its line, so the view can show line numbers,
syntax colours and an error marker on the right line.

**Why this priority**: the MVP's "syntax assistance and line-numbered diagnostics" without the view.

**Independent Test**: tokenize sample sources; attach diagnostics; read lines and markers.

**Acceptance Scenarios**:

1. **Given** a source, **Then** every character belongs to exactly one token, and the tokens rebuild the source.
2. **Given** diagnostics on lines 3 and 7, **Then** lines 3 and 7 carry them, in order, and other lines carry none.

---

### User Story 5 - Starter templates compile (Priority: P2)

The experience ships a few starter templates, written in code: a gradient, a pattern from the shared noise library and
a uniform-driven shape. Each declares its uniforms with ranges and compiles cleanly.

**Why this priority**: the manual's feature 02 (templates with defined uniforms), and the person's first launch.

**Independent Test**: validate and compile every template off screen.

**Acceptance Scenarios**:

1. **Given** each template, **Then** it passes validation, compiles with no error, and its declared uniforms match
   the compiled program's active uniforms.

### Edge Cases

- **An empty source:** refused as having no `main`.
- **Windows line endings or a final line without a newline:** lines are numbered the same way as with plain newlines.
- **A very long single line:** counted against the size limit; the tokenizer stays linear in the source length.
- **An error the compiler reports with no line:** kept as a diagnostic on no line, shown above the source.
- **A comment that never closes:** tokenized as a comment to the end of the source, with no crash.
- **A uniform declared in the source but not in the project, or the reverse:** reported by name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-101**: A shader project MUST hold a version, a name, the fragment source, the declared uniforms (name,
  title, range, default) and its limits; it MUST round-trip exactly.
- **FR-A22-102**: A damaged, newer-version, oversized or non-finite project MUST be refused with a named reason and
  change nothing.
- **FR-A22-103**: The source validator MUST check the size, the line count, the uniform count and the declared inputs
  against documented limits, and refuse a source with no `main` or its own version line, before any compile.
- **FR-A22-104**: A compile error MUST name the person's file and line, after the template's inserted lines; an error
  in a shared include MUST name that include.
- **FR-A22-105**: The editor model MUST number lines, split the source into syntax tokens that rebuild it exactly, and
  attach each diagnostic to its line.
- **FR-A22-106**: At least three starter templates MUST exist, written in code, each with declared uniforms, a source
  that validates and compiles, and uniforms that match the compiled program.
- **FR-A22-107**: The core MUST be pure: no GL call, clock read, network or UI framework.

### Key Entities

- **Shader project**: version, name, fragment source, uniforms, limits.
- **Uniform declaration**: name, title, range, default.
- **Limits**: maximum source bytes, lines, uniforms and inputs.
- **Diagnostic (person's view)**: file, line, severity, message.
- **Editor line**: number, tokens, diagnostics.
- **Template**: id, title, source, uniforms, licence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-101**: 100% of valid projects round-trip exactly; 100% of refusal samples are refused with their reason.
- **SC-A22-102**: 100% of the broken-shader fixtures name the authored line (or the include) of their error.
- **SC-A22-103**: For every sample source, the tokens rebuild the source exactly and every diagnostic lands on its
  line.
- **SC-A22-104**: 100% of templates compile with no error and match their uniforms.
- **SC-A22-105**: Each test finishes in under 10 seconds.

## Assumptions

- The shared source expansion, compile-log parser, compile and link, uniform reflection and GLSL library exist in
  VisualCore (A22-P00 contract) and are reused unchanged.
- The exact limits are chosen and documented in this phase, under the expansion's hard ceiling.

## Traceability

| Source | Requirement |
|---|---|
| MVP: code editor with syntax assistance and line-numbered diagnostics | FR-A22-104, 105 |
| Regression fixture: compiler-error line mapping points to the authored line | FR-A22-104, SC-A22-102 |
| Algorithm rules 1–2 (map lines after inserted code; prevalidate before compile) | FR-A22-103, 104 |
| Version 0.1 feature 02 (templates with defined uniforms) | FR-A22-106 |
| Brainstorm: shader compilation, diagnostics and error reporting, shader asset pipeline | FR-A22-101–106 |
| Contract G-MODEL, G-VALIDATE, G-LINES, G-TEMPLATES | FR-A22-101–107 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no GL call in the
  core; no network; no sandbox claim; no artwork.
