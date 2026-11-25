# Implementation Plan: R02-G16-09 — Starlit Cartouche: simulator integration and full app lock

**Branch**: `459-starlit-cartouche-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) |
**Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Prove Starlit Cartouche inside the one app on the simulator while it stays a candidate. In the host-tested
`StarlitCartoucheCore`: `StarlitCartoucheExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration
examples, the pattern of `VoxelOrigamiSchemaExamples`, feature 449). In the experience: the panel's identifiers
exist since features 453 … 457; `StarlitCartoucheControls.identifierNames` pins the 37 names and a test checks each is
unique and used once. In the app: the registration stores both examples (comment updated); app unit tests restore them,
pin level 1's certified actions (to star 4 after 1 beat, then to star 5 after 0 beats) against the Core, open the
candidate through the registry and engine and confirm it is not available; interface tests `SCPlayUITests` and
`SCReplayUITests` (namespace `SC`) in a new serial chunk `y3`; the Release simulator build and symbol check run as
evidence (`StarlitCartoucheGolden` and `acceptanceScenarios` are already forbidden). Feature 458's regression is re-run
for all-level solvability. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests and app unit tests), swift-testing (package tests), Python 3
(release checks).
**Primary dependencies**: StarlitCartoucheCore and StarlitCartoucheExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-y3 app-release-build app-release-symbols`; the 458 regression.
**Constraints**: no new target; Starlit Cartouche stays in `candidates`; interface tests each under 90 s; no device;
`xcodegen generate` after the new UI test folder (memory xcodegen-after-new-app-files); the new chunk key `y3` checked
unique (memory ui-chunk-keys-unique).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G1609-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSchemaExamples.swift           new   examples (lead)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSchemaExampleTests.swift  new   restore (A)
Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift           edit  names (lead)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheIdentifierTests.swift  new  unique (E)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/StarlitCartouche/SCSupport.swift             new   (agent C)
Apps/VisualCore/Tests/UI/StarlitCartouche/SCPlayUITests.swift         new   (agent C)
Apps/VisualCore/Tests/UI/StarlitCartouche/SCReplayUITests.swift       new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk y3 serial (agent D)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/starlit-cartouche.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, the identifier list and the registration first (shared files); then agents A (example
tests), B (app unit tests), C (interface tests), D (release-check edits) and E (identifier tests) work on separate
files; the lead builds, runs and records.
