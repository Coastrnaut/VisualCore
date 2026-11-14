# Infinite Geometry — release checklist and artifact inventory

Infinite Geometry (`a05.infinite-geometry`) ships inside the one VisualCore app (ADR-0009); feature 045 (A05-P06),
FR-A05-620. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). Statuses:

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A05-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A05-P06 is sealed) or a sealed earlier phase
  (`.autonomy/evidence/A05-P0N.json`);
- `pending-campaign-ii`: needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`
  ([device-campaign.md](device-campaign.md));
- `owner-action`: done by the owner only, steps in [build-and-archive.md](../../release/build-and-archive.md) section 5
  (`BLOCKED_OWNER_ACTION` until done).

`scripts/check_experience_release.py --config docs/apps/infinite-geometry/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| No permission, no network, tracking, advertising or sensor framework in the experience's sources | Privacy | verified | `.autonomy/checks/A05-P06.ig-no-network.json` (T-A05-603); [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A05-P06.release-checks.json` (`app-privacy-manifest`); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A05-P06.release-checks.json` (`app-no-tracking`) |
| Usage strings: the experience adds none; the app keeps only the declared ones | Privacy | verified | `.autonomy/checks/A05-P06.release-checks.json` (`app-usage-descriptions`) |
| Exported pictures: PNG held in memory, no metadata, no file written, passed on only through the share sheet | Privacy | verified | `.autonomy/checks/A05-P06.experiences-ios27.json` (`GeometryExportTests`); `.autonomy/evidence/A05-P04.json`; [privacy-and-credits.md](privacy-and-credits.md) |
| Licenses and acknowledgements: no third-party code or non-code assets in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A05-P06.release-checks.json` (`app-licenses`); [privacy-and-credits.md](privacy-and-credits.md) |
| Saved-composition migration: committed library fixtures (format 1, newer format, newer document version, damaged, no format) load as specified; newer files refused and kept | Data | verified | `.autonomy/checks/A05-P06.experiences-ios27.json` (`GeometryLibraryMigrationTests`); `.autonomy/evidence/A05-P04.json` |
| Drawing-failure recovery: failure state, saved compositions byte-identical, a new session opens and draws | Recovery | verified | `.autonomy/checks/A05-P06.experiences-ios27.json` (`GeometryRecoveryTests`) |
| VoiceOver: the canvas has a spoken description that follows the composition; every control has a label | Accessibility | verified | `.autonomy/checks/A05-P06.experiences-ios27.json` (`GeometryOrbitViewTests.theCanvasDescriptionStatesTheFieldOfViewOnTheSolid`); `.autonomy/checks/A05-P06.app-ui.json` (`IGControlsUITests`, chunk k2) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | Run with `VC_RUN_AUDITS=1` in [device-campaign.md](device-campaign.md); deferred by owner ruling of 2026-11-13 |
| Dynamic Type at the largest accessibility size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md); controls use text styles and wrap (`GeometryControls.swift`) |
| ExperiencesCreative package suites on the iOS 27 simulator (sim-27.2; iOS 26 at X-A05 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A05-P06.baseline.json`, `.autonomy/checks/A05-P06.experiences-ios27.json` |
| Interface chunk k2: open, presets, symmetry order, view buttons, description; save, choose another preset, reopen, export | Tests | verified | `.autonomy/checks/A05-P06.app-ui.json` (`app-ui-ios27-k2`: `IGControlsUITests`, `IGLibraryExportUITests`, iOS 27.2 phone simulator) |
| Experience runner on iOS 27 | Tests | verified | `.autonomy/checks/A05-P06.verify-27.json` |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A05-P06.release-checks.json` |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A05-P06.script-tests.json` |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings | Store | verified | `.autonomy/checks/A05-P06.copy-claims.json` (`Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A05-P06.experience-release.json` |
| Store text input describing only implemented and tested features | Store | verified | [store-listing.md](store-listing.md); `.autonomy/checks/A05-P06.copy-claims.json` |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A05-P06.release-checks.json` |
| Frame time per quality tier for every preset kind, the governor's settled tier, memory with the mesh cache full, thermal state, export time on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md); no number is claimed before device evidence |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 |
| App Store Connect: record, App Privacy answers, the one USD 1.99 non-consumable, store text, screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5 to 9 |
