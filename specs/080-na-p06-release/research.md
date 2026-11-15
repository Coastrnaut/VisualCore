# Research: A10-P06 Final verification, privacy, packaging and release

Facts verified on 2026-11-15 (clarification session): release-document check and statuses; derived release steps;
shared copy denylist; `failNextDraw`; no permission in the a10 registration.

## D1 — Documents

- **Decision**: as Digital Aquarium's (A09-P06): `privacy-and-credits.md` (stored: `high-scores.json` — at most ten scores with wave
  and run number, no personal data — in the experience's folder, and the app's session state; nothing sent; no
  permission; ambient sound only; how to delete: Settings' reset of the experience's data or removing the app; credits
  from `content-licenses.md`), `store-listing.md` (text plus a table claim → proving test), `release-checklist.md` (Item |
  Area | Status | Evidence; statuses `verified`, `pending-campaign-ii`, `owner-action`; artifact inventory), and
  `release.json` (schema 1; required documents; checklist; copy check over the store text and the controls and
  presenter Swift, `allow` empty).

## D2 — Scans

- **Decision**: source scan as a `run-check` with `grep -rnE` over the experience (Clarifications Q3); skill and ranking
  scan as a small shell script `specs/080-na-p06-release/scan-claims-release.sh` (whole-word, case-insensitive; Clarifications Q2) over the store
  text and the interface Swift, exit 1 on a hit.

## D3 — Samples and recovery

- **Decision**: four fixtures (valid, newer, damaged, truncated) under `ExperienceTests/Fixtures`; the test copies each into
  a temporary `ExperienceStorage` as `high-scores.json` and builds a `HighScoreStore`; recovery: a saved table, then
  `failNextDraw`, a drawn frame puts the session into its failure state; files byte-identical; a new session draws.

## D4 — Interface tests

- **Decision**: `NASettingsUITests` using the existing `NASupport` (namespace `NA`, identifiers
  `experience.a10.neon-arcade.<name>`, candidate launch); chunk `"r2": ["NAArcadeUITests", "NASettingsUITests"]`
  (serial).
