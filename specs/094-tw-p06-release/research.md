# Research: A12-P06 Final verification, privacy, packaging and release

Facts verified on 2026-11-15 (clarification session): release-document check and statuses; derived release steps;
shared copy denylist; no failure seam yet in `WorldsPresenter`; no committed sample world files; no permission in the
a12 registration; control identifiers.

## D1 — Documents

- **Decision**: as Physics Playground's (A11-P06): `privacy-and-credits.md` (stored: `world-0…3.json` — the saved
  worlds' names, presets, seeds, props, light and view, no personal data — and `world-0…3.png` thumbnails in the
  experience's folder, and the app's session state; nothing sent; no permission; how to delete: Clear on a slot, the
  app's Settings reset of the experience's data, or removing the app; credits from `content-licenses.md`: 3 presets,
  3 palettes, 4 props, 4 prop palettes, 3 packs, all original, MIT), `store-listing.md` (text plus a table claim →
  proving test), `release-checklist.md` (Item | Area | Status | Evidence; statuses `verified`, `pending-campaign-ii`,
  `owner-action`; artifact inventory; accessibility rows), `release.json` (schema 1; required documents; checklist; copy
  check over the store text and `WorldsControls.swift` and `WorldsPresenter.swift`, `allow` empty).
- **Rationale**: the shared checker already validates this shape; the precedent passed.

## D2 — Scans

- **Decision**: source scan as a `run-check` with `grep -rnE` over the experience (Clarifications Q3); refused-words
  scan `specs/094-tw-p06-release/scan-claims-release.sh` (the A12-P05 words, whole-word, case-insensitive) over the
  store text and the interface Swift, and every test named in the store claim table must exist; exit 1 on a hit.

## D3 — Recovery and samples

- **Decision**: `WorldsPresenter.failNextDraw` (internal var; the next `draw` throws `ExperienceError` once and clears
  the flag), `WorldsRecoveryDrawTests` (a world saved to slot 0 in a temporary storage, the flag set, one frame puts the
  session into its failure state, `world-0.json` and `world-0.png` byte-identical, a new session draws; the schema-1
  example restores). `WorldSampleFileTests` over `Fixtures/world-{valid,newer,damaged,truncated}.json` copied as
  `world-0.json` into a temporary storage: valid opens (state equal to its document, digest stable), newer →
  `newer-version`, damaged (not JSON) → `damaged`, truncated (valid cut in half) → `damaged`; each file byte-identical
  after the read; a lone `world-0.png` leaves slot 0's status "Empty." and the valid sample without a picture reads "Holds “<name>”,
  no picture.".

## D4 — Interface tests

- **Decision**: `TWSupport` (namespace `TW`, identifiers `experience.a12.tiny-worlds.<name>`, candidate launch as
  `PPSupport`); `TWWorldUITests` (choose and open the asteroid garden pack, the status names it; turn left and zoom in
  change their spoken values; reset view), `TWEditUITests` (place raises "N of 24 props"; the light azimuth slider moves;
  save to slot 0 shows its status and picture); chunk `"t2": ["TWWorldUITests", "TWEditUITests"]` (serial: the world
  draws every frame, as Physics Playground).
