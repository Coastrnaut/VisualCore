# Implementation Plan: R02-G10-09 — Backwards Aurora: simulator integration and full app lock

**Branch**: `399-backwards-aurora-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Prove Backwards Aurora inside the one app on the simulator while it stays a candidate. In the host-tested
`BackwardsAuroraCore`: `BackwardsAuroraExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `NocturneGardenSchemaExamples`, feature 389). In the experience: stable accessibility identifiers on
every panel control (the start, end and level steppers, Reverse and the replay controls exist since features 393,
394, 395, 396 and 397). In the app: the
registration stores both examples (comment corrected); app unit tests restore them, pin level 1's certified reversals and the
steppers' starting section (0 … 1) against the Core, open the candidate through the registry and engine and confirm it
is not available; interface tests `BAPlayUITests` and `BAReplayUITests` (namespace `BA`) in a new serial chunk `s3`;
the Release simulator build and symbol check run as evidence (`BackwardsAuroraGolden` and `acceptanceScenarios` are
already forbidden). Feature 398's regression is re-run for all-level solvability. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: BackwardsAuroraCore and BackwardsAuroraExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-s3 app-release-build app-release-symbols`; the 398 regression.
**Constraints**: no new target; Backwards Aurora stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1009-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSchemaExamples.swift            new   examples (lead)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSchemaExampleTests.swift   new   restore (agent A)
Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraControls.swift            edit  identifiers (lead)
Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraIdentifierTests.swift new  unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/BackwardsAurora/BASupport.swift               new   (agent C)
Apps/VisualCore/Tests/UI/BackwardsAurora/BAPlayUITests.swift           new   (agent C)
Apps/VisualCore/Tests/UI/BackwardsAurora/BAReplayUITests.swift         new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk s3 serial (agent D)
project.yml + xcodegen                                                edit if the UI test sources need listing (lead)
docs/architecture/backwards-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate files; the lead
builds, runs and records.
