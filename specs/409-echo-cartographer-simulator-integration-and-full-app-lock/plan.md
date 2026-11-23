# Implementation Plan: R02-G11-09 — Echo Cartographer: simulator integration and full app lock

**Branch**: `409-echo-cartographer-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Prove Echo Cartographer inside the one app on the simulator while it stays a candidate. In the host-tested
`EchoCartographerCore`: `EchoCartographerExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `BackwardsAuroraSchemaExamples`, feature 399). In the experience: stable accessibility
identifiers on every panel control (the column, row and level steppers, Pulse, Claim, Mark and the replay controls exist
since features 403 … 407). In the app: the registration stores both examples (comment corrected); app unit tests
restore them, pin level 1's certified actions and the cursor's starting cell (the entry, column 0, row 3) against the
Core, open the candidate through the registry and engine and confirm it is not available; interface tests
`ECGPlayUITests` and `ECGReplayUITests` (namespace `ECG`) in a new serial chunk `t3`; the Release simulator build and
symbol check run as evidence (`EchoCartographerGolden` and `acceptanceScenarios` are already forbidden). Feature 408's
regression is re-run for all-level solvability. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: EchoCartographerCore and EchoCartographerExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-t3 app-release-build app-release-symbols`; the 408 regression.
**Constraints**: no new target; Echo Cartographer stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1109-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSchemaExamples.swift             new   examples (lead)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSchemaExampleTests.swift    new   restore (agent A)
Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerControls.swift             edit  identifiers (lead)
Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerIdentifierTests.swift new   unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/EchoCartographer/ECGSupport.swift             new   (agent C)
Apps/VisualCore/Tests/UI/EchoCartographer/ECGPlayUITests.swift         new   (agent C)
Apps/VisualCore/Tests/UI/EchoCartographer/ECGReplayUITests.swift       new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk t3 serial (agent D)
project.yml + xcodegen                                                edit if the UI test sources need listing (lead)
docs/architecture/echo-cartographer.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate files; the lead
builds, runs and records.
