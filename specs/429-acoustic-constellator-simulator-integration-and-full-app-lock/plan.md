# Implementation Plan: R02-G13-09 — Acoustic Constellator: simulator integration and full app lock

**Branch**: `429-acoustic-constellator-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Prove Acoustic Constellator inside the one app on the simulator while it stays a candidate. In the host-tested
`AcousticConstellatorCore`: `AcousticConstellatorExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `HarmonicBridgesSchemaExamples`, feature 419). In the experience: the panel's identifiers
exist since features 423 … 427; `AcousticConstellatorControls.identifierNames` pins the 35 names and a test checks each is
unique and used once. In the app: the registration stores both examples (comment updated); app unit tests restore
them, pin level 1's certified actions (link stars 0 and 1, then a listen) and the panel's opening choice
(star 0, partner 1) against the Core, open the candidate through the registry and engine and confirm it is not
available; interface tests `ACNPlayUITests` and `ACNReplayUITests` (namespace `ACN`) in a new serial chunk `v3`; the
Release simulator build and symbol check run as evidence (`AcousticConstellatorGolden` and `acceptanceScenarios` are already
forbidden). Feature 428's regression is re-run for all-level solvability. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: AcousticConstellatorCore and AcousticConstellatorExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-v3 app-release-build app-release-symbols`; the 428 regression.
**Constraints**: no new target; Acoustic Constellator stays in `candidates`; interface tests each under 90 s; no device;
`xcodegen generate` after the new UI test folder (lesson of feature 409, memory xcodegen-after-new-app-files).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1309-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSchemaExamples.swift             new   examples (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSchemaExampleTests.swift    new   restore (agent A)
Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorControls.swift             edit  identifierNames (lead)
Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorIdentifierTests.swift new   unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/AcousticConstellator/ACNSupport.swift               new   (agent C)
Apps/VisualCore/Tests/UI/AcousticConstellator/ACNPlayUITests.swift           new   (agent C)
Apps/VisualCore/Tests/UI/AcousticConstellator/ACNReplayUITests.swift         new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk v3 serial (agent D)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/acoustic-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, the identifier list and the registration first (shared files); then agents A (example
tests), B (app unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate
files; the lead builds, runs and records.
