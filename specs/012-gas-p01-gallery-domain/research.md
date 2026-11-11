# Research: A01-P01

- **R1 Parameter hash.** Decision: FNV-1a 64-bit over a canonical string:
  `family|seed|palette|name=value;…`, with names sorted and values formatted with `%.9g` after resolution. The hash
  is rendered as 16 hex digits. Rationale: stable across runs and platforms (Swift `Hasher` is seeded per process),
  with no dependency. Alternative: SHA-256 via CryptoKit, rejected because it is not a Foundation-only dependency
  (rule R2) and is not needed for a cache key.
- **R2 Canonical encoding.** Decision: `JSONEncoder` with `.sortedKeys`, documents holding `Double` values that were
  already resolved, and the seed encoded as a decimal **string** (JSON numbers lose precision above 2^53).
  Rationale: exact `UInt64` round trips. Alternative: numeric seed, rejected for precision loss at 2^64−1.
- **R3 GLSL include library.** Decision: `VisualCoreRendering` bundles `GLSL/vc/*.glsl` as package resources
  (`Bundle.module`):
  - `hash.glsl`: pcg-style integer hash and `hash21`/`hash22`;
  - `noise.glsl`: value and gradient noise and `fbm`;
  - `palette.glsl`: `vc_palette(t)` over `u_palette`/`u_paletteCount` in linear light;
  - `sdf.glsl`: sphere, box, torus and smooth union;
  - `color.glsl`: exact sRGB encode and decode.

  `ShaderBundle` preloads them as includes `"vc/<name>.glsl"`. Rationale: one copy for 25 apps; include syntax is
  already supported by `ShaderLibrary`.
- **R4 Full-screen scene.** `FullScreenShaderScene` draws a single triangle using a built-in vertex shader that outputs
  `v_uv`. It binds `u_time`, `u_resolution`, `u_seed`, `u_palette`/`u_paletteCount` and `u_<param>` floats. Its
  inputs are a value snapshot (`parameters`, `palette`, `seedOffsets`, `fixedTime`). When `fixedTime` is set, time
  ignores frames, which makes tests and previews deterministic.
- **R5 Distinctness and determinism thresholds.** The F07 noise-floor data shows identical draws on the same simulator
  match exactly. The tolerance (≥ 99% within 2/255, mean ≤ 0.5/255) leaves headroom. Distinctness of ≥ 20/255 mean
  between families is far above that noise.
- **R6 Particles family.** `ParticleReplay` (pure) configures a `ParticleSystem(seed:)` with an emitter and forces from
  the parameters, and replays at fixed 1/60 s steps to `min(t, 120)`. `ParticlesArtScene` draws the background shader
  with `FullScreenShaderScene` and the particles with `ParticleRenderer`, using a `Camera2D` that fits the view.
- **R7 RenderSurface.** It is a `UIViewRepresentable` that embeds a caller-owned `RenderHost.view`. It sets the scale
  callback and exposes `accessibilityLabel`/`accessibilityHint` on the container. The surface never creates or
  destroys hosts; ownership stays with the caller (one host per screen).
- **R8 Shader errors.** `FullScreenShaderScene.errorMessage` holds the first diagnostic as `file:line: message`.
  Rendering then clears to dark gray, and the screen shows the message.
