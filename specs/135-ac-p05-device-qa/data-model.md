# Data model: A18-P05 (feature 135)

- **`CachedScene` (VisualCoreRendering):**
  - `init(child: any RenderScene)`;
  - `var key: Int` and `var passThrough: Bool` (default true);
  - `private(set) var childDrawCount: Int`;
  - `invalidate()`;
  - setup, resize, render and teardown as a `RenderScene`. It owns the child.
- **Presenter:**
  - the still rule `isStill` = (no motion or reduced) ∧ ¬seconds ∧ no fade;
  - `stillKey` hashes theme, palette, tier, night dim and tint, drift step, idle dim and size;
  - with `passThrough = !isStill`, the cache key is `stillKey`;
  - `backgroundDrawCount` (the child's draws).
- **Campaign row:** id, measurement, device, procedure, threshold, status.
