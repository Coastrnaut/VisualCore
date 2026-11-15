# Implementation Plan: Solar System Explorer — Phase 06 Final verification, privacy, packaging and release

**Branch**: `108-sse-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness with no VisualCore change: a privacy and credits note, a source scan and the release build checks
(privacy manifest, no tracking, licences, usage descriptions); a test-only `failNextDraw` seam and a recovery test that
keeps `view.json` byte-identical; four committed sample saved views answered by `ViewStore`; stored schema 1–3
examples (`SolarCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()`) passed to the candidate
registration; release documents (store listing with claim → test table, release checklist, `release.json`), the copy
claim checks and an experience word scan; known limitations; app interface tests in a new serial chunk `v2`
(`SSEViewUITests`, `SSETourUITests` through `SSESupport`). Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/release.md](contracts/release.md).

## Technical Context

**Language**: Swift 6, Python 3 (scan script). **Dependencies** (verified during clarification):
`check_experience_release.py` (release.json schema 1, statuses `verified`, `pending-campaign-ii`, `owner-action`),
`check_copy_claims.py` with `Configs/copy-claims-denylist.json`, `release_check.py` (derived steps, interface chunks,
`SERIAL_CHUNKS`), `ViewStore` refusals, `ExperienceRegistration(examples:)` with `MigrationExample`
(`MazeCore.schemaOneExample()` precedent), the session failure state. **Storage**: `view.json` only. **Testing**: SSE
package tests on sim-27.2; app build, unit and the `v2` interface chunk on iOS 27; runner iOS 27; release build checks;
release-document and copy-claim checks; scan scripts; script tests. **Constraints**: tests < 10 s, interface tests
< 60 s; iOS 27 only; reference regression and iOS 26 at X-A14. No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (release tools reused) · II-a N/A · III PASS (no assets) · IV PASS (recovery, samples and examples
tested) · V PASS (schema 1–3 examples restore in schema 4; refused files untouched) · VI PASS (claims only with tests;
device rows pending) · VII PASS (accessibility facts listed; audits pending for devices) · VIII PASS (no permission, no
network, scan proves it) · IX PASS · X PASS (owner steps BLOCKED_OWNER_ACTION) · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
docs/apps/solar-system-explorer/{privacy-and-credits.md, store-listing.md, release-checklist.md, release.json}  new
docs/release/known-limitations.md (Solar System Explorer section)                                              modify
specs/108-sse-p06-release/{scan-claims-release.sh, scan-sources-release.sh}                                     new
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{SolarPresenter (failNextDraw),
  Adapter/SolarCore (schema examples)}.swift                                                                    modify
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/{SolarRecoveryDrawTests,SavedViewSampleTests,
  SolarSchemaExampleTests}.swift; ExperienceTests/Fixtures/view-{valid,newer,damaged,oversized}.json            new
Packages/ExperiencesCreative/Package.swift (ExperienceTests resources: Fixtures)                                modify
Apps/VisualCore/App/ExperienceRegistry.swift (a14 examples)                                                     modify
Apps/VisualCore/Tests/UI/SolarSystemExplorer/{SSESupport,SSEViewUITests,SSETourUITests}.swift                   new
scripts/release_check.py (chunk "v2", serial)                                                                    modify
```

**Lifecycle**: unchanged; the seam throws once from `draw` and clears itself (test builds only through `@testable`
access). **Migration**: none new; examples prove 1 → 4. **Rollback**: revert the commits.

## Parallel work

Agent A: release documents and the two scan scripts. Agent B: the interface tests (`SSESupport`, two suites). Lead:
seam, samples, examples, registry, Package.swift, release_check chunk, runs.

## Evidence

`run-check --stage A14-P06`: `sse-no-network` (source scan), `sse-claims` (word scan), `sse-ios27`, `app-ui` (build,
unit, `app-ui-ios27-v2`), `verify-27`, `release-checks` (`app-release-build app-release-symbols app-privacy-manifest
app-no-tracking app-licenses app-usage-descriptions experience-release-a14 copy-claims-a14`), `script-tests`.
