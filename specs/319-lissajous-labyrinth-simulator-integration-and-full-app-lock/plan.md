# Implementation Plan: R02-G02-09 — Lissajous Labyrinth: simulator integration and full app lock

**Branch**: `319-lissajous-labyrinth-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Prove Lissajous Labyrinth inside the one app on the simulator while it stays a candidate. In the host-tested
`LissajousLabyrinthCore`: `LissajousLabyrinthExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored
migration examples, the pattern of `AuroraLoomSchemaExamples`). In the experience: stable accessibility identifiers on
every panel control (pending values, Apply and Clear exist since feature 314). In the app: the registration stores both
examples (comment corrected); app unit tests restore them, pin level 1's start dials and solution against the Core, open
the candidate through the registry and engine and confirm it is not available; interface tests `LLPlayUITests` and
`LLReplayUITests` (namespace `LL`) in a new serial chunk `j3`; the Release simulator build and symbol check run as
evidence (`LissajousLabyrinthGolden` and `acceptanceScenarios` are already forbidden). Feature 318's regression is re-run
for all-level solvability. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: LissajousLabyrinthCore and LissajousLabyrinthExperience; VisualCoreExperience
(`MigrationExample`, `ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-j3 app-release-build app-release-symbols`; the 318 regression.
**Constraints**: no new target; Lissajous Labyrinth stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G0209-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSchemaExamples.swift           new   schemaOneExample, schemaTwoExample (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSchemaExampleTests.swift  new   restore and migrate both (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift            edit  identifiers (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthIdentifierTests.swift new  every identifier present and unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples restore, level 1 pins, candidate open, not available (agent B)
Apps/VisualCore/Tests/UI/LissajousLabyrinth/LLSupport.swift           new   (agent C)
Apps/VisualCore/Tests/UI/LissajousLabyrinth/LLPlayUITests.swift       new   (agent C)
Apps/VisualCore/Tests/UI/LissajousLabyrinth/LLReplayUITests.swift     new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk j3 serial (agent D)
project.yml + xcodegen                                                 edit if the UI test sources need listing (lead)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate files; the lead
builds, runs and records.
