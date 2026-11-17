# Implementation Plan: Digital Zen Garden — Phase 06 Final verification, privacy, packaging and release

**Branch**: `150-zg-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-RELEASE:
- **Documents:** privacy and credits, store listing with proving tests, release checklist, `release.json` and the A20
  section of `docs/release/known-limitations.md`.
- **Two scans:** the source scan (no network, tracking, sensor, Photos library, idle-timer or brightness API) and the
  claims scan (no physics, therapeutic, medical, wellbeing or unmeasured performance word).
- **Crash recovery:** a `failNextDraw` seam, with `library.json` and the garden files unchanged.
- **Committed samples:** of the snapshot, a saved garden and the library index.
- **Interface journey:** `ZGReleaseUITests` in chunk `b3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, POSIX shell for the two scans, and the existing Python release checks.
- **Testing:**
  - `DigitalZenGardenExperienceTests` (recovery, samples) on sim-27.2;
  - chunk `b3` on the iOS 27.2 phone;
  - `release_check.py --only experience-release-a20 copy-claims-a20` and the app release steps.
- **Constraints:** no signing, archive or upload. iOS 27 only; iOS 26 and the reference regression at X-A20. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| VIII Privacy | PASS: nothing sent; the only permission is the add-only Photos string, asked by the system share sheet |
| IX Accessibility | PASS: interface tests; audits wait for devices (ZG-D8, owner ruling of 2026-11-13) |
| XI Release | PASS: checklist rows verified, pending-campaign-ii or owner-action; no fabricated measurement |
| A20 calm and honest | PASS: the claims scan refuses physics, therapeutic, medical and wellbeing wording |
| X–XIII | PASS: documented API; no VisualCore change |

Post-design: PASS.

## Project Structure

```text
docs/apps/digital-zen-garden/{privacy-and-credits,store-listing,release-checklist}.md, release.json             new
docs/apps/digital-zen-garden/README.md (document table)                                                         modify
docs/release/known-limitations.md (A20 section)                                                                modify
specs/150-zg-p06-release/{scan-sources-release,scan-claims-release}.sh                                          new
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenPresenter.swift (failNextDraw, GardenDrawError)   modify
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{GardenRecoveryDrawTests,StoredSampleTests}.swift  new
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/Fixtures/{snapshot-v1,snapshot-newer,snapshot-damaged,
  garden-current,garden-newer,garden-damaged,library-current,library-newer,library-damaged}.json                new
Packages/ExperiencesCreative/Package.swift (Fixtures resource of DigitalZenGardenExperienceTests)                modify
Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGReleaseUITests.swift; scripts/release_check.py (b3 adds it)          new/modify
docs/apps/digital-zen-garden/visualcore-contract.json (G-RELEASE closed)                                        modify
```

- **Dependency direction:** tests → experience → core → VisualCore; no new dependency.
- **Lifecycle:** the seam acts only on the next draw and clears itself; nothing else changes.
- **Migration:** none (schema 1 only; the samples prove the refusals).
- **Rollback:** revert the commits.

## Parallel work

- **Agent D:** the documents.
- **Agent K:** the seam, the fixtures and the tests.
- **Agent U:** the interface journey.
- **Lead:** the two scans, Package.swift, release_check.py, the runs, the contract and the commits.
