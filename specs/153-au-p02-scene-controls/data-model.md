# Data Model: A21-P02 (feature 153)

- **AuroraCore** (adapter, snapshot schema 1): the `SkyScene`, `hue` (−0.5…0.5 turns) and `limit` (0.2…0.72,
  default 0.6); digest of exactly these. A snapshot of a newer schema, a damaged payload or a scene
  that `SkyScene.decode` refuses is refused on restore, and the open sky stays as it was. Actions (one value each): `preset.select` 0…2 (integer), `colour.hue`
  −0.5…0.5, `motion.speed` 0…2, `motion.turbulence` 0…1, `sky.ribbons` 1…4 (integer), `sky.stars` 0…400 (integer),
  `sky.clouds` 0…1, `light.limit` 0.2…0.72. A fractional integer value is refused; a refusal leaves the state
  unchanged. Quality tiers `level-0` (5 octaves) and `level-1` (3).
- **Hue:** the presenter rotates every palette colour's hue by `hue` turns (in a perceptual-enough HSV of the sRGB
  colour) before building `SkyUniforms`; the core's `SkyUniforms(scene:phase:level:)` is unchanged.
- **Blend:** from (current blended inputs), to (target inputs), progress 0…1 over 1.5 s of frame time, smoothstep
  eased; immediate under Reduce Motion.
- **Limit in the shader:** `u_limit`; knee from 0.83 × limit to the limit, applied after compositing; every pixel's
  luminance ≤ limit + 1/255.
- **Chrome:** `controlsHidden` (presenter only), restored by a tap on the canvas or the action "Show controls".

- **As built (A21-P02):**
  - the knee starts at 5/6 × limit (`SkyShader.kneeRatio`), so the default 0.72 is exactly the A21-P01 knee;
  - only a preset change starts the 1.5 s blend; a control moved during a blend retargets it with its progress kept;
    re-selecting the current preset snaps; opening or restoring shows the state at once;
  - the palette expands to five stops (the sky and four ribbon slots, black beyond the count), which draws the A21-P01
    picture byte for byte; during a blend the larger ribbon count is drawn and a ribbon present on one side only fades;
  - `reset()` returns the limit to 0.6 and keeps the quality tier;
  - restore refusals are `SkyRestoreRefusal` (`damaged`, `scene(SceneRefusal)`, out-of-range `hue` or `limit`); a
    fractional integer value is refused with the rule `a21.not-whole`; the outcome is `preset-<id>`;
  - the tap that shows the controls is presentation only: no gesture action, all eight actions native.
