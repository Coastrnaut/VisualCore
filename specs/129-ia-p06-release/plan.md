# Implementation Plan: Interactive Anatomy — Phase 06 Final verification, privacy, packaging and release

**Branch**: `129-ia-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-RELEASE with no VisualCore change. It follows the A16-P06 pattern.

- **Documents** in `docs/apps/interactive-anatomy/`: `privacy-and-credits.md`, `store-listing.md` (claims with
  proving tests), `release-checklist.md`, `release.json`, plus an A17 section in `docs/release/known-limitations.md`.
- **Scans:** `scan-sources-release.sh` and `scan-claims-release.sh` in this spec directory.
- **Code:**
  - a test-only `failNextDraw` seam in the presenter;
  - `ExperienceTests/AnatomyRecoveryDrawTests.swift`;
  - committed view sample files under `ExperienceTests/Fixtures`, with `StoredViewSampleTests.swift`;
  - the `Fixtures` resource of the experience tests in Package.swift.
- **Interface tests:** `Apps/VisualCore/Tests/UI/InteractiveAnatomy/{IASupport,IAExploreUITests,IASearchUITests}.swift`
  and the serial chunk `y2` in `scripts/release_check.py`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, POSIX sh and Python 3 for the checks.
- **Dependencies:** the existing ones.
- **Storage:** `view.json` (A17-P03).
- **Testing:**
  - experience package tests on sim-27.2;
  - app build, unit and interface chunk `y2` on iOS 27.2;
  - release checks: `app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses
    app-usage-descriptions experience-release-a17 copy-claims-a17`;
  - runner, packages, contract, documented API, scripts.
- **Constraints:** unit tests under 10 s, interface tests under 60 s. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I–III | PASS: no rendering change |
| IV | PASS |
| V | PASS: samples of every view schema |
| VI | PASS |
| VII | PASS: interface journeys through the list and search |
| VIII | PASS: privacy page; source scan |
| IX | PASS |
| X–XIII | PASS |

A17 rules: no medical or accuracy claim (scan), the not-reviewed and schematic labels stay: PASS. Owner actions
(signing, archive, upload, clinical review) are recorded, not done. Post-design: PASS.

## Project Structure

```text
docs/apps/interactive-anatomy/{privacy-and-credits,store-listing,release-checklist}.md, release.json      new
docs/release/known-limitations.md (A17 section)                                                          modify
specs/129-ia-p06-release/{scan-sources-release,scan-claims-release}.sh                                    new
Packages/ExperiencesCreative/InteractiveAnatomy/Experience/AnatomyPresenter.swift (failNextDraw seam)     modify
Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/{AnatomyRecoveryDrawTests,
  StoredViewSampleTests}.swift; ExperienceTests/Fixtures/view-{v2,v1,newer,damaged}.json                 new
Packages/ExperiencesCreative/Package.swift (Fixtures resource of InteractiveAnatomyExperienceTests)       modify
Apps/VisualCore/Tests/UI/InteractiveAnatomy/{IASupport,IAExploreUITests,IASearchUITests}.swift            new
scripts/release_check.py (chunk y2, serial)                                                               modify
docs/apps/interactive-anatomy/visualcore-contract.json (G-RELEASE closed)                                 modify
```

**Lifecycle:** the `failNextDraw` seam is test-only. It throws once, clears itself, and is unreachable from the
interface. **Migration:** none new. **Rollback:** revert the commits.

## Parallel work

- **Agent D:** the release documents.
- **Agent K:** the seam, recovery test, samples and sample test.
- **Agent U:** the interface tests.
- **Lead:** scans, Package.swift, release_check.py, contract, runs, commits.
