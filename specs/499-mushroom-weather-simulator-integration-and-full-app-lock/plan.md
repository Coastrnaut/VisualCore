# Implementation Plan: R02-G20-09 — Mushroom Weather: simulator integration and full app lock

**Branch**: `499-mushroom-weather-simulator-integration-and-full-app-lock` (spec directory only; work on `main`)
| **Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Prove Mushroom Weather inside the one app on the simulator while it stays a candidate. In the host-tested
`MushroomWeatherCore`: `MushroomWeatherExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `MushroomWeatherSchemaExamples`, feature 489). In the experience: the failure explanation
gets its own identifier `explanation`, and `MushroomWeatherControls.identifierNames` pins the panel's names with a test that
each is unique and used once. In the app: the registration stores both examples (comment updated); app unit tests
restore them, pin level 1's certified plan (a pod at row 2, column 5 in slot 0 and vent 0 closed, then the run) against
the Core, open the candidate through the registry and engine and confirm it is not available; interface tests
`MWPlayUITests` and `MWReplayUITests` (namespace `MW`) in a new serial chunk `c4`; the Release simulator build and
symbol check run as evidence (`MushroomWeatherGolden` and `acceptanceScenarios` are already forbidden). Feature 498's
regression is re-run for all-level solvability. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests and app unit tests), swift-testing (package tests), Python 3
(release checks).
**Primary dependencies**: MushroomWeatherCore and MushroomWeatherExperience; VisualCoreExperience
(`MigrationExample`, `ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-c4 app-release-build app-release-symbols`; the 498 regression.
**Constraints**: no new target; Mushroom Weather stays in `candidates`; interface tests each under 90 s; no
device; `xcodegen generate` after the new UI test folder (memory xcodegen-after-new-app-files); the new chunk key `c4`
checked unique (memory ui-chunk-keys-unique).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G2009-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSchemaExamples.swift           new   examples (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSchemaExampleTests.swift  new   restore (A)
Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherControls.swift           edit  names, explanation id (lead)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherIdentifierTests.swift  new  unique (E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/MushroomWeather/MWSupport.swift                new   (agent C)
Apps/VisualCore/Tests/UI/MushroomWeather/MWPlayUITests.swift            new   (agent C)
Apps/VisualCore/Tests/UI/MushroomWeather/MWReplayUITests.swift          new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk c4 serial (agent D)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, the identifier list and the registration first (shared files); then agents A (example
tests), B (app unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate
files; the lead builds, runs and records.
