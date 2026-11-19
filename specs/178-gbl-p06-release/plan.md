# Implementation Plan: Graphics Benchmark Lab — Phase 06 Final verification, privacy, packaging and release

**Branch**: `178-gbl-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-RELEASE with documents, scans, a recovery seam, stored samples and a release journey:
- **Documents:** `docs/apps/graphics-benchmark-lab/{privacy-and-credits,store-listing,release-checklist,licenses}.md`
  and `release.json`; an A24 section in `docs/release/known-limitations.md`.
- **Scans:** `specs/178-gbl-p06-release/{scan-sources-release,scan-claims-release}.sh`.
- **Recovery:** a test-only `failNextDraw` seam in `BenchPresenter` and `BenchRecoveryDrawTests`.
- **Samples:** committed fixtures in `ExperienceTests/Fixtures/` and `ReleaseSampleTests`.
- **Interface:** `GBLReleaseUITests` in chunk `f3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, shell, Markdown and JSON.
- **Dependencies:** unchanged. The release steps of `scripts/release_check.py` (`experience-release-<code>`,
  `copy-claims-<code>`, `release-build`) read `docs/apps/<slug>/release.json`, as for A23.
- **Verified APIs (read-only audit):** `ExperienceStorage` (`write`, `read`, file listing), `ExperienceSession`
  (fails with the presenter's thrown error), `BenchCore.restore` refusals (`damaged`, `outOfRange`), `ResultLibrary`
  (`list`, `open`, read-only on a newer index), `RunDocument.decode` refusals, `TemporaryFolder`.
- **Testing:**
  - Graphics Benchmark Lab tests on sim-27.2 (`GraphicsBenchmarkLabCoreTests`, `GraphicsBenchmarkLabExperienceTests`);
  - the app build, unit tests and chunk `f3`;
  - the release checks;
  - the runner.
- **Constraints:** no new feature; no VisualCore change; no measured claim; unit tests under 10 s, interface tests
  under 60 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V | PASS: device rows stay `pending-campaign-ii`; no device run |
| VI | PASS: every claim names a test; no fabricated measurement, ranking or benchmark number |
| VIII | PASS: no network, no permission, no tracking or private identifier; an export only on the person's tap |
| IX | PASS: stored samples prove the refusals of damaged, newer and oversized files |
| X | PASS: the licence inventory is complete; every workload picture is made in code |
| XI, XII | PASS: an experience in the one app; no purchase or advertising change |
| A24 section | PASS: bounded runs, truthful claims, offline and private, results refused safely |

Post-design: PASS.

## Project Structure

```text
docs/apps/graphics-benchmark-lab/{privacy-and-credits,store-listing,release-checklist,licenses}.md, release.json  new
docs/release/known-limitations.md                                                     modify  A24 section
specs/178-gbl-p06-release/{scan-sources-release,scan-claims-release}.sh               new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/BenchPresenter.swift     modify  failNextDraw seam
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/{BenchRecoveryDrawTests,ReleaseSampleTests}.swift new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/Fixtures/*.json     new     samples
Packages/ExperiencesCreative/Package.swift                                            modify  test resources
Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab/GBLReleaseUITests.swift                 new
scripts/release_check.py                                                              modify  f3 adds GBLReleaseUITests
docs/apps/graphics-benchmark-lab/visualcore-contract.json                             modify  G-RELEASE
```

- **Dependency direction:** unchanged (the experience depends on its core and VisualCore; tests on both).
- **Lifecycle:** the seam is internal and test-only. It throws once and clears itself.
- **Migration:** none; every stored format keeps its version. The samples are generated once through the real
  encoders and then committed.
- **Rollback:** revert the commits.

## Parallel work

- **Agent R:** the release documents and release.json (new files).
- **Agent K:** the two scan scripts.
- **Agent E:** the seam, `BenchRecoveryDrawTests`, the samples and `ReleaseSampleTests`.
- **Agent U:** `GBLReleaseUITests`.
- **Lead:** `release_check.py`, `Package.swift`, known-limitations, contract, runs and commits.
