# Data Model: A22-P03 (feature 161)

- **StudioCore** (schema 1):
  - `template` 0…3;
  - `values` [16] (0…1);
  - `textures` [2] (0 checker, 1 ramp, 2 noise; optional in the payload, default `[0, 1]`);
  - `runs`.

  The digest covers the template, the values and the textures.
- **Actions:**
  - `template.select [0…3]`;
  - `uniform.set [0…15, 0…1]`;
  - `texture.set [0…1, 0…2]`, both whole; the input index must be below the live project's input count, otherwise
    `a22.no-texture`;
  - `shader.run [1…1]`.
- **TextureRecipes:** pure; each recipe gives 64 × 64 RGBA floats (0…1, rows bottom-up):
  - `checker`: 8 × 8 cells, 0.85 and 0.25 grey;
  - `ramp`: from (0.05, 0.10, 0.40) to (0.95, 0.55, 0.20), left to right;
  - `noise`: value noise of an integer hash over an 8 × 8 lattice, smoothstep-interpolated, grey.
- **Template `texture-mix`:** inputs `u_texture0` and `u_texture1`; uniform `u_blend` (0…1, default 0.5). Its output
  is `mix(texture(u_texture0, v_uv), texture(u_texture1, v_uv), u_blend)`.
- **SyntaxPalette:** a token kind maps to a colour role and a weight (keyword bold, comment italic).
- **Inspector row:** title, value text (two decimals plus the unit), range text ("a to b"), slider normalized.
