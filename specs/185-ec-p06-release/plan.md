# Implementation Plan: Effects Composer — Phase 06 Final verification, privacy, packaging and release

**Branch**: `185-ec-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-RELEASE with documents, scans, a recovery seam, stored samples and a release journey, after
`specs/178-gbl-p06-release`:
- **Documents:** `docs/apps/effects-composer/{privacy-and-credits,store-listing,release-checklist,licenses}.md` and
  `release.json`; an A25 section in `docs/release/known-limitations.md`; the registration's summary and capabilities.
- **Scans:** `specs/185-ec-p06-release/{scan-sources-release,scan-claims-release}.sh`.
- **Recovery:** a test-only `failNextDraw` seam in `ComposerPresenter` and `ComposerRecoveryTests`.
- **Samples:** committed fixtures in `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/Fixtures/` and
  `ReleaseSampleTests`.
- **Interface:** `ECReleaseUITests` in the new chunk `h3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, shell, Markdown and JSON.
- **Dependencies:** unchanged. `scripts/release_check.py` discovers `docs/apps/*/release.json` and builds
  `experience-release-a25` and `copy-claims-a25` from it.
- **Verified APIs (read-only audit):** `ExperienceStorage` (`write`, `read`, listing), `ExperienceSession` (fails with
  the presenter's thrown error), `ComposerCore.restore(payload:seed:)` refusals, `LookLibrary` (list, open, read only on
  a newer index), `ChainDocument.decode` refusals, `ExperienceShell`.
- **Testing:** Effects Composer tests on sim-27.2; the app build, unit tests and chunk `h3`; the release checks; the
  runner; `CatalogSearchTests` after the registration change.
- **Constraints:** no measurement claimed; no owner action performed.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no new target; one experience |
| II | PASS: no VisualCore change |
| IV | PASS: no assets; samples generated through the real encoders |
| VI (money) | PASS: no purchase or advertising copy; the tier stays free |
| VIII | PASS: privacy page; scans for network, tracking and library reads |
| IX (evidence) | PASS: device rows pending, never claimed |
| XIII | PASS: `///` on the seam; tests for every claim |

Post-design: PASS.

## Project Structure

```text
docs/apps/effects-composer/{privacy-and-credits,store-listing,release-checklist,licenses}.md   new
docs/apps/effects-composer/release.json                                                       new
docs/release/known-limitations.md                                                             modify  A25 section
Catalog/registrations.json                                                                    modify  a25 summary, capabilities
specs/185-ec-p06-release/{scan-sources-release,scan-claims-release}.sh                        new
Packages/ExperiencesCreative/EffectsComposer/Experience/ComposerPresenter.swift               modify  failNextDraw, ComposerDrawError
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ComposerRecoveryTests.swift      new
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ReleaseSampleTests.swift         new
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/Fixtures/*.json                  new     nine samples
Packages/ExperiencesCreative/Package.swift                                                    modify  test resources (Fixtures), if not yet declared
Apps/VisualCore/Tests/UI/EffectsComposer/ECReleaseUITests.swift                               new
scripts/release_check.py                                                                      modify  chunk h3
docs/apps/effects-composer/visualcore-contract.json                                           modify  G-RELEASE closed
```

- **Lifecycle:** the seam is internal and off by default; it throws once and clears itself.
- **Migration:** none; samples pin the current formats. **Rollback:** revert the commits.

## Parallel work

- **Agent D:** the four documents, `release.json`, the known-limitations section and the registration text.
- **Agent S:** the two scan scripts.
- **Agent R:** the seam, the recovery test, the samples and their tests.
- **Agent U:** `ECReleaseUITests` (the lead adds chunk `h3`).
- **Lead:** chunk wiring, runs, contract, ticks, commits.
