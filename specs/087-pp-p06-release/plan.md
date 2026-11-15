# Implementation Plan: Physics Playground — Phase 06 Final verification, privacy, packaging and release

**Branch**: `087-pp-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness without new physics: privacy and credits note, store text with a claim → test table, release
checklist with artifact inventory and accessibility rows, `release.json` for the shared release checks, known
limitations, a source scan and a refused-words scan over store text and interface Swift, a crash-recovery test and the
re-run sample-file and migration tests, the first interface chunk `s2` (`PPSupport`, `PPWorldUITests`,
`PPExperimentUITests`), and the release build checks. Owner and device items stay open. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/release-config.md](contracts/release-config.md).

## Technical Context

**Language**: Markdown, JSON, POSIX shell, Swift 6 (tests). **Dependencies**: `scripts/check_experience_release.py`,
`scripts/release_check.py` (`experience-release-a11`, `copy-claims-a11`, chunk `s2`), `Configs/copy-claims-denylist.json`,
`ExperienceShell`, `ExperimentStore`, `PlaygroundPresenter.failNextDraw`, XCUITest with `AppUITestSupport`.
**Storage**: none new. **Testing**: package tests on sim-27.2; app build, unit and chunk `s2` (serial); runner iOS 27;
release checks; scans; script tests. **Constraints**: interface tests < 60 s each; iOS 27 only; no NEEDS CLARIFICATION.

## Constitution Check

I PASS · II PASS (shared release checks reused) · III PASS (crash recovery through the host) · IV PASS · V PASS
(migration examples re-run) · VI PASS (checks with evidence) · VII PASS (interface tests through accessibility
identifiers; checklist accessibility rows) · VIII PASS (privacy note; source scan) · IX PASS · X PASS (credits from
`content-licenses.md`) · XI PASS (no per-app listing) · XII–XIII PASS. A11 rules: truthful claims (scans), offline and
private — PASS. Post-design: PASS.

## Project Structure

```text
docs/apps/physics-playground/{privacy-and-credits.md,store-listing.md,release-checklist.md,release.json}      new
docs/apps/physics-playground/README.md (links), docs/release/known-limitations.md (A11 section)                modify
specs/087-pp-p06-release/scan-claims-release.sh                                                              new
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/PlaygroundRecoveryDrawTests.swift              new
Apps/VisualCore/Tests/UI/PhysicsPlayground/{PPSupport,PPWorldUITests,PPExperimentUITests}.swift               new
scripts/release_check.py (chunk "s2", serial)                                                                modify
project.yml (only if the UI test folder must be listed; xcodegen generate)                                    check
```

**Lifecycle**: unchanged. **Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent A: the four documents and the known-limitations section. Agent B: the UI test files. Agent C: the recovery test.
Lead: release.json review, scans, chunk wiring, runs, ticks, commits.
