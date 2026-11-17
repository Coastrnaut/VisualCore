# Contract: A17-P06 (feature 129)

- `docs/apps/interactive-anatomy/release.json` (schema 1): `experience` "a17.interactive-anatomy"; `requiredDocs`
  (privacy-and-credits, store-listing, release-checklist, device-campaign, review, content-sources, visualcore-contract
  .md, `docs/release/build-and-archive.md`); `checklist`; `copyCheck` {text: [store-listing.md], swift: [AnatomyControls,
  AnatomyPresenter, AnatomyOverlay, Adapter/AnatomyCore, Core/AnatomyReview], allow: ["camera"]}.
- Presenter seam: `var failNextDraw = false` (internal; the next `draw` throws `AnatomyDrawError.injected` once).
- Interface identifiers: `experience.a17.interactive-anatomy.<name>` as built in A17-P02…P05.
