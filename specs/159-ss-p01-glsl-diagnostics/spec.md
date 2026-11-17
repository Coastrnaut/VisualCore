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

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Program compiles:**
  - `ResourceRegistry.program(vertex:fragment:defines:library:vertexName:fragmentName:)` expands the fragment text
    with the given `ShaderLibrary`, compiles it and links it. It throws `ShaderError.source`, `.compile` or `.link`,
    the last two with `[ShaderDiagnostic]`.
  - `InfoLogParser` maps each log line through the expansion's origins, so an error inside an included file carries
    that file's name and line. Diagnostics have no column.
- **Expansion:**
  - `ShaderLibrary` (VisualCoreShaderSource, pure) refuses a `#version` other than `#version 300 es`, and any
    `#version` inside an include.
  - It inserts the version line itself and adds no precision line. Its expansion is at most 64 KiB, with includes at
    most 8 deep.
  - `ShaderBundle.visualCoreLibrary` (VisualCoreRendering) holds the `vc/` include texts.
- **Full-screen drawing:** `FullScreenShaderScene.vertexSource` provides `out vec2 v_uv` (0…1, origin bottom-left).
- **Uniform declarations:** `ParameterDefinition` (VisualCoreParameters, pure) takes a name matching
  `^[a-zA-Z][a-zA-Z0-9_]{0,31}$`, a finite range with min < max and a default inside it, so a GLSL uniform name such as
  `u_speed` is a valid parameter name.
- **Package layout:** a pending core is `<Name>Core` with `<Name>CoreTests` and no experience target (the pending-core
  allowance of `scripts/check_experience_packages.py`). Its tests may depend on VisualCoreRendering to draw off screen,
  as Aurora's did.

- Q: How is the person's source placed into the template, so that lines map back? → A: Three named files in one
  `ShaderLibrary`, with the `vc/` includes added:
  - `ss/prelude.glsl`: `precision highp float;`, `in vec2 v_uv;`, `uniform float u_time;`, `uniform vec2
    u_resolution;`, `out vec4 fragColor;`, and `#include "vc/noise.glsl"` and `#include "vc/color.glsl"`;
  - `ss/shader.frag`: the person's source, unchanged;
  - `ss/main.frag`: the entry, `#include "ss/prelude.glsl"` and then `#include "ss/shader.frag"`.

  A diagnostic in the person's code then names `ss/shader.frag` and the authored line; one in the prelude or in a
  `vc/` file names that file. The core builds the three texts and the mapping rule. It does not expand or compile:
  the caller adds `ShaderBundle.visualCoreLibrary`. The person's source must not contain `#version`, `precision`
  redeclarations are allowed, and the person writes `void main()` with `fragColor`.
- Q: What are the limits, and which uniforms exist in 0.1? → A:
  - **Limits** (`ShaderLimits`, documented, under the 64 KiB ceiling): at most 16,384 bytes of source and 400 lines;
    at most 16 uniforms; at most 2 texture inputs, which are declared but bound only from A22-P03.
  - **Uniforms:** float uniforms only (a `ParameterDefinition` each). The prelude's `u_time` and `u_resolution` are
    reserved names.
  - **Validator:** it also refuses:
    - a source without `void main`;
    - any `#version` line;
    - a declared uniform missing from the source (matched as `uniform float <name>;`);
    - a source `uniform float` that the project does not declare (reported by name);
    - a reserved name;
    - a duplicate name.
- Q: What is the project file? → A:
  - **Envelope:** `ShaderProject` is a versioned envelope, kind `a22.shader-project`, schema 1, at most 65,536 bytes
    encoded, holding the name (1 to 40 characters), the source, the uniforms and the limits.
  - **Refusal codes:** `damaged`, `newer-version`, `too-large`, `not-finite` and `out-of-range` (a uniform's default
    outside its range, a reversed range, or a limit above the hard ceiling).
  - **Round trip:** encoding is canonical (sorted keys), so a round trip is byte-identical.
- Q: Which syntax tokens does the editor model produce? → A: Kinds, in order of matching:
  - comment (`//` to the end of the line, `/* … */` across lines, and an unclosed one to the end of the source);
  - preprocessor (a line starting with `#`);
  - number (integers, floats, exponents and the `u` suffix);
  - keyword (GLSL ES 3.00 control and qualifier words);
  - type (`float`, `vec2` … `mat4`, `sampler2D`, `bool`, `int`, `uint`, `void`);
  - built-in function (`sin`, `mix`, `smoothstep` and the other GLSL ES 3.00 functions) or built-in variable
    (`gl_FragCoord`);
  - identifier, operator or punctuation, whitespace.

  Lines are split on `\n`, `\r\n` or `\r` and numbered from 1; tokens never span a line in the model (a block
  comment is cut at line ends). Diagnostics attach to lines of `ss/shader.frag`; any other file's diagnostics are
  "outside the source" and listed above it.
- Q: Which templates ship, and how is "compiles" proved? → A: Three, written in code with a licence record each:
  - `gradient` (`v_uv` and `u_time`; uniform `u_speed`);
  - `noise-flow` (`vc_fbm` from `vc/noise.glsl`; uniforms `u_scale` and `u_speed`);
  - `rings` (concentric rings; uniforms `u_count` and `u_width`).

  The core's tests compile each through `ResourceRegistry.program` with `FullScreenShaderScene.vertexSource`, draw one
  frame off screen and compare the active uniforms with the declared ones. The regression fixtures (one broken
  shader per error class: an unknown identifier, a type mismatch, a missing semicolon, an error in a `vc/`-using line,
  and an error after a multi-line block comment) are compiled the same way.

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
