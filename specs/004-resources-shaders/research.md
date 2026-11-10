# Research: Phase 3

## R-F301 ANGLE info-log format
- **Decision**: parse lines matching `^(ERROR|WARNING): (\d+):(\d+): (.*)$` (source-string index, line,
  message); anything else becomes a raw diagnostic with file "unknown". A simulator test captures a
  real ANGLE log for a known error and pins the parser against it.
- **Rationale**: ANGLE's GLSL translator emits this form; pinning against real output avoids guessing.

## R-F302 Line map with inserted lines
- **Decision**: expansion emits `#version 300 es` first, then defines, then content. The line map is an
  array indexed by expanded line (1-based) → (file, line); synthetic lines map to file `<generated>`.
- **Alternatives**: `#line` directives (rejected: `#line` with a file argument isn't portable in GLSL ES).

## R-F303 SHA-256 without CryptoKit in the pure module
- **Decision**: small pure-Swift SHA-256 (FIPS 180-4) with NIST test vectors; CryptoKit exists on
  macOS/iOS but keeping the pure module Foundation-only satisfies R2 and Linux portability.

## R-F304 Byte estimates
- **Decision**: RGBA8 = 4 B/px, RGBA16F = 8, R8 = 1, depth24 = 4; buffers = requested size; programs 0.
