# Research: A25-P00 (feature 179)

- **D1 What VisualCore offers (survey, spot-checked):**
  - **Passes and targets:** `FieldPass` (`RenderTarget` inputs; float, vec2, vec4 and int uniforms;
    `FieldPassError.compile`), `ResourceRegistry.makeRenderTarget`, `acquireTarget`, `recycle`, `trimPools`,
    `PingPongTarget`, `TextureFormat` (rgba8, rgba16f, r8), `FloatRenderSupport`, `ResourceBudget`, `stats`.
  - **Effects graph:** `EffectGraphDescription`, `EffectGraphValidator`, `PassSchemas`, `EffectRenderer`,
    `EffectScene` (a closed set of internal pass types).
  - **Shaders:** `ShaderLibrary`, `ShaderBundle`, `vc/color.glsl`, `InfoLogParser`, `ShaderDiagnostic`, `ShaderError`,
    the program cache.
  - **Parameters and persistence:** `ParameterDefinition`, `ParameterSchema`, `ParameterEditor`, `ExperienceControl`,
    `ExperienceStorage`, `MigrationChain`, `DocumentStore`, `NamedLibrary`.
  - **Export:** `RenderTarget.readPixels`, `RenderHost.renderOffscreen`, `StillImage`, `StillImageEncoder`,
    `ExportGeometry`, `StillCapture`, `TemporaryFolder`.
  - **Host:** `ExperiencePresenter`, `ExperienceCore`, `ExperienceShell`, `ExperienceSession`, `RenderContext`.
- **D2 What it lacks:** a byte-wise upload into a render target; image decoding; a photo picker anywhere; an sRGB
  texture format; vec3 and mat4 field uniforms; a shared still-export `Transferable`; structured per-pass diagnostics
  from `EffectRenderer`.
- **D3 Traceability:** the six brainstorm capabilities (render graph, framebuffer pipelines, shader library, effect
  parameters, preset serialization, offscreen rendering and export) and the six version 0.1 features (linear chain
  with five effects; reorder, enable and preview; compare and presets; image import; still export; target pooling and
  compile diagnostics) each map to matrix rows.
- **D4 Phase plan of the gaps (manual §9):**

  | Gap | Phase |
  |---|---|
  | G-MODEL (effects, nodes, chain, parameters, output settings), G-EFFECTS (five effect programs) | A25-P01 |
  | G-COMPILER (pass plan, lifetimes), G-POOL (bounded targets), G-DIAG (compile diagnostics) | A25-P02 |
  | G-EDIT (reorder, enable, preview), G-COMPARE, G-IMPORT (picker, decode, cap), U-RGBAUPLOAD | A25-P03 |
  | G-PRESETS (stored presets), G-EXPORT (still export) | A25-P04 |
  | G-COLOR (linear and sRGB boundaries), G-ROBUST (memory, limits, device plan) | A25-P05 |
  | G-RELEASE | A25-P06 |
- **D5 Numbers later:** caps (chain length, parameter ranges, source and export edges, target count and bytes) are
  set in A25-P01 and A25-P02 as bounds, not targets.
- **D6 Rejected:**
  - `EffectRenderer` and its pass set (closed: new effects cannot be added from outside, and its diagnostics are only
    registry warnings);
  - uploading a large image through `upload(rgbaFloats:)` (four floats per pixel);
  - an image-picker or photo-library read permission (the system picker needs none).
