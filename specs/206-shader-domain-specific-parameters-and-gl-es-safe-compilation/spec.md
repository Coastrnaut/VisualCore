# Feature Specification: R02-F06 — Shader domain-specific parameters and GL ES safe compilation

**Feature Branch**: `206-shader-domain-specific-parameters-and-gl-es-safe-compilation` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F06 (migration ledger, shared round feature) · ID namespace FR-R02F06-###, SC-R02F06-###, T-R02F06-###

**Input**: User description: the archived R02-F06 `/speckit-specify` prompt (round2.md), verbatim in the invocation, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation`;
  FR-R02F06-###, SC-R02F06-###, T-R02F06-###.
- **Section 13 disposition: extend.** The framework already expands shader sources with includes and defines and maps
  every expanded line back to its file (`ShaderLibrary`), caches programs by a hash of the expanded text
  (`ShaderCacheKey`, 64 programs, eviction retires), parses compiler logs into file-and-line diagnostics
  (`InfoLogParser`), reflects a program's active uniforms with typed setters (`ShaderProgram`), reports the device's
  shader precision (`RenderCapabilities`), and declares named parameter ranges (`ParameterSchema`). This feature adds
  what the 75 games need on top of that pipeline: safe preprocessing (include once, checked defines), declared program
  variants that can be compiled in advance, a default precision chosen from the device, complete diagnostics (long logs,
  warnings, link errors), declared uniform layouts checked against the compiled program, and parameters bound to their
  uniforms. No second shader pipeline.
- **Who the users are:** the engineer writing one of the 75 games, who writes shaders as text in code, needs a mistake
  named with its file and line before anything is drawn, and needs every variant of a shader to compile on the devices;
  the player, who must never see a black frame or a wrong colour from a shader that silently failed; the verification
  runner, which compiles every variant of every game in advance.
- **Prerequisites:** R02-F04 (GPU resource ownership) and UA-F02 are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009: one USD 1.99 unlock); the
  Round 2 lock (ImplementationLock-100). **Device-only items:** the precision and compile behaviour of the three devices'
  drivers is checked in the device campaign; the simulator's ANGLE path is the automated evidence. **Owner-only items:**
  none.
- **Owner rulings:** tests are short; system accessibility audits wait for the device campaign; independent files go to
  parallel agents.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A shader mistake is named before anything is drawn (Priority: P1) 🎯

A game engineer writes a shader with includes and defines. A wrong include, a bad define, a compile error or a link
error is reported with the file and line the engineer wrote, with every message of the compiler, and the game never
draws with a half-made program.

**Why this priority**: every visual of every game is a shader; a silent failure is a black screen on a device.

**Independent Test**: compile shaders with planted mistakes and compare the reports with the expected file, line and
message.

**Acceptance Scenarios**:

1. **Given** a shader that includes the same helper twice through two paths, **When** it is expanded, **Then** the
   helper appears once and the shader compiles.
2. **Given** a define with an invalid name, a reserved name, a multi-line value or too many defines, **When** the
   shader is expanded, **Then** it is refused with a named reason before compiling.
3. **Given** a compile error in an included file, **When** it is compiled, **Then** the report names that file and line;
   **given** a link error, **Then** the report names the stage and both files; **given** a compiler log longer than the
   old fixed limit, **Then** every message is kept.
4. **Given** a shader that compiles with warnings, **When** it is compiled, **Then** the warnings are kept with the
   program.

---

### User Story 2 - Every variant compiles in advance (Priority: P1)

The engineer declares the variants of a shader (for example a quality level and a feature switch, each with a closed
list of values); the game or the verification runner compiles them all in advance and learns which fail.

**Why this priority**: a variant first compiled on a device in the middle of play is a stall or a failure the player
sees.

**Independent Test**: declare a variant set, compile every combination, and check the count, the keys and the reports.

**Acceptance Scenarios**:

1. **Given** a variant set of two switches with two and three values, **When** it is compiled in advance, **Then** six
   programs are made, each with its own key, and each later request is served from the cache.
2. **Given** a combination that fails, **When** the set is compiled, **Then** the result names that combination and its
   diagnostics, and the others are still compiled.
3. **Given** a variant set above the combination limit, **Then** it is refused before compiling.

---

### User Story 3 - Precision is right for the device (Priority: P2)

A fragment shader without a precision statement gets the best precision the device supports; a shader that asks for a
precision the device lacks is reported.

**Independent Test**: expand shaders with and without precision statements against device precision reports with and
without high precision.

**Acceptance Scenarios**:

1. **Given** a fragment shader without a float precision statement, **When** it is expanded for a device with high
   fragment precision, **Then** a high-precision default is inserted; **for** a device without it, **then** medium.
2. **Given** a fragment shader that requests high precision on a device without it, **Then** a warning names the file
   and line.

---

### User Story 4 - Uniforms and parameters stay in step (Priority: P1)

The engineer declares a shader's uniforms (names and types) and binds a game's named parameters to them. A misspelled
or mistyped uniform is reported when the program is made, a declared uniform the compiler removed is reported as
unused, and parameter values reach their uniforms clamped to their ranges, the same after a context rebuild.

**Independent Test**: check layouts against compiled programs; set parameters and read the uniform values back.

**Acceptance Scenarios**:

1. **Given** a program with an active uniform not in its declared layout, or one of a different type, **When** the
   layout is checked, **Then** it is refused naming the uniform.
2. **Given** a declared uniform that the compiler removed, **Then** it is reported as unused, not as an error.
3. **Given** a parameter schema bound to a program, **When** values are applied, **Then** each `u_<name>` uniform holds
   the clamped value, non-finite values are refused, and after a context rebuild the same values are applied again.

### Edge Cases

- **An include cycle or an include deeper than the limit:** refused as today.
- **An expanded source above 64 KiB:** refused, the size checked in bytes during expansion.
- **A define value of an empty string:** allowed (a flag define).
- **A variant set with one combination:** behaves as a single program.
- **A program evicted from the cache while a variant set is warm:** the next request compiles it again and reports a
  miss.
- **A parameter with no uniform in the program:** reported once as unused.
- **A driver log in an unknown format:** kept whole as one diagnostic.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F06-001**: Expansion MUST include each file at most once per shader (later includes of the same file are
  skipped), keep refusing cycles, depth above 8 and expanded text above 64 KiB measured in bytes.
- **FR-R02F06-002**: Defines MUST be validated before expansion: a name matches `[A-Za-z_][A-Za-z0-9_]*`, does not
  start with `GL_` or `__`; a value has no line break and at most 256 characters; at most 32 defines per shader.
- **FR-R02F06-003**: A declared variant set (switches, each with a closed list of values) MUST enumerate its
  combinations in a stable order with a stable key per combination, refuse more than 64 combinations, and compile all of
  them in advance, reporting each failing combination with its diagnostics without stopping the others.
- **FR-R02F06-004**: A fragment shader without a float precision statement MUST receive a default precision chosen from
  the device report (high when supported, otherwise medium), as a generated line; a requested precision the device
  lacks MUST be reported as a warning with file and line.
- **FR-R02F06-005**: Compile and link logs MUST be read whole up to 64 KiB, warnings of successful compiles kept with the
  program, link diagnostics labelled with both stages' file names, and an unparsed log line kept as a diagnostic.
- **FR-R02F06-006**: A declared uniform layout (name and type) MUST be checked against a program's active uniforms:
  an undeclared or mistyped active uniform is an error naming it; a declared uniform the compiler removed is reported as
  unused.
- **FR-R02F06-007**: A parameter schema MUST bind to a program's `u_<name>` float uniforms; applying values clamps them
  to their ranges, refuses non-finite values, reports parameters without a uniform once, and re-applies after a context
  rebuild.
- **FR-R02F06-008**: Every refusal and failure MUST carry a stable reason code (`shader.*`) and the feature id `R2-F06`;
  failure reports name the experience id, seed, tick and capability tier when the caller supplies them.
- **FR-R02F06-009**: Existing shaders, programs and tests MUST keep working unchanged (no Stage One breakage); every new
  public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Define set**: validated name–value pairs.
- **Variant set**: a shader's switches and their values; combinations with keys.
- **Precision policy**: the default float precision chosen from the device.
- **Uniform layout**: declared uniform names and types.
- **Parameter binding**: a parameter schema matched to a program's uniforms.
- **Shader report**: diagnostics with reason codes, stage, file, line and severity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F06-001**: 100% of planted mistakes (at least 12: include twice, cycle, depth, size, four define faults,
  compile error in an include, link error, long log, mistyped uniform) are reported with the expected reason, file and
  line.
- **SC-R02F06-002**: A variant set of six combinations compiles in advance into six programs with six distinct keys,
  and six later requests are all cache hits.
- **SC-R02F06-003**: Default precision is high or medium exactly as the device report says, in 4 of 4 combinations of
  device report and shader text.
- **SC-R02F06-004**: Parameter values read back from their uniforms equal the clamped values within float precision,
  before and after a context rebuild.
- **SC-R02F06-005**: Every existing shader of the 25 integrated experiences still compiles (the existing validation
  tests pass), and the reference regression passes 7 of 7 steps.
- **SC-R02F06-006**: Each unit test finishes in under 10 seconds.

## Assumptions

- Shaders are GLSL ES 3.00 text written in code; no shader is loaded from the network or a file the person supplies at
  run time in the 75 games (Shader Studio keeps its own editor path).
- Uniform blocks are not needed by the 75 games' shared features listed in section 13; they stay out of scope.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Shader preprocessing | FR-R02F06-001, 002 |
| Embedded program variants | FR-R02F06-003 |
| Precision qualifiers | FR-R02F06-004 |
| Compile diagnostics | FR-R02F06-005, 008 |
| Stable uniforms | FR-R02F06-006, 007 |
| Observability (feature id, reason code) | FR-R02F06-008 |
| No Stage One breakage | FR-R02F06-009 |

## Negative Requirements / Excluded scope

- No second shader pipeline or context; no uniform blocks; no runtime shader download; no shader binary cache on disk;
  no image models or art; no device run before ImplementationLock-100; no advertising or purchase change.
