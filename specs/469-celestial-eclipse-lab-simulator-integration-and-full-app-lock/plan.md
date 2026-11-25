# Implementation Plan: R02-G17-09 — Celestial Eclipse Lab: simulator integration and full app lock

**Branch**: `469-celestial-eclipse-lab-simulator-integration-and-full-app-lock` (spec directory only; work on `main`)
| **Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Prove Celestial Eclipse Lab inside the one app on the simulator while it stays a candidate. In the host-tested
`CelestialEclipseLabCore`: `CelestialEclipseLabExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored
migration examples, the pattern of `StarlitCartoucheSchemaExamples`, feature 459). In the experience: the failure
explanation gets its own identifier `explanation`, and `CelestialEclipseLabControls.identifierNames` pins the 41 names
with a test that each is unique and used once. In the app: the registration stores both examples (comment updated);
app unit tests restore them, pin level 1's certified plan (body 1 to phase 2, then body 2 to phase 0, then the run)
against the Core, open the candidate through the registry and engine and confirm it is not available; interface tests
`CELPlayUITests` and `CELReplayUITests` (namespace `CEL`) in a new serial chunk `z3`; the Release simulator build and
symbol check run as evidence (`CelestialEclipseLabGolden` and `acceptanceScenarios` are already forbidden). Feature
468's regression is re-run for all-level solvability. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests and app unit tests), swift-testing (package tests), Python 3
(release checks).
**Primary dependencies**: CelestialEclipseLabCore and CelestialEclipseLabExperience; VisualCoreExperience
(`MigrationExample`, `ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-z3 app-release-build app-release-symbols`; the 468 regression.
**Constraints**: no new target; Celestial Eclipse Lab stays in `candidates`; interface tests each under 90 s; no
device; `xcodegen generate` after the new UI test folder (memory xcodegen-after-new-app-files); the new chunk key `z3`
checked unique (memory ui-chunk-keys-unique).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1709-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSchemaExamples.swift           new   examples (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSchemaExampleTests.swift  new   restore (A)
Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabControls.swift           edit  names, explanation id (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabIdentifierTests.swift  new  unique (E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/CelestialEclipseLab/CELSupport.swift         new   (agent C)
Apps/VisualCore/Tests/UI/CelestialEclipseLab/CELPlayUITests.swift     new   (agent C)
Apps/VisualCore/Tests/UI/CelestialEclipseLab/CELReplayUITests.swift   new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk z3 serial (agent D)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/celestial-eclipse-lab.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, the identifier list and the registration first (shared files); then agents A (example
tests), B (app unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate
files; the lead builds, runs and records.
