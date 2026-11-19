# Implementation Plan: Visual Programming Lab — Phase 06 Final verification, privacy, packaging and release

**Branch**: `171-vpl-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-RELEASE with documents, scans, a recovery seam, stored samples and a release journey:
- **Documents:** `docs/apps/visual-programming-lab/{privacy-and-credits,store-listing,release-checklist}.md` and
  `release.json`; an A23 section in `docs/release/known-limitations.md`.
- **Scans:** `specs/171-vpl-p06-release/{scan-sources-release,scan-claims-release}.sh`.
- **Recovery:** a test-only `failNextDraw` seam in `LabPresenter` and `LabRecoveryDrawTests`.
- **Samples:** committed fixtures in `ExperienceTests/Fixtures/` and `ReleaseSampleTests` (beside the A23-P04
  `StoredSampleTests`, which stays unchanged).
- **Interface:** `VPLReleaseUITests` in chunk `e3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, shell, Markdown and JSON.
- **Dependencies:** unchanged. The release steps of `scripts/release_check.py` (`experience-release-<code>`,
  `copy-claims-<code>`, `release-build`) read `docs/apps/<slug>/release.json`, as for A22.
- **Testing:**
  - Visual Programming Lab tests on sim-27.2 (`VisualProgrammingLabCoreTests`, `VisualProgrammingLabExperienceTests`);
  - the app build, unit tests and chunk `e3`;
  - the release checks;
  - the runner.
- **Constraints:** no new feature; no VisualCore change; no measured claim.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V | PASS: device rows stay `pending-campaign-ii`; no device run |
| VI | PASS: every claim names a test; no fabricated measurement |
| VIII | PASS: no network, no permission, no tracking; the privacy page and the source scan prove it |
| IX | PASS: stored samples prove the refusals of damaged, newer and oversized files |
| X | PASS: the licence inventory is complete; every operator, example and picture is made in code |
| XI, XII | PASS: an experience in the one app; no purchase or advertising change |

Post-design: PASS.

## Project Structure

```text
docs/apps/visual-programming-lab/{privacy-and-credits,store-listing,release-checklist}.md, release.json   new
docs/release/known-limitations.md                                                     modify  A23 section
specs/171-vpl-p06-release/{scan-sources-release,scan-claims-release}.sh               new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/LabPresenter.swift       modify  failNextDraw seam
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/{LabRecoveryDrawTests,ReleaseSampleTests}.swift new
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/Fixtures/*.json     new     samples
Apps/VisualCore/Tests/UI/VisualProgrammingLab/VPLReleaseUITests.swift                 new
scripts/release_check.py                                                              modify  e3 adds VPLReleaseUITests
docs/apps/visual-programming-lab/visualcore-contract.json                             modify  G-RELEASE
```

- **Dependency direction:** unchanged (the experience depends on its core and VisualCore; tests on both).
- **Lifecycle:** the seam is internal and test-only. It throws once and clears itself.
- **Migration:** none. The samples are generated once through the real encoders and then committed.
- **Rollback:** revert the commits.

## Parallel work

- **Agent R:** the release documents and release.json (new files).
- **Agent K:** the two scan scripts.
- **Agent E:** the seam, `LabRecoveryDrawTests`, the samples and `ReleaseSampleTests`.
- **Agent U:** `VPLReleaseUITests`.
- **Lead:** `release_check.py`, known-limitations, contract, runs and commits.
