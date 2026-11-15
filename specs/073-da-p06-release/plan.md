# Implementation Plan: Digital Aquarium — Phase 06 Final verification, privacy, packaging and release

**Branch**: `073-da-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness of Digital Aquarium inside the one app, with no new feature: a privacy and credits note, a source
scan, sample saved files and a forced-failure recovery test, the store text with traced claims, a release checklist
and configuration (`release.json`, so the release-document and copy steps run for a09), a realism and care-word scan,
known limitations, an interface test chunk `q2` and the release build checks; owner and device items stay open as
recorded steps. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/release-config.md](contracts/release-config.md).

## Technical Context

**Language**: Swift 6 (tests), Markdown/JSON (documents), Python (existing checks only). **Dependencies**: the
release-document check, the shared copy check, `release_check.py` steps and UI chunks, `ExperienceStorage`,
`AquariumLibrary`, `failNextDraw` — verified in the clarification session. **Storage**: unchanged. **Testing**:
ExperiencesCreative on sim-27.2; app build, unit and interface chunk q2 (serial); runner iOS 27; release build checks;
script tests. **Constraints**: package tests < 10 s, interface tests < 60 s; iOS 27 only; no measured claims.

## Constitution Check

I PASS (no rendering change) · II PASS (documents and tests only; shared tools reused) · III PASS (forced-failure
recovery) · IV–VI PASS (tests on sim-27.2) · VII PASS (interface journeys by labelled controls; audits deferred to the
device campaign by the owner's ruling) · VIII PASS (privacy scan, note, manifest checks; no permission) · IX PASS
(sample files refused byte-identical) · X–XIII PASS (owner steps recorded, never done). Post-design: PASS.

## Project Structure

```text
docs/apps/digital-aquarium/{privacy-and-credits.md, store-listing.md, release-checklist.md, release.json}   new
docs/apps/digital-aquarium/README.md (document links)                                                        modify
docs/release/known-limitations.md (A09 section)                                                              modify
Packages/ExperiencesCreative/Package.swift (resources .copy("Fixtures") for DigitalAquariumExperienceTests)   modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/Fixtures/aquarium-*.json (4 samples)             new
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumSampleFileTests,
  AquariumRecoveryDrawTests}.swift                                                                           new
Apps/VisualCore/Tests/UI/DigitalAquarium/{DASupport,DAAquariumUITests,DALibraryUITests}.swift               new
scripts/release_check.py (chunk "q2", serial)                                                                modify
specs/073-da-p06-release/scan-realism.sh (the realism and care-word scan used by run-check)                  new
```

**Lifecycle**: unchanged. **Migration**: none (sample files exercise format 1 and newer). **Rollback**: revert.

## Build and evidence

See [quickstart.md](quickstart.md); each command runs through
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name <check> -- <command>`.

## Parallel work

Agent A: the four documents and known limitations. Agent B: sample files, sample-file and recovery tests. Agent C: the
interface tests and chunk. Lead: release.json, scans, Package.swift, runs, commits.
