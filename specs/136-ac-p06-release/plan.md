# Implementation Plan: Ambient Clock — Phase 06 Final verification, privacy, packaging and release

**Branch**: `136-ac-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-RELEASE:
- **Documents:** privacy and credits, store listing with proving tests, release checklist, `release.json` and the A18
  section of `docs/release/known-limitations.md`.
- **Two scans:** the source scan (no network, sensor or brightness; the idle timer in one named file) and the claims
  scan.
- **Crash recovery:** a `failNextDraw` seam, with favourites unchanged.
- **Committed samples:** of the snapshot and of the favourites file.
- **Interface journey:** `ACThemeUITests` in chunk `z2`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, POSIX shell for the two scans, and the existing Python release checks.
- **Testing:**
  - `AmbientClockExperienceTests` (recovery, samples) on sim-27.2;
  - chunk `z2` on the iOS 27.2 phone;
  - `release_check.py --only experience-release-a18 copy-claims-a18` and the app release steps.
- **Constraints:** no signing, archive or upload. iOS 27 only; iOS 26 and the reference regression at X-A18. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| VIII Privacy | PASS: no permission, nothing sent, keep-awake opt-in and disclosed, brightness never written |
| IX Accessibility | PASS: interface tests; audits wait for devices (owner ruling of 2026-11-13) |
| XI Release | PASS: checklist rows verified, pending-campaign-ii or owner-action; no fabricated measurement |
| X–XIII | PASS: documented API; no VisualCore change |

Post-design: PASS.

## Project Structure

```text
docs/apps/ambient-clock/{privacy-and-credits,store-listing,release-checklist}.md, release.json                   new
docs/release/known-limitations.md (A18 section)                                                                 modify
specs/136-ac-p06-release/{scan-sources-release,scan-claims-release}.sh                                          new
Packages/ExperiencesCreative/AmbientClock/Experience/AmbientPresenter.swift (failNextDraw)                      modify
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{AmbientRecoveryDrawTests,StoredSampleTests}.swift     new
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/Fixtures/{snapshot-v1,v2,v3,newer,damaged,
  favourites-current,newer,damaged}.json                                                                        new
Packages/ExperiencesCreative/Package.swift (Fixtures resource of the experience tests)                          modify
Apps/VisualCore/Tests/UI/AmbientClock/ACThemeUITests.swift; scripts/release_check.py (z2 adds ACThemeUITests)    new/modify
docs/apps/ambient-clock/visualcore-contract.json (G-RELEASE closed)                                             modify
```

- **Migration:** none.
- **Rollback:** revert the commits.

## Parallel work

- **Agent D:** the documents.
- **Agent K:** the seam, the fixtures and the tests.
- **Agent U:** the interface journey.
- **Lead:** the two scans, Package.swift, release_check.py, the runs, the contract and the commits.
