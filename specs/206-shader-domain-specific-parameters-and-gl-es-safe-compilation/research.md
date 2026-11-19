# Research: R02-F06

- **R1 Include once vs guards.** Decision: the expander skips a file already included in this expansion. Rationale:
  diamond includes work without asking authors for `#ifndef`; the bundled guards stay harmless. Alternative:
  `#pragma once` (rejected: one more directive to parse, same effect).
- **R2 Byte size guard.** Decision: track the running byte count (UTF-8 plus newlines) during expansion and compare
  with 65,536. Rationale: fixes the line-count comparison (`ShaderLibrary.swift:121`).
- **R3 Define validation.** Decision: identifier rule, reserved prefixes `GL_` and `__`, single-line values ≤ 256
  characters, ≤ 32 defines. Rationale: GLSL ES 3.00 §3.4 reserves `GL_` and `__` macro names; multi-line values would
  break line mapping.
- **R4 Variant enumeration.** Decision: ≤ 6 switches, 1–8 values each, ≤ 64 combinations, lexicographic order. Rationale:
  bounded advance compile time; matches the cache size of 64.
- **R5 Precision.** Decision: insert `precision highp float;` (or `mediump`) after the defines in a fragment shader
  without a `precision … float;` statement; flag `highp` declarations when `fragmentHighp.isSupported` is false.
  Rationale: GLSL ES fragment shaders have no default float precision.
- **R6 Logs.** Decision: `GL_INFO_LOG_LENGTH` sized buffer, capped at 65,536 bytes; read the log after a successful
  compile too. Rationale: full messages and warnings.
- **R7 Uniform types.** Decision: map `glGetActiveUniform` types to `UniformType` (FLOAT, FLOAT_VEC2–4, INT, INT_VEC2–4,
  BOOL, FLOAT_MAT3, FLOAT_MAT4, SAMPLER_2D, SAMPLER_3D, SAMPLER_CUBE); others are `.other(code)` and must not be
  declared. Rationale: covers every uniform used by the 25 experiences.
- **R8 Parameter binding.** Decision: `u_<name>` float uniforms set from `ResolvedParameters` after clamping. Rationale:
  the documented convention of `ParameterDefinition`.
