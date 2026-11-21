# Implementation Plan: R02-G01-09 — Aurora Loom: simulator integration and full app lock

**Branch**: `309-aurora-loom-simulator-integration-and-full-app-lock` (spec directory only; work on `main`) | **Date**:
2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

Prove Aurora Loom inside the one app on the simulator while it stays a candidate. In the host-tested `AuroraLoomCore`:
`AuroraLoomExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored migration examples, A18 pattern). In
the experience: stable accessibility identifiers on every panel control, and pending stepper steps with Apply and
Clear (spec amendment: the steppers spent a move per tap, so panel-only players could not win level 1). In the app: the registration stores both
examples (comment corrected); app unit tests restore them, open the candidate through the registry and engine and
confirm it is not available; interface tests `ALPlayUITests` and `ALReplayUITests` (namespace `AL`) in a new
serial chunk `i3`; `RELEASE_FORBIDDEN` gains `AuroraLoomGolden` and `acceptanceScenarios`, and the Release
simulator build and symbol check run as evidence. Feature 308's regression is re-run for all-level solvability.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests), swift-testing (unit), Python 3 (release checks).
**Primary dependencies**: AuroraLoomCore and AuroraLoomExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `release_check.py --only
app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-i3 app-release-build app-release-symbols`; the 308 regression.
**Constraints**: no new target; Aurora Loom stays in `candidates`; interface tests each under 90 s; no device.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G0109-006). |
| VI Evidence Over Assertion | PASS — interface, unit, release-build and symbol runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers are added beside the existing labels and values. |
| XI One App and Stable Experience Identity | PASS — one target; id unchanged; earlier schemas migrate. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSchemaExamples.swift                         new   schemaOneExample, schemaTwoExample (lead)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSchemaExampleTests.swift                new   restore and migrate both (agent A)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift                         edit  identifiers, pending steppers, Apply, Clear (lead)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift                        edit  pending steps, apply, clear (lead)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomPanelTests.swift                  new   pending, apply, all 100 levels won through the panel (agent E)
Apps/VisualCore/App/ExperienceRegistry.swift                   edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                 edit  examples restore, candidate open, not available (agent B)
Apps/VisualCore/Tests/UI/AuroraLoom/ALSupport.swift            new   (agent C)
Apps/VisualCore/Tests/UI/AuroraLoom/ALPlayUITests.swift        new   (agent C)
Apps/VisualCore/Tests/UI/AuroraLoom/ALReplayUITests.swift      new   (agent C)
scripts/release_check.py, scripts/test_scripts.py              edit  chunk i3 serial, RELEASE_FORBIDDEN (agent D)
project.yml + xcodegen                                          edit if the UI test sources need listing (lead)
docs/architecture/aurora-loom.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md, docs/apps or app docs as needed (lead)
```

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3. **Rollback**: revert the commits.

## Parallel work

The lead writes the examples, identifiers and registration first (shared files); then agents A (example tests), B (app
unit tests), C (interface tests) and D (release-check edits) work on separate files; the lead builds, runs and records.
