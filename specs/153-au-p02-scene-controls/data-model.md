# Data Model: A21-P02 (feature 153)

- **AuroraCore** (adapter, snapshot schema 1): the `SkyScene`, `hue` (−0.5…0.5 turns) and `limit` (0.2…0.72,
  default 0.6); digest of exactly these. Actions (one value each): `preset.select` 0…2 (integer), `colour.hue`
  −0.5…0.5, `motion.speed` 0…2, `motion.turbulence` 0…1, `sky.ribbons` 1…4 (integer), `sky.stars` 0…400 (integer),
  `sky.clouds` 0…1, `light.limit` 0.2…0.72. A fractional integer value is refused; a refusal leaves the state
  unchanged. Quality tiers `level-0` (5 octaves) and `level-1` (3).
- **Blend:** from (current blended inputs), to (target inputs), progress 0…1 over 1.5 s of frame time, smoothstep
  eased; immediate under Reduce Motion.
- **Limit in the shader:** `u_limit`; knee from 0.83 × limit to the limit, applied after compositing; every pixel's
  luminance ≤ limit + 1/255.
- **Chrome:** `controlsHidden` (presenter only), restored by a tap on the canvas or the action "Show controls".
