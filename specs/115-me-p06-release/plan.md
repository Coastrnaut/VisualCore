# Implementation Plan: Molecular Explorer — Phase 06 Final verification, privacy, packaging and release

**Branch**: `115-me-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness for A15 with no VisualCore change, following A14-P06:
- **Documents:** privacy and credits, the store entry with a claim → test table, a release checklist with the artifact
  inventory, a device-campaign plan (ME-D1 … ME-D6), a Molecular Explorer section in the known limitations, and
  `release.json`.
- **Scans:** two scan scripts, one for sources and one for claim words.
- **Recovery:** a test-only `failNextDraw` seam with a recovery test.
- **Fixtures:** committed sample recent, settings and import files.
- **Registry:** stored schema 1–3 examples passed to the registry.
- **Interface:** an interface chunk `w2` with two suites.
- **Checks:** the release build checks.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/release.md](contracts/release.md).

## Technical Context

- **Language:** Swift 6, POSIX shell (scan scripts).
- **Dependencies** (verified during clarification):
  - `check_experience_release.py`: release.json schema 1, with the statuses `verified`, `pending-campaign-ii` and
    `owner-action`;
  - `check_copy_claims.py` with `--allow`;
  - `release_check.py`: derived `experience-release-a15` and `copy-claims-a15` steps, interface chunks, and
    `SERIAL_CHUNKS`, which reaches `v2`;
  - `RecentStore` and `SettingsStore` refusals;
  - `MoleculeImporter`;
  - `ExperienceRegistration(examples:)` with `MigrationExample` (Infinite Geometry's `schemaOneExample()` is the
    precedent);
  - the session failure state, as Solar System Explorer's `failNextDraw` uses it;
  - SwiftPM test resources, as SolarSystemExplorerExperienceTests' `Fixtures` uses them.
- **Storage:** unchanged (`recent.json`, `settings.json`, `import.xyz`, `import-title.txt`).
- **Testing:**
  - package tests on sim-27.2;
  - app build, unit tests and the `w2` interface chunk on iOS 27;
  - the runner on iOS 27;
  - the release build checks;
  - the release-document and copy-claim checks;
  - the scan scripts and the script tests.
- **Constraints:** package tests under 10 s and interface tests under 60 s; iOS 27 only; the reference regression and
  iOS 26 run at X-A15. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS |
| II | PASS: release tools reused |
| II-a | N/A |
| III | PASS: no assets |
| IV | PASS: recovery, samples and examples tested |
| V | PASS: schema 1–3 examples restore in schema 4; refused files untouched |
| VI | PASS: claims only with tests; device rows pending |
| VII | PASS: accessibility facts listed; audits pending for devices |
| VIII | PASS: no permission; only the picked file is read; the scan proves it |
| IX | PASS |
| X | PASS: owner steps are BLOCKED_OWNER_ACTION |
| XI–XIII | PASS |

Post-design: PASS.

## Project Structure

```text
docs/apps/molecular-explorer/{privacy-and-credits.md, store-listing.md, release-checklist.md, device-campaign.md,
  release.json}                                                                                                 new
docs/release/known-limitations.md (Molecular Explorer section)                                                 modify
specs/115-me-p06-release/{scan-claims-release.sh, scan-sources-release.sh}                                      new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{MoleculePresenter (failNextDraw),
  Adapter/MoleculeCore (schema examples)}.swift                                                                 modify
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{MoleculeRecoveryDrawTests,StoredFileSampleTests,
  MoleculeSchemaExampleTests}.swift; ExperienceTests/Fixtures/{recent-,settings-}{valid,newer,damaged,oversized}.json,
  import-{valid,oversized}.xyz                                                                                  new
Packages/ExperiencesCreative/Package.swift (MolecularExplorerExperienceTests resources: Fixtures)                modify
Apps/VisualCore/App/ExperienceRegistry.swift (a15 examples)                                                     modify
Apps/VisualCore/Tests/UI/MolecularExplorer/{MESupport,MEExploreUITests,MELibraryUITests}.swift                  new
scripts/release_check.py (chunk "w2", serial)                                                                    modify
```

**Lifecycle:** unchanged. The seam throws once from `draw` and clears itself; it is set only through `@testable`
access. **Migration:** none new; the examples prove 1 → 4. **Rollback:** revert the commits.

## Parallel work

- **Agent A:** release documents and the two scan scripts.
- **Agent B:** the interface tests (`MESupport` and two suites).
- **Agent C:** the seam, the samples, the examples and their tests.
- **Lead:** registry, Package.swift, the `release_check` chunk, runs and commits.

## Evidence

Each check runs as `run-check --stage A15-P06`:
- `me-no-network` (source scan) and `me-claims` (word scan);
- `me-ios27`;
- `app-ui` (build, unit and `app-ui-ios27-w2`);
- `verify-27`;
- `release-checks`: `app-release-build`, `app-release-symbols`, `app-privacy-manifest`, `app-no-tracking`,
  `app-licenses`, `app-usage-descriptions`, `experience-release-a15` and `copy-claims-a15`;
- `script-tests`.
