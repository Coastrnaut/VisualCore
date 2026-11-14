# Particle Universe — release checklist and artifact inventory

Particle Universe (`a04.particle-universe`) ships inside the one VisualCore app (ADR-0009); feature 038 (A04-P06),
FR-A04-630. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). Statuses:

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A04-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A04-P06 is sealed) or a sealed earlier phase
  (`.autonomy/evidence/A04-P0N.json`);
- `pending-campaign-ii`: needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`
  ([device-campaign.md](device-campaign.md));
- `owner-action`: done by the owner only, steps in [build-and-archive.md](../../release/build-and-archive.md) section 5
  (`BLOCKED_OWNER_ACTION` until done).

`scripts/check_experience_release.py --config docs/apps/particle-universe/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| No permission, no network, tracking, advertising or sensor framework in the experience's sources | Privacy | verified | `.autonomy/checks/A04-P06.pu-no-network.json` (T-A04-604); [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A04-P06.release-checks.json` (`app-privacy-manifest`); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A04-P06.release-checks.json` (`app-no-tracking`) |
| Usage strings: the experience adds none; the app keeps only the declared ones | Privacy | verified | `.autonomy/checks/A04-P06.release-checks.json` (`app-usage-descriptions`) |
| Licenses and acknowledgements: no third-party code or non-code assets in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A04-P06.release-checks.json` (`app-licenses`); [privacy-and-credits.md](privacy-and-credits.md) |
| Saved-scene migration: committed library fixtures (no format, format 1, newer format, damaged) load as specified; scene document v1 migrates, newer is refused and kept | Data | verified | `.autonomy/checks/A04-P06.experiences-ios27.json`, `.autonomy/checks/A04-P06.experiences-ios26.json` (`ParticleLibraryMigrationTests`); `.autonomy/evidence/A04-P04.json` |
| Drawing-failure recovery: failure state, saved scenes unchanged, retry runs again | Recovery | verified | `.autonomy/checks/A04-P06.experiences-ios27.json`, `.autonomy/checks/A04-P06.experiences-ios26.json` (`ParticleRecoveryTests`) |
| Reduce Motion: the experience starts paused in the one app | Accessibility | verified | `.autonomy/checks/A04-P06.ui-pu-j2-r2.json` (`PUSandboxUITests.testReduceMotionStartsPaused`) |
| Reduce Flashing: brightness capped in the hosted session; trails keep working | Accessibility | verified | `.autonomy/checks/A04-P06.experiences-ios27.json` (`ParticleRecoveryTests`); `.autonomy/checks/A04-P06.ui-pu-j3.json` (`PUTrailUITests.testTrailsWorkUnderReduceFlashing`) |
| VoiceOver: the canvas has a spoken summary that follows the scene; the family choices carry their labels | Accessibility | verified | `.autonomy/checks/A04-P06.ui-pu-j2-r2.json` (`PUSandboxUITests.testOpenFromTheCatalogShowsTheDescribedCanvas`, `testEveryFamilyIsSelectableAndDescribed`) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | `PUAccessibilityAuditUITests` (`VC_RUN_AUDITS=1`) in [device-campaign.md](device-campaign.md); deferred by owner ruling of 2026-11-13 |
| Dynamic Type at the largest accessibility size | Accessibility | pending-campaign-ii | `PUAccessibilityAuditUITests.testAuditLargestAccessibilityTextSize` in [device-campaign.md](device-campaign.md); controls use text styles (`ParticleControls.swift`) |
| ExperiencesCreative package suites on both simulator runtimes (sim-27.2, sim-26.5) | Tests | verified | `.autonomy/checks/A04-P06.experiences-ios27.json`, `.autonomy/checks/A04-P06.experiences-ios26.json` |
| Interface chunk j2: sandbox, families, live count, pause, step and new seed, background round trip, Reduce Motion | Tests | verified | `.autonomy/checks/A04-P06.ui-pu-j2-r2.json` (`app-ui-ios27-j2`, iOS 27.2 phone simulator) |
| Interface chunk j3: emitters, placed force, trails | Tests | verified | `.autonomy/checks/A04-P06.ui-pu-j3.json` (`app-ui-ios27-j3`, iOS 27.2 phone simulator) |
| Interface chunk j4: saved scenes library | Tests | verified | `.autonomy/checks/A04-P06.ui-pu-j4.json` (`app-ui-ios27-j4`, iOS 27.2 phone simulator) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A04-P06.release-checks.json` |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A04-P06.script-tests.json` |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings | Store | verified | `.autonomy/checks/A04-P06.copy-claims.json` (`Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A04-P06.experience-release.json` |
| Store text input describing only implemented and tested features | Store | verified | [store-listing.md](store-listing.md); `.autonomy/checks/A04-P06.copy-claims.json` |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A04-P06.release-checks.json` |
| Frame pacing, drawn-detail steps under load, thermal behaviour, memory and launch on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md); no number is claimed before device evidence |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 |
| App Store Connect: record, App Privacy answers, the one USD 1.99 non-consumable, store text, screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5 to 9 |
