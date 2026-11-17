# Implementation Plan: Aurora — Phase 06 Final verification, privacy, packaging and release

**Branch**: `157-au-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-RELEASE:
- **Documents:** privacy and credits, store listing with proving tests, release checklist, `release.json` and the A21
  section of `docs/release/known-limitations.md`.
- **Two scans:** the source scan (no network, location, tracking, sensor, microphone, camera, Photos, idle-timer or
  brightness API) and the claims scan (no forecast, scientific, therapeutic, sleep, always-on or unmeasured
  performance word).
- **Crash recovery:** a `failNextDraw` seam, with `prefs.v1` unchanged.
- **Committed samples:** of the snapshot and the saved choices.
- **Interface journey:** `AUReleaseUITests` in chunk `c3`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/release.md](contracts/release.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, POSIX shell for the two scans, and the existing Python release checks.
- **APIs used (verified in code):**
  - `ExperienceStorage.value(for:)` and `setValue(_:for:)`;
  - `SkyPreferences` (`kind` `a21.preferences`, `storageKey` `prefs.v1`, refusals `damaged`, `newer-version`,
    `out-of-range`);
  - `SkyCore.snapshotPayload()` and `restore(payload:seed:)`, with the engine's restore refusals;
  - the session's draw-failure path (`experience.draw-failed`).
- **Testing:**
  - `AuroraExperienceTests` (recovery, samples) on sim-27.2;
  - chunk `c3` on the iOS 27.2 phone;
  - `release_check.py --only experience-release-a21 copy-claims-a21` and the app release steps.
- **Constraints:**
  - no signing, archive or upload;
  - iOS 27 only; iOS 26 and the reference regression wait for X-A21 (owner ruling of 2026-11-14), where the iOS 26.x
    half of G-RELEASE's test is run and cited.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| VIII Privacy | PASS: nothing sent; no permission; no screen or brightness control |
| IX Accessibility | PASS: interface tests; audits wait for devices (AU-D8, owner ruling of 2026-11-13) |
| XI Release | PASS: checklist rows verified, pending-campaign-ii or owner-action; no fabricated measurement |
| A21 truthful claims | PASS: the claims scan refuses forecast, scientific, therapeutic, sleep and always-on wording |
| X–XIII | PASS: documented API; no VisualCore change |

Post-design: PASS.

## Project Structure

```text
docs/apps/aurora/{privacy-and-credits,store-listing,release-checklist}.md, release.json                          new
docs/apps/aurora/README.md (document table)                                                                     modify
docs/release/known-limitations.md (A21 section, after A20)                                                      modify
specs/157-au-p06-release/{scan-sources-release,scan-claims-release}.sh                                          new
Packages/ExperiencesCreative/Aurora/Experience/AuroraPresenter.swift (failNextDraw, SkyDrawError)               modify
Packages/ExperiencesCreative/Aurora/ExperienceTests/{SkyRecoveryDrawTests,StoredSampleTests}.swift              new
Packages/ExperiencesCreative/Aurora/ExperienceTests/Fixtures/{snapshot-v1,snapshot-newer,snapshot-damaged,
  prefs-current,prefs-newer,prefs-damaged,prefs-out-of-range}.json                                              new
Packages/ExperiencesCreative/Package.swift (Fixtures resource of AuroraExperienceTests)                         modify
Apps/VisualCore/Tests/UI/Aurora/AUReleaseUITests.swift; scripts/release_check.py (c3 adds it)                  new/modify
docs/apps/aurora/visualcore-contract.json (G-RELEASE closed)                                                    modify
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
