# Contract: Visual Programming Lab preview (A23-P03)

- **Operators (GLSL ES 3.00 text, `#include "vc/noise.glsl"` where used):** samplers `u_a`, `u_b` (mix), `u_image`
  (blur, output); uniforms `u_scale`, `u_octaves`, `u_speed`, `u_time` (noise), `u_angle`, `u_start`, `u_end`
  (gradient, vec4), `u_amount` (mix), `u_radius`, `u_direction` (blur, vec2), output none.
- **Presenter:** `pipeline` (test seam), `previewState`, `previewVisible`; the inset is the bottom-left square of a
  third of the drawable's shorter side.
- **Identifiers:** `preview` (the inset frame), `preview-message`, `preview-toggle`.
- **VisualCore names used:** `FieldPass`, `FieldUniform`, `FieldPassError`, `RenderTarget`, `TextureFormat`,
  `ResourceRegistry`, `ShaderBundle`, `RenderContext`, `FrameInfo` (and the A23-P02 set).
