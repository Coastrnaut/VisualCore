# Data model: A18-P06 (feature 136)

- **`release.json`:** the release checker's schema 1:
  - `experience` a18.ambient-clock;
  - `requiredDocs`: the privacy, store, checklist, campaign, licenses and contract pages, plus
    `docs/release/build-and-archive.md`;
  - `checklist`;
  - `copyCheck` with `text` (the store listing) and `swift` (the controls, overlay, presenter and the adapter's core).
- **Checklist row:** item | status (verified, pending-campaign-ii, owner-action) | evidence.
- **Presenter seam:** `var failNextDraw = false`. The next `draw` throws `AmbientDrawError.injected` once and clears
  the flag.
- **Samples:**
  - the snapshot payloads are the schema examples' payloads, plus a schema 4 and a damaged one;
  - the favourites files are the envelope of A18-P03, a schema 2 one and a damaged one.
