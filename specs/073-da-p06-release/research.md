# Research: A09-P06 Final verification, privacy, packaging and release

Facts verified on 2026-11-14 (clarification session): release-document check and statuses; derived release steps;
shared copy denylist; `failNextDraw`; no permission in the a09 registration.

## D1 — Documents

- **Decision**: as Oscilloscope Studio's (A08-P06): `privacy-and-credits.md` (stored: `aquarium-<uuid>.json` saved
  configurations in the experience's folder and the app's session state; nothing sent; no permission; credits from
  `content-licenses.md`), `store-listing.md` (text plus a table claim → proving test), `release-checklist.md` (Item |
  Area | Status | Evidence; statuses `verified`, `pending-campaign-ii`, `owner-action`; artifact inventory), and
  `release.json` (schema 1; required documents; checklist; copy check over the store text and the controls and
  presenter Swift, `allow` empty).

## D2 — Scans

- **Decision**: source scan as a `run-check` with `grep -rnE` over the experience (Clarifications Q3); realism and care
  scan as a small shell script `specs/073-da-p06-release/scan-realism.sh` (whole-word, case-insensitive) over the store
  text and the interface Swift, exit 1 on a hit.

## D3 — Samples and recovery

- **Decision**: four fixtures (valid, newer, damaged, mismatched name) under `ExperienceTests/Fixtures`, the test copies
  them into a temporary `ExperienceStorage` and builds an `AquariumLibrary`; recovery: a saved configuration, then
  `failNextDraw`, a drawn frame puts the session into its failure state; files byte-identical; a new session draws.

## D4 — Interface tests

- **Decision**: `DASupport` modelled on `OSSupport` (namespace `DA`, identifiers `experience.a09.digital-aquarium.<name>`,
  candidate launch); chunk `"q2": ["DAAquariumUITests", "DALibraryUITests"]` in `SERIAL_CHUNKS`.
