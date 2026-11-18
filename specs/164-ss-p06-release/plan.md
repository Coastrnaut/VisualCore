# Implementation Plan: Shader Studio — Phase 06 Final verification, privacy, packaging and release

**Branch**: `164-ss-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-RELEASE with documents, scans, a recovery seam, stored samples and a release journey:
- **Documents:** `docs/apps/shader-studio/{privacy-and-credits,store-listing,release-checklist}.md` and `release.json`;
  an A22 section in `docs/release/known-limitations.md`.
- **Scans:** `specs/164-ss-p06-release/{scan-sources-release,scan-claims-release}.sh`.
- **Recovery:** a test-only `failNextDraw` seam and `StudioRecoveryDrawTests`.
- **Samples:** committed fixtures in `ExperienceTests/Fixtures/` and `StoredSampleTests`.
- **Interface:** `SSReleaseUITests` in chunk `d3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, shell, Markdown and JSON.
- **Dependencies:** unchanged. The release steps of `scripts/release_check.py` (`experience-release-<n>`,
  `copy-claims-<n>`, `release-build`) read `docs/apps/<slug>/release.json`, as for A21.
- **Testing:**
  - Shader Studio tests on sim-27.2;
  - the app build, unit tests and chunk `d3`;
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
| X | PASS: the licence inventory is complete; everything is made in code |
| XI, XII | PASS: an experience in the one app; no purchase or advertising change |
| A22 (2.18.1) | PASS: the copy says GPU code is not a sandbox |

Post-design: PASS.

## Project Structure

```text
docs/apps/shader-studio/{privacy-and-credits,store-listing,release-checklist}.md, release.json   new
docs/release/known-limitations.md                                                                modify  A22 section
specs/164-ss-p06-release/{scan-sources-release,scan-claims-release}.sh                           new
Packages/ExperiencesCreative/ShaderStudio/Experience/StudioPresenter.swift                       modify  failNextDraw seam
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{StudioRecoveryDrawTests,StoredSampleTests}.swift new
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/Fixtures/*.json                        new     samples
Packages/ExperiencesCreative/Package.swift                                                       modify  test resources (if needed)
Apps/VisualCore/Tests/UI/ShaderStudio/SSReleaseUITests.swift; scripts/release_check.py (d3)      new/modify
docs/apps/shader-studio/visualcore-contract.json                                                 modify  G-RELEASE
```

- **Dependency direction:** unchanged.
- **Lifecycle:** the seam is internal and test-only. It throws once and clears itself.
- **Migration:** none. The samples are generated once through the real encoders and then committed.
- **Rollback:** revert the commits.

## Parallel work

- **Agent R:** the release documents and release.json (new files).
- **Agent K:** the two scan scripts.
- **Agent E:** the seam, `StudioRecoveryDrawTests`, the samples and `StoredSampleTests`.
- **Agent U:** `SSReleaseUITests`.
- **Lead:** `release_check.py`, known-limitations, contract, runs and commits.
