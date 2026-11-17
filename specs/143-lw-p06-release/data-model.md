# Data model: A19-P06 (feature 143)

- **`release.json`:** the release checker's schema 1:
  - `experience` a19.living-wallpapers;
  - `requiredDocs`: the privacy, store, checklist, campaign, licenses, video decision and contract pages, plus
    `docs/release/build-and-archive.md`;
  - `checklist`;
  - `copyCheck` with `text` (the store listing), `swift` (`WallpaperControls.swift`, `EditorModel.swift`,
    `HelpView.swift`, `Adapter/WallpaperCore.swift`) and `allow` `["share"]`.
- **Checklist row:** item | status (verified, pending-campaign-ii, owner-action) | evidence.
- **Presenter seam:** `var failNextDraw = false`. The next `draw` throws `WallpaperDrawError.injected` once and clears
  the flag.
- **Samples:**
  - the snapshot payloads are the schema examples' payloads (1 and 2), plus a schema 3 and a damaged one;
  - the history files are the envelope `a19.export-history` schema 1 with two entries, a schema 2 one and a damaged
    one.
