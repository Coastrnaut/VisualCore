

- **As built (A21-P04):**
  - `AmbientLoopPartial` (cycles per loop ≥ 1, amplitude 0…1) is public; `sampleRate` is a static constant of
    `AmbientLoopRecipe` (48,000); phases step in exact integers (`(c·i) mod N`);
  - the swell is `0.65 − 0.35·cos(2π·m·i/N)` (0.3 to 1, never silent), and the buffer is scaled so its peak equals the
    gain, then clamped;
  - `AmbientLoopPlayer` has an output seam of its own (a looped schedule does not fit the one-shot output), a default
    volume of 1, and never restarts by itself after a stop;
  - the sky shader has `u_twinkleOff` (unset by default, so the default picture is unchanged);
  - `fragmentHighp` is an injectable closure (unknown by default): in the app a compile failure triggers the fallback,
    since `RenderContext` carries no capabilities; sky compile failures fall back instead of throwing; the fallback
    sky is drawn through the cache.
