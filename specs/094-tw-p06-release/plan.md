# Implementation Plan: Tiny Worlds — Phase 06 Final verification, privacy, packaging and release

**Branch**: `094-tw-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness without new world features: privacy and credits note, store text with a claim → test table, release
checklist with artifact inventory and accessibility rows, `release.json` for the shared release checks, the A12 section
of the known limitations, a source scan and a refused-words scan over store text and interface Swift, a test-only
`failNextDraw` seam with a crash-recovery test, four committed sample world files with their test, the re-run schema-1
migration, the interface chunk `t2` (`TWSupport`, `TWWorldUITests`, `TWEditUITests`), and the release build checks.
Owner and device items stay open. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
Contract: [contracts/release-config.md](contracts/release-config.md).

## Technical Context

**Language**: Markdown, JSON, POSIX shell, Swift 6 (tests and one test-only seam). **Dependencies**:
`scripts/check_experience_release.py`, `scripts/release_check.py` (`experience-release-a12`, `copy-claims-a12`, chunk
`t2`), `Configs/copy-claims-denylist.json`, `ExperienceShell`, `WorldStore` (`world-<slot>.json`, `world-<slot>.png`,
refusals `damaged`, `newer-version`, `too-large`), `WorldDocument`, `WorldsCore.schemaOneExample()`, XCUITest with
`AppUITestSupport`. **Storage**: none new. **Testing**: package tests on sim-27.2; app build, unit and chunk `t2`
(serial); runner iOS 27; release checks; scans; script tests. **Constraints**: interface tests < 60 s each; iOS 27 only;
no NEEDS CLARIFICATION.

## Constitution Check

I PASS · II PASS (shared release checks reused) · III PASS (crash recovery through the host's failure state) · IV PASS ·
V PASS (sample files and the schema-1 example) · VI PASS (checks with evidence) · VII PASS (interface tests through
accessibility identifiers; checklist accessibility rows) · VIII PASS (privacy note; source scan) · IX PASS · X PASS
(credits from `content-licenses.md`) · XI PASS (no per-app listing) · XII–XIII PASS. A12 rules: truthful claims (scans),
offline and private — PASS. Post-design: PASS.

## Project Structure

```text
docs/apps/tiny-worlds/{privacy-and-credits.md,store-listing.md,release-checklist.md,release.json}             new
docs/apps/tiny-worlds/README.md (links), docs/release/known-limitations.md (A12 section)                       modify
specs/094-tw-p06-release/scan-claims-release.sh                                                              new
Packages/ExperiencesCreative/TinyWorlds/Experience/WorldsPresenter.swift (test-only failNextDraw)             modify
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsRecoveryDrawTests,WorldSampleFileTests}.swift  new
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/Fixtures/{world-valid,world-newer,world-damaged,
  world-truncated}.json                                                                                       new
Packages/ExperiencesCreative/Package.swift (TinyWorldsExperienceTests resources: [.copy("Fixtures")])          modify
Apps/VisualCore/Tests/UI/TinyWorlds/{TWSupport,TWWorldUITests,TWEditUITests}.swift                            new
scripts/release_check.py (chunk "t2", serial)                                                                modify
project.yml (only if the UI test folder must be listed; xcodegen generate)                                    check
```

**Dependency direction**: unchanged. **Lifecycle**: `failNextDraw` (internal, test-only) makes the next `draw` throw
once, so the host enters its failure state; nothing else changes. **Migration**: none (the schema-1 example re-run).
**Rollback**: revert the commits.

## Parallel work

Agent A: the four documents and the known-limitations section. Agent B: the UI test files. Agent C: the sample files,
their test and the recovery test (the presenter seam by the lead). Lead: seam, Package.swift, release.json review,
scans, chunk wiring, runs, ticks, commits.
