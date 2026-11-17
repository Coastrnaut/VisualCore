# Research: A18-P03 (feature 133)

- **D1 Crossfade in VisualCoreRendering (clarification Q1):**
  - **Decision:** a `RenderScene` composing two scenes through `context.redirected`.
  - **Rationale:** it is generic, has two consumers, and uses existing render targets.
  - **Alternative:** an experience-local mix. Rejected, because it would be copied later.
- **D2 Themes as fragments (Q2):** each theme is a `FullScreenShaderScene` fragment with uniforms `u_resolution`,
  `u_time`, `u_palette[4]` and a count uniform.
  - **Rationale:** the same lifecycle as the noise gradient, and one draw.
  - **Alternative for particle drift:** VisualCore particles. Rejected for this phase, because a shader keeps one draw
    and a deterministic frame.
- **D3 Curated palettes:** there are 12 palettes in all (three per theme). Each channel is at most 0.2 encoded, so
  white text reaches more than 4.5 : 1 and the probe reads `dark`.
- **D4 Preset and favourites (Q3, Q4):** `ThemePreset` is pure core data. The favourites use `NamedLibrary` in
  `ExperienceStorage`, with a cap of 12.
- **D5 Snapshot schema 2:** `theme` and `palette` are added, and schema 1 migrates to theme 0 and palette 0. The
  schema-1 and schema-2 examples are registered in `ExperienceRegistry` (the lesson of X-A17).
- **D6 Crossfade timing (Q5):** 1.2 s, smoothstep, `transitionDuration` under Reduce Motion. A change during a fade
  restarts it from the current mix.
