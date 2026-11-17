# Data model: A18-P03 (feature 133)

## VisualCoreRendering

- `public final class CrossfadeScene: RenderScene`:
  - `init(from: RenderScene, to: RenderScene)`;
  - `var progress: Double` (clamped 0…1);
  - `setup` makes two `RenderTarget`s of the drawable size;
  - `resize` remakes them;
  - `render` draws `from` into target A and `to` into target B through `context.redirected(to:width:height:)`, then
    mixes them with `mix(a, b, progress)` into `context.framebuffer`;
  - `teardown` releases the targets and the mix program;
  - `replaceIncoming(_:)` and `captureOutgoingFromMix()` restart a fade from the current mix.

## AmbientClockCore

- **`ThemePreset`:**
  - fields `theme` (0–3), `palette` (0–2), `speed` (0.25–2) and `motion` (Bool);
  - kind `a18.theme-preset`, schema 1, at most 4,096 bytes, sorted keys;
  - refusals `damaged`, `newer-version`, `too-large` and `out-of-range`, each with a sentence.
- **`ThemeCatalog`:**
  - `themes` has 4 entries, each with an id, a name, three palettes of four sRGB colours, and a count per level
    (noise octaves 5/3, particle cells 48/24, waves 6/3, shapes 8/4);
  - `contrastProblems()` is empty when every palette colour gives white text at least 4.5 : 1;
  - `budget(theme:tier:)` gives the count for a theme at a level.

## Experience

- **`AmbientCore` schema 2:** adds `theme` (0–3) and `palette` (0–2). The controls `theme.select` [0…3] and
  `theme.palette` [0…2] are added; a theme change resets the palette to 0.
- **Migration 1 → 2:** theme 0, palette 0.
- **Favourites:** `AmbientFavourites` keeps `favourites.json` in the experience storage: kind `a18.favourites`,
  schema 1, entries with an id, a name, `createdAt` and a preset, at most 12 entries and 65,536 bytes; problems
  `damaged`, `newer-version`, `too-large` and `invalid-entry`.
  - `save(name:preset:)` normalises the name, refuses a 13th entry (`over-cap`) and a duplicate (`duplicate-name`).
  - `apply(id:port:)` sends the four controls.
  - Also `remove(id:)` (an empty list removes the file), an injectable id generator (`makeID`), the refusal
    `store-failed` (the storage error's code), and static `decode` and `encode` for tests.
- **Outcomes:** `showing-time`, `motion-off` and `theme-<id>`. The outcome is the theme when it is not the noise
  gradient.
