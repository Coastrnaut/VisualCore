# Implementation Plan: R02-G09-09 — Nocturne Garden: simulator integration and full app lock

**Branch**: `389-nocturne-garden-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Prove Nocturne Garden inside the one app on the simulator while it stays a candidate. In the host-tested
`NocturneGardenCore`: `NocturneGardenExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `FacetedForgeSchemaExamples`, feature 379). In the experience: stable accessibility identifiers on
every panel control (the kind, column, row, size, bloom, sun and level steppers, Plant, Move, Resize, Remove and Set sun exist since
features 383, 384 and 386). In the app: the
registration stores both examples (comment corrected); app unit tests restore them, pin level 1's certified moves and the
pickers' starting picks against the Core, open the candidate through the registry and engine and confirm it
is not available; interface tests `NGPlayUITests` and `NGReplayUITests` (namespace `NG`) in a new serial chunk `r3`;
the Release simulator build and symbol check run as evidence (`NocturneGardenGolden` and `acceptanceScenarios` are
already forbidden). Feature 388's regression is re-run for all-level solvability. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). Contract: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: NocturneGardenCore and NocturneGardenExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-r3 app-release-build app-release-symbols`; the 388 regression.
**Constraints**: no new target; Nocturne Garden stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G0909-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSchemaExamples.swift            new   examples (lead)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSchemaExampleTests.swift   new   restore (agent A)
Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenControls.swift            edit  identifiers (lead)
Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenIdentifierTests.swift new  unique (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/NocturneGarden/NGSupport.swift               new   (agent C)
Apps/VisualCore/Tests/UI/NocturneGarden/NGPlayUITests.swift           new   (agent C)
Apps/VisualCore/Tests/UI/NocturneGarden/NGReplayUITests.swift         new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk r3 serial (agent D)
project.yml + xcodegen                                                edit if the UI test sources need listing (lead)
docs/architecture/faceted-forge.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate files; the lead
builds, runs and records.
