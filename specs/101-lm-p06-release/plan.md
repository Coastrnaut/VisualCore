# Implementation Plan: Light Maze — Phase 06 Final verification, privacy, packaging and release

**Branch**: `101-lm-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness of Light Maze inside the one app, following A12-P06: the privacy and credits note, a source scan, the
store text input with its claim → test table and Light Maze's own refused-word scan, the release checklist with the
artifact inventory, `release.json` for the shared release-document and copy checks, the device-campaign plan and
known limitations; a test-only `failNextDraw` seam with a recovery test and four committed sample progress files; two
interface test classes in a new serial chunk `u2`; and the release build checks. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). Contract: [contracts/release-config.md](contracts/release-config.md).

## Technical Context

**Language**: Swift 6, Python 3, shell. **Dependencies** (verified in the clarification session):
`scripts/check_experience_release.py` (release.json schema 1), `scripts/release_check.py` (`experience-release-<code>`,
`copy-claims-<code>`, `UI_CHUNKS`, `SERIAL_CHUNKS`, the `app-release-*` steps), `ProgressStore.load()` and its refusals,
`MazePresenter.draw`, Tiny Worlds' `failNextDraw` and `TWSupport` as models, `MazeCore.schemaOneExample()`.
**Storage**: none new. **Testing**: ExperiencesCreative on sim-27.2; app build, unit and chunk `u2`; runner iOS 27;
release checks; script tests. **Constraints**: interface tests < 60 s each; package tests < 10 s; no device runs.

## Constitution Check

I PASS (one app; no per-app listing) · II PASS · III PASS (no imported art or sound) · IV PASS · V PASS (schema-1
example re-run; sample files) · VI PASS · VII PASS (accessibility facts listed; audits deferred to devices) · VIII PASS
(no permission, nothing sent; privacy note) · IX PASS · X PASS (owner steps BLOCKED_OWNER_ACTION; device rows pending)
· XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
docs/apps/light-maze/{privacy-and-credits.md,store-listing.md,release-checklist.md,device-campaign.md,release.json} new
docs/apps/light-maze/README.md (links), docs/release/known-limitations.md (A13 section)                         modify
specs/101-lm-p06-release/scan-claims-release.sh                                                                new
Packages/ExperiencesCreative/LightMaze/Experience/MazePresenter.swift (test-only failNextDraw)                   modify
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeRecoveryDrawTests,ProgressSampleFileTests}.swift    new
Packages/ExperiencesCreative/LightMaze/ExperienceTests/Fixtures/progress-{valid,newer,damaged,truncated}.json    new
Packages/ExperiencesCreative/Package.swift (LightMazeExperienceTests resources: [.copy("Fixtures")])             modify
Apps/VisualCore/Tests/UI/LightMaze/{LMSupport,LMLevelUITests,LMHelpUITests}.swift                              new
scripts/release_check.py (chunk "u2", serial)                                                                  modify
project.yml (only if the UI test folder must be listed; xcodegen generate)                                      check
```

**Dependency direction**: unchanged. **Lifecycle**: `failNextDraw` (internal, test-only) makes the next `draw` throw
once, so the host enters its failure state; nothing else changes. **Migration**: none (the schema-1 example re-run).
**Rollback**: revert the commits.

## Parallel work

Agent A: the five documents and `scan-claims-release.sh`. Agent B: fixtures + `ProgressSampleFileTests`. Agent C: the
interface tests. Lead: `failNextDraw` + `MazeRecoveryDrawTests`, Package.swift, release_check.py chunk, runs, commits.
