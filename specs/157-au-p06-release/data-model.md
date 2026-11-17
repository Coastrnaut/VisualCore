# Data model: A21-P06 (feature 157)

- **`release.json`:** the release checker's schema 1:
  - `experience` a21.aurora;
  - `requiredDocs`: the privacy, store, checklist, campaign, licenses and contract pages, plus
    `docs/release/build-and-archive.md`;
  - `checklist`;
  - `copyCheck` with `text` (the store listing), `swift` (`AuroraControls.swift`, `AuroraPresenter.swift`,
    `Adapter/AuroraCore.swift`, `SkySound.swift`) and `allow` `[]`.
- **Checklist row:** item | status (verified, pending-campaign-ii, owner-action) | evidence.
- **Presenter seam:** `var failNextDraw = false`. The next `draw` throws `SkyDrawError.injected` once and clears the
  flag.
- **Samples:**
  - the snapshot payloads: the schema-1 example, a schema 2 one and a damaged one;
  - the preferences: the `a21.preferences` envelope at schema 1 (a non-default preset, sound on, volume 0.4), at
    schema 2, a damaged one and an out-of-range one.
