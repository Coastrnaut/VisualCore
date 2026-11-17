# Data model: A18-P05 (feature 135)

- **`CachedScene` (VisualCoreRendering):**
  - `init(child: any RenderScene)`;
  - `var key: Int` and `var passThrough: Bool` (default true);
  - `private(set) var childDrawCount: Int`;
  - `invalidate()`, and `isSetUp`;
  - pass-through releases the target, so each switch from moving to still costs one draw, and an offscreen export
    resizes the scene and so redraws once;
  - setup, resize, render and teardown as a `RenderScene`. It owns the child.
- **Presenter:**
  - the still rule `isStill` = (no motion or reduced) ∧ ¬seconds ∧ no fade;
  - `stillKey` is a 64-bit FNV-1a mix of theme, palette, tier, night dim and tint, drift step, idle dim and size,
    plus `displayScale` (the drift in pixels depends on it) and the uniform time (always 0 while still);
  - with `passThrough = !isStill`, the cache key is `stillKey`;
  - `backgroundDrawCount` (the child's draws).
- **Campaign row:** id, measurement, device, procedure, threshold, status.
