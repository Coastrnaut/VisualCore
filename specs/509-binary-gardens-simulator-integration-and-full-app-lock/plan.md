# Implementation Plan: R02-G21-09 — Binary Gardens: simulator integration and full app lock

**Branch**: `509-binary-gardens-simulator-integration-and-full-app-lock` (spec directory only; work on `main`)
| **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Prove Binary Gardens inside the one app on the simulator while it stays a candidate, on feature 499's pattern. In the
host-tested `BinaryGardensCore`: `BinaryGardensExperienceCore.schemaOneExample()` and `schemaTwoExample()` (stored
migration examples, the envelope of `MushroomWeatherSchemaExamples`, seed 2_509). In the experience:
`BinaryGardensControls.identifierNames` pins the panel's names (the 37 it carries today plus those features 505 … 507
add) with a test that each is unique and used once. In the app: the registration stores both examples (its comment
"Snapshot schema 1, so no earlier example is stored yet" corrected); app unit tests restore them, pin level 1's
certified plan (star 2, 0-based star 1, to luminosity index 0, then the run) against the Core, open the candidate
through the registry and engine and confirm it is not available; interface tests `BGPlayUITests` and
`BGReplayUITests` (namespace `BG`) in a new serial chunk `d4`; the Release simulator build and symbol check run as
evidence (`BinaryGardensGolden` is forbidden by feature 508, `acceptanceScenarios` already). Feature 508's regression
is re-run for all-level solvability. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
Contract: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

**Prerequisites recorded first**: R02-G21-04 (feature 504, recorded pass 2026-11-27) and R02-G21-05 … R02-G21-08
(features 505 … 508: specified and planned, not in code). Implementation starts only after R02-G21-08 is recorded: the
stars, level picker, tutorial dismissal and schema 2 (505), the announcements and Sound (506), the replay, traces and
schema 3 (507) and `BinaryGardensGolden` with `scripts/binary_gardens_regression.py` (508) are what this gate tests.

## Technical Context

**Language/Version**: Swift 6, XCTest (interface tests and app unit tests), swift-testing (package tests), Python 3
(release checks).
**Primary dependencies**: BinaryGardensCore and BinaryGardensExperience; VisualCoreExperience (`MigrationExample`,
`ExperienceSnapshot`, `DigestBuilder`); the app's registry, `DebugLaunch` and UI test support.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; `xcodebuild_package.py --only-testing
BinaryGardensExperienceTests` on `sim-27.2`; `release_check.py --only app-build-for-testing-ios27 app-unit-ios27
app-ui-ios27-d4 app-release-build app-release-symbols`; the 508 regression.
**Constraints**: no new target; Binary Gardens stays in `candidates`; no device; `xcodegen generate` after the new UI
test folder (memory xcodegen-after-new-app-files); the chunk key `d4` grepped free in `scripts/release_check.py`
(2026-11-27: `UI_CHUNKS` ends at `c4`, no `"d4"` anywhere; memory ui-chunk-keys-unique); no UI class uses `BG`.
**Counted bounds**: 3 interface tests (2 play, 1 replay), each under 90 s plus about 30 s of automation-session setup
per launch (the relaunch test: 90 + 2 × 30 = 150 s, inside the 180 s per-test allowance); a press retried at most 3
times and counted only when its value or the actions-left count moves; at most 8 taps to choose a picker value; the
replay of level 1's two-step trace (luminosity, run) stepped at most 4 times; 2 stored examples; 4 app unit tests;
host example tests under 10 s each; `identifierNames` 37 names today, its final count read from the panel as built.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — the examples live in the game's Core; the app only registers them. |
| IV Host-Testable Domain Logic, Test-First | PASS — the examples are host-tested before the app uses them. |
| V Implementation Before Devices | PASS — no device; D1–D3 journeys wait (SC-R02G2109-006, feature 510). |
| VI Evidence Over Assertion | PASS — interface, unit, release, symbol and regression runs are recorded checks. |
| VII Native, Accessible UI | PASS — identifiers sit beside the existing labels and values; the list is pinned. |
| XI One App and Stable Experience Identity | PASS — one target; `r02-g21.binary-gardens` unchanged; 1 → 3, 2 → 3. |
| XII One Purchase and No Advertising | PASS — free; nothing sold. |
| XIII Code-Driven Visuals | PASS — no visual change; the shaders of features 503 and 506 are untouched. |

Post-design re-check: PASS (the contract adds only Core examples and a name list; no renderer, target or sale).

## Project Structure

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSchemaExamples.swift          new   examples (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSchemaExampleTests.swift new   restore (lead)
Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift          edit  names (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensIdentifierTests.swift  new (lead)
Apps/VisualCore/App/ExperienceRegistry.swift                          edit  examples, comment (lead)
Apps/VisualCore/Tests/Unit/AppModelTests.swift                        edit  examples, level 1 pins, candidate (agent B)
Apps/VisualCore/Tests/UI/BinaryGardens/BGSupport.swift                new   (agent C)
Apps/VisualCore/Tests/UI/BinaryGardens/BGPlayUITests.swift            new   (agent C)
Apps/VisualCore/Tests/UI/BinaryGardens/BGReplayUITests.swift          new   (agent C)
scripts/release_check.py, scripts/test_scripts.py                     edit  chunk d4 serial (lead)
project.yml + xcodegen                                                regenerate for the new UI test folder (lead)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Dependency graph**: R02-G21-08 recorded → baselines → examples, names and registration (lead) → {app unit tests
(B), interface tests (C), chunk `d4` and xcodegen (lead)} → release build and symbols, regression → docs, round-two
host chunks, script tests, rendering and reference runs → converge, seal, record.

**Migration**: none of the format; the examples prove 1 → 3 and 2 → 3 through features 505 and 507's steps.
**Rollback**: revert the commits; the registration without `examples:` and chunk `d4` removed restore today's state.
**CI**: `BinaryGardens` is already in round-two host half b's filter (`.github/workflows/ci.yml`); the new example
tests join it; the interface chunk runs locally as gate evidence only, as `c4` does; check the record push's run with
`gh run list`.

## Parallel work

The lead writes the examples, the identifier list, the registration, chunk `d4` and xcodegen first (shared files);
then agent B (app unit tests) and agent C (interface tests) work on their separate files, drafting in isolated copies
before R02-G21-08 is recorded if wanted (new files only); the lead builds, runs, retests every agent result and records.
