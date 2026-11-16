# Implementation Plan: Simulation Lab — Phase 06 Final verification, privacy, packaging and release

**Branch**: `122-sl-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-RELEASE with no VisualCore change, following A15-P06:
- **Privacy:** `docs/apps/simulation-lab/privacy-and-credits.md`, covering:
  - what is stored and where: preset files in the experience's storage, the session state, and one capture PNG in the
    temporary folder;
  - deletion, and that nothing is sent;
  - the license inventory: six presets, three palettes and the in-code shader programs.

  A source scan `specs/122-sl-p06-release/scan-sources-release.sh` refuses the uses of clarification Q3.
- **Recovery and samples:**
  - the test-only `failNextDraw` seam in `SimulationPresenter`, with `ExperienceTests/SimulationRecoveryDrawTests.swift`;
  - fixtures `ExperienceTests/Fixtures/preset-{valid,newer,damaged,invalid}.json` and
    `state-{valid,newer,damaged}.json`, declared as a `Fixtures` resource of `SimulationLabExperienceTests` in
    `Packages/ExperiencesCreative/Package.swift`, with `ExperienceTests/StoredFileSampleTests.swift`;
  - schema examples: none, since both schemas are at version 1 (recorded).
- **Release documents** in `docs/apps/simulation-lab/`: `store-listing.md` (text and a Claim | Proving test table),
  `release-checklist.md`, `device-campaign.md` (SL-D1 … SL-D6) and `release.json`, plus a Simulation Lab section in
  `docs/release/known-limitations.md`. The claims scan `specs/122-sl-p06-release/scan-claims-release.sh` covers the
  words of Q2.
- **Interface:** `Apps/VisualCore/Tests/UI/SimulationLab/{SLSupport,SLExploreUITests,SLLibraryUITests}.swift` and the
  serial chunk `x2` in `scripts/release_check.py`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/release.md](contracts/release.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (tests, one seam), Markdown, JSON, POSIX sh.
- **Dependencies** (verified at clarify): `release.json` schema 1 read by `scripts/check_experience_release.py`;
  `release_check.py` steps `experience-release-a16`, `copy-claims-a16`, `app-release-build`, `app-release-symbols`,
  `app-privacy-manifest`, `app-no-tracking`, `app-licenses` and `app-usage-descriptions`; `SimulationPresetStore` and
  `SimulationCore.restore`; XCUITest through the app's launch arguments, as `MESupport` does.
- **Testing:** package suites on iOS 27.2; the app build, unit and chunk `x2` on the iOS 27.x phone; release checks;
  script tests.
- **Constraints:** owner-only steps are recorded, never done; device rows stay pending-campaign-ii. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| VIII Privacy | PASS: source scan and privacy document; usage descriptions unchanged |
| VI Tests | PASS: recovery, samples, interface journeys |
| VII Accessibility | PASS: method and limits shown and spoken (A16-P04 label); audits wait for devices |
| X No ads / XI–XIII | PASS: no SDK; documented seam; no VisualCore change |
| Others | PASS: no renderer, persistence-schema or core change |

Post-design: PASS.

## Project Structure

```text
docs/apps/simulation-lab/{privacy-and-credits,store-listing,release-checklist,device-campaign}.md, release.json   new
docs/release/known-limitations.md                                                                              modify
specs/122-sl-p06-release/{scan-sources-release,scan-claims-release}.sh                                         new
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift                               modify (failNextDraw)
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{SimulationRecoveryDrawTests,StoredFileSampleTests}.swift new
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/Fixtures/*.json                                     new
Packages/ExperiencesCreative/Package.swift                                                                     modify (Fixtures resource)
Apps/VisualCore/Tests/UI/SimulationLab/{SLSupport,SLExploreUITests,SLLibraryUITests}.swift                     new
scripts/release_check.py                                                                                       modify (chunk x2)
docs/apps/simulation-lab/visualcore-contract.json (G-RELEASE closed)                                            modify
```

**Dependency direction:** unchanged. **Migration:** none (schemas stay at 1). **Rollback:** revert the commits.

## Parallel work

- **Agent A:** the release documents.
- **Agent B:** the UI tests and `SLSupport`.
- **Agent C:** the fixtures, the sample tests and the recovery test.
- **Lead:** the seam, `Package.swift`, `release_check.py`, the scans, the contract, the runs and the commits.
