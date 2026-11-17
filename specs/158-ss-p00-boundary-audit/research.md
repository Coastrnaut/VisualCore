# Research: A22-P00 (feature 158)

## Facts (verified in code, 2026-11-17)

The facts of the clarification session hold. VisualCore provides:
- **Source and diagnostics:** source expansion with includes, defines and a line-origin table; an info-log parser that
  gives line-mapped diagnostics; compile and link through the registry with structured errors and a program cache;
  active-uniform reflection and typed setters.
- **Drawing and limits:** a full-screen shader scene with fixed source; capability and precision queries (GLSL ES
  3.00 only); texture upload; parameter schemas that refuse NaN and clamp.
- **Storage:** experience storage with named files and small values; snapshots with migration.
- **Pacing:** frame pacing, a pacing meter and a presenter frame cap.

It has no watchdog, no code editor, no last-good program swap, no texture inputs for full-screen shaders, no named-file
library over the experience storage and no per-shader failure log.

## Decisions

- **D1 Scope:** audit only. The one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities and the six version 0.1 features.
  - **Capabilities:** shader compilation, diagnostics and error reporting, render previews, the shader asset pipeline,
    parameter controls.
  - **Features:** the code editor with line-numbered diagnostics; templates with uniforms and texture inputs; an
    explicit Compile and Run with a last-known-good preview; a parameter inspector for bounded uniforms; local save and
    open with versioned files; resource and complexity limits, a watchdog and recoverable failures.
  - **Cross-cutting rows:** context loss, resize and orientation, quality tiers, accessibility, bounded resources,
    permissions (none), the compatibility profile, the render thread and truthful claims.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners** (the manual's phases):

  | Gaps | Phase |
  |---|---|
  | The project, template, uniform and diagnostic models as pure versioned types; the source validator and its caps; line mapping through the expansion's origins; the starter templates | A22-P01 |
  | The preview scene: compile in the host's context, swap only on success, keep the last good program, uniforms from reflection; the explicit Compile and Run | A22-P02 |
  | The editor with line numbers and a diagnostics list; the parameter inspector for bounded uniforms; texture inputs made in code | A22-P03 |
  | Project save and open with versioned files; the watchdog, stop and reset; the compatibility profile | A22-P04 |
  | Device plan (drivers, keyboards, iPhone ergonomics, slow shaders) and the interface journeys | A22-P05 |
  | Release | A22-P06 |
- **D4a Numbers later:** the caps (source bytes, lines, uniforms, preview size), the watchdog limit and the template
  set are decided with their tests in A22-P01 to A22-P04. This audit fixes only who owns them.
- **D5 Permissions:** none. There is no import from Photos or Files in 0.1, and no network.
- **D6 No sandbox claim:** GPU code is never presented as isolated (manual risk 1).
- **Alternatives considered:**
  - Rebuilding a `FullScreenShaderScene` per compile was rejected: a failed compile draws grey and loses the last good
    preview.
  - A VisualCore watchdog now was rejected: it has one user; it moves upstream only when a second experience needs it
    (Principle II).
  - `NamedLibrary` from VisualCorePersistence was rejected: it works on a raw directory, not on the experience
    storage that the host manages and removes.
