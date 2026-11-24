# Implementation Plan: R02-G14-09 — Moonlit Mechanism: simulator integration and full app lock

**Branch**: `439-moonlit-mechanism-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Prove Moonlit Mechanism inside the one app on the simulator while it stays a candidate. In the host-tested
`MoonlitMechanismCore`: `MoonlitMechanismExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `AcousticConstellatorSchemaExamples`, feature 429). In the experience: the panel's identifiers
exist since features 434 … 437; `MoonlitMechanismControls.identifierNames` pins the 44 names and a test checks each is
unique and used once. In the app: the registration stores both examples (comment updated); app unit tests restore them,
pin level 1's certified actions (handle turn +1, lamp step −1, then the run) against the Core, open the candidate
through the registry and engine and confirm it is not available; interface tests `MMPlayUITests` and `MMReplayUITests`
(namespace `MM`) in a new serial chunk `w3`; the Release simulator build and symbol check run as evidence
(`MoonlitMechanismGolden` and `acceptanceScenarios` are already forbidden). Feature 438's regression is re-run for
all-level solvability. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests and app unit tests), swift-testing (package tests), Python 3
(release checks).
**Primary dependencies**: MoonlitMechanismCore and MoonlitMechanismExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-w3 app-release-build app-release-symbols`; the 438 regression.
**Constraints**: no new target; Moonlit Mechanism stays in `candidates`; interface tests each under 90 s; no device;
`xcodegen generate` after the new UI test folder (memory xcodegen-after-new-app-files); the new chunk key `w3` checked
unique (memory ui-chunk-keys-unique).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1409-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSchemaExamples.swift             new   examples (lead)
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSchemaExampleTests.swift    new   restore (agent A)
Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift             edit  identifierNames (lead)
Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismIdentifierTests.swift new   unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/MoonlitMechanism/MMSupport.swift             new   (agent C)
Apps/VisualCore/Tests/UI/MoonlitMechanism/MMPlayUITests.swift         new   (agent C)
Apps/VisualCore/Tests/UI/MoonlitMechanism/MMReplayUITests.swift       new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk w3 serial (agent D)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/moonlit-mechanism.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, the identifier list and the registration first (shared files); then agents A (example
tests), B (app unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate
files; the lead builds, runs and records.
