# Implementation Plan: R02-G03-09 — Wave Knot Keeper: simulator integration and full app lock

**Branch**: `329-wave-knot-keeper-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Prove Wave Knot Keeper inside the one app on the simulator while it stays a candidate. In the host-tested
`WaveKnotKeeperCore`: `WaveKnotKeeperExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored
migration examples, the pattern of `AuroraLoomSchemaExamples`). In the experience: stable accessibility identifiers on
every panel control (the point picker and direction buttons exist since features 323 and 324). In the app: the registration stores both
examples (comment corrected); app unit tests restore them, pin level 1's start rope and certified solution against the Core, open
the candidate through the registry and engine and confirm it is not available; interface tests `WKPlayUITests` and
`WKReplayUITests` (namespace `WK`) in a new serial chunk `l3`; the Release simulator build and symbol check run as
evidence (`WaveKnotKeeperGolden` and `acceptanceScenarios` are already forbidden). Feature 328's regression is re-run
for all-level solvability. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: WaveKnotKeeperCore and WaveKnotKeeperExperience; VisualCoreExperience
(`MigrationExample`, `ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-l3 app-release-build app-release-symbols`; the 328 regression.
**Constraints**: no new target; Wave Knot Keeper stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G0309-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSchemaExamples.swift           new   schemaOneExample, schemaTwoExample (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSchemaExampleTests.swift  new   restore and migrate both (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift            edit  identifiers (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperIdentifierTests.swift new  every identifier present and unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples restore, level 1 pins, candidate open, not available (agent B)
Apps/VisualCore/Tests/UI/WaveKnotKeeper/WKSupport.swift           new   (agent C)
Apps/VisualCore/Tests/UI/WaveKnotKeeper/WKPlayUITests.swift       new   (agent C)
Apps/VisualCore/Tests/UI/WaveKnotKeeper/WKReplayUITests.swift     new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk l3 serial (agent D)
project.yml + xcodegen                                                 edit if the UI test sources need listing (lead)
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate files; the lead
builds, runs and records.
