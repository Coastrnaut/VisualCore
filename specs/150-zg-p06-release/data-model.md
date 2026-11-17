# Data model: A20-P06 (feature 150)

- **`release.json`:** the release checker's schema 1:
  - `experience` a20.digital-zen-garden;
  - `requiredDocs`: the privacy, store, checklist, campaign, licenses and contract pages, plus
    `docs/release/build-and-archive.md`;
  - `checklist`;
  - `copyCheck` with `text` (the store listing), `swift` (`GardenControls.swift`, `GardenPresenter.swift`,
    `Adapter/GardenCore.swift`, `GardenStill.swift`) and `allow` `["share"]`.
- **Checklist row:** item | status (verified, pending-campaign-ii, owner-action) | evidence.
- **Presenter seam:** `var failNextDraw = false`. The next `draw` throws `GardenDrawError.injected` once and clears
  the flag.
- **Samples:**
  - the snapshot payloads: the schema-1 document (from a fixture garden), a schema 2 one and a damaged one;
  - the garden files: the envelope `a20.saved-garden` version 1, a version 2 one and a damaged one;
  - the index files: the envelope `a20.garden-library` version 1 naming two gardens, a version 2 one and a damaged one.
