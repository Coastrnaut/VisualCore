# Feature Specification: Phase 3 — Shared GPU Resource and Shader Services

**Feature Branch**: `004-resources-shaders` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F03 · ID namespace FR-F3##, SC-F3##, T-F3##

**Input**: User description: archived `sources/README.md` §10.5 Phase 3 prompt (verbatim in the
invocation), with the canonical override: the reference is read-only. ProjectM use is shown in F07
through the reference harness, with the engine's shaders and presets unchanged. In F03 the
non-ProjectM demonstration is package tests plus the sample scenes moved onto the new services. Pure
parts go in the host-testable package. Contract: `specs/002-architecture-contracts/contracts/resources-shaders-errors.md`.

## User Scenarios & Testing *(mandatory)*

Users: developers of the suite apps (25 of them, most with custom shaders and offscreen targets).

### User Story 1 - Write shaders with clear errors (Priority: P1) 🎯

A developer keeps shader sources as named files with shared snippets included by name. When a
shader has a mistake, the error names the original file and line, and the last working program keeps
drawing.

**Independent Test**: Host tests expand includes and map lines; simulator tests compile a broken
shader and check that the diagnostic file/line are correct and the previous program still renders.

**Acceptance Scenarios**:

1. **Given** a fragment shader including `noise.glsl` with an error on line 12 of `noise.glsl`,
   **When** compiled, **Then** the diagnostic reports file `noise.glsl`, line 12, stage fragment.
2. **Given** a working program, **When** a replacement fails to compile, **Then** the working program
   remains in use and the failure is reported.
3. **Given** a source over 64 KiB, includes deeper than 8 levels, or a cyclic include, **When**
   loaded, **Then** it is rejected with a specific error before reaching the GPU.

---

### User Story 2 - Create textures, buffers and framebuffers safely (Priority: P1)

A developer creates textures, buffers and render targets through one registry that tracks bytes per
kind against a budget, refuses allocations over budget, and reports live counts so leaks are visible.

**Independent Test**: Host tests for budget accounting; simulator tests create and release objects
and check counts and bytes return to zero, including after 100 context recreations.

**Acceptance Scenarios**:

1. **Given** a 64 MiB budget, **When** a 128 MiB texture is requested, **Then** it is refused with an
   over-budget error and nothing is allocated.
2. **Given** a resource from an older context generation, **When** used, **Then** it is rejected,
   counted as stale, and never reaches the GPU.
3. **Given** a scene that creates and releases resources, **When** the host is destroyed, **Then** the
   leak counter is zero.
4. **Given** a framebuffer target, **When** created at a size, **Then** it is complete, can be rendered
   into and read back, and is released with its texture.

---

### User Story 3 - Variants, caching and uniforms (Priority: P2)

A developer compiles the same shader with different defines (variants), gets a cached program when
the same sources and defines are requested again, and sets uniforms by name with type checking.

**Independent Test**: Simulator tests count compilations (cache hit on repeat; cache cleared after
recreation) and verify uniform type mismatches are reported once and not applied.

**Acceptance Scenarios**:

1. **Given** a program requested twice with identical sources and defines, **When** the second request
   arrives, **Then** no new compilation happens.
2. **Given** a recreated context, **When** a program is requested again, **Then** it is recompiled for
   the new generation.
3. **Given** a uniform declared as `vec3`, **When** set as a float, **Then** the mismatch is reported once
   and the uniform is unchanged.

### Edge Cases

- Unknown include name: error with the including file and line.
- Memory warning: free pooled targets; live counts reflect the release.
- Zero-size or over-max-size texture: rejected before allocation.
- Uniform not present (optimized out): reported once per program, ignored.
- ANGLE info-log formats that cannot be parsed: diagnostic keeps the raw message, file "unknown".
- Physical-device GPU memory: not measured here (estimates only; campaign II).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F301**: A shader library MUST hold named sources and expand `#include "name"` directives with
  a line map from expanded lines to (file, line).
- **FR-F302**: Expansion MUST reject sources over 64 KiB after expansion, include depth over 8,
  include cycles and unknown includes, each with a specific error.
- **FR-F303**: The library MUST add `#version 300 es` when missing, and support named variants via
  `#define` lines inserted after the version line, keeping the line map correct.
- **FR-F304**: ANGLE compile/link info logs MUST be parsed into diagnostics (file, line, stage,
  severity, message) mapped through the line map; unparseable lines keep the raw message.
- **FR-F305**: Program creation MUST never replace a working program on failure; failures return
  diagnostics.
- **FR-F306**: Programs MUST be cached by a hash of sources and defines per context generation, and
  the cache cleared on recreation.
- **FR-F307**: Uniform setters MUST validate the name and type against the program's active uniforms,
  reporting each mismatch once per program and uniform.
- **FR-F308**: A resource registry MUST create textures, buffers, framebuffers (with color texture)
  and programs, tracking kind, GL name, bytes, generation and label for each.
- **FR-F309**: The registry MUST enforce per-kind and total byte budgets (default total 256 MiB),
  refusing over-budget requests without allocating.
- **FR-F310**: Handles from an older generation MUST be rejected and counted (`staleRejected`).
- **FR-F311**: The registry MUST report live counts and bytes per kind, peak bytes, stale rejections
  and leaks (live at teardown); releasing all handles returns counts and bytes to zero.
- **FR-F312**: On memory pressure, pooled render targets MUST be freed and the release reflected.
- **FR-F313**: Texture and render-target sizes MUST be validated against capabilities (non-zero, ≤ max
  texture size).
- **FR-F314**: The existing sample scenes MUST be moved onto the shader and resource services.
- **FR-F315**: The color-space policy MUST be documented: 8-bit targets hold sRGB-encoded values;
  linear-light math converts explicitly.

### Key Entities

- **ShaderSource / ShaderLibrary / ExpandedShader** (pure): name, text; expansion result with line map.
- **ShaderDiagnostic** (pure): file, line, stage, severity, message.
- **ResourceBudget / ResourceLedger** (pure): limits, per-kind counters, peak, stale, leaks.
- **GPUHandle**: kind, GL name, bytes, generation, label.
- **ShaderProgram**: GL program, uniform table, cache key.
- **RenderTarget**: framebuffer + color texture + size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F301**: 100% of fixture shader errors report the correct original file and line.
- **SC-F302**: 100% of invalid sources (size, depth, cycle, unknown include) are rejected before the GPU.
- **SC-F303**: After 100 context recreations with resources created each time, live handles and bytes
  are zero after teardown.
- **SC-F304**: Repeated identical program requests compile once per generation (cache hits measured).
- **SC-F305**: Over-budget requests are refused 100% of the time with no allocation.
- **SC-F306**: Sample scenes render identically before and after moving onto the services (pixel tests unchanged).

## Assumptions

- ANGLE info-log format `ERROR: 0:<line>: <message>` (verified in a simulator fixture during
  implementation; other forms fall back to raw messages).
- Byte sizes are estimates from dimensions and formats (driver truth unavailable).
- ProjectM engine shaders are not touched (F07 shows coexistence).
