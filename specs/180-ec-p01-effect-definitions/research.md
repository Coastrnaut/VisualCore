# Research: A25-P01 (feature 180)

- **R1 Effects app-local over FieldPass.**
  - **Decision:** each effect is a fragment program string in the core with a matching CPU reference; tests compile it
    with `FieldPass` in the host's context.
  - **Rationale:** A25-P00 clarification Q1; the effects graph's pass set is closed.
  - **Alternatives considered:** `EffectRenderer` pass types (rejected: no posterize or vignette, no outside effects).
- **R2 Exact references.**
  - **Decision:** formulas use only operations reproducible on the CPU in `Float`; sampling at texel centres (blur,
    grade, posterize, vignette) is exact for an `.rgba8` source, and `distort`'s between-centre sampling gets a wider
    tolerance (4/255).
  - **Rationale:** a reference that differs only by quantisation keeps the render contract testable.
- **R3 Undo as inverse edits.**
  - **Decision:** each edit records its inverse at the time it applies (for example remove records the node and its
    position); undo applies the inverse.
  - **Rationale:** exact restoration without storing whole chains; equality and fingerprint prove it.
  - **Alternatives considered:** snapshots per edit (rejected: more memory, same result).
- **R4 Packed uniforms.**
  - **Decision:** each program reads `u_params` (vec4) and, when needed, `u_params2`; the texel size is `u_texel` (vec2).
  - **Rationale:** `FieldUniform` has no vec3 or mat4 (A25-P00 audit).
