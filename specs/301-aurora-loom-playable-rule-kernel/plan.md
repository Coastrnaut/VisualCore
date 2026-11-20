# Implementation Plan: R02-G01-01 — Aurora Loom: playable rule kernel

**Branch**: `301-aurora-loom-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Create `Packages/ExperiencesRound02` (Auto-Creator.md section 16) with the pure target `AuroraLoomCore` and its tests: an
integer phase model (`AuroraLoomHarmony`), immutable levels with a fingerprint (`AuroraLoomLevel`, JSON schema 1), the play
state machine with validated, recorded moves, undo, redo and exact win and failure (`AuroraLoomPlay`), and the R02-F23
`PuzzleRules` conformance (`AuroraLoomRules`). Refusals are `AuroraLoomError` with `r02-g01.*` codes. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`), VisualCoreMath
(`StableHash`). No GPU, GLSL, Objective-C++ or UIKit code in this feature (the renderer is R02-G01-03).
**Package**: new `Packages/ExperiencesRound02/Package.swift` (platforms iOS 26 and macOS 15, so the pure Core is tested on
the host with `swift test`; later Experience targets need the simulator). No XcodeGen or app target change yet; the app
links the experience at R02-G01-09.
**Seeds**: fixtures use `SeededRandom(seed: 2_301)`.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (new CI step beside the VisualCore host tests);
`swift test --package-path Packages/VisualCore`; VisualCoreRendering on sim-27.2 and sim-26.5 and ExperiencesCreative on
sim-27.2 as regression; reference regression in two chunks; script tests (run alone).
**Performance**: one evaluation is 3 ribbons × 4 gates × 2P ≤ 3 × 4 × 8,192 = 98,304 integer steps (P ≤ 4,096 when
Ω = 1); levels in tests use Ω ≥ 16 (P ≤ 256).
**Constraints**: additive; existing packages unchanged; every value an exact integer; no network, no art.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering in this feature. |
| II App-neutral API | PASS — game code lives in an experience package, not in VisualCore; VisualCore API unchanged. |
| IV Host-testable | PASS — pure Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — level fields, moves, allowance and records refused or bounded by code. |
| X Licensing and provenance | PASS — original rules and code from the archived design; no third-party content. |
| XI One app and stable identity | PASS — experience R02-G01 (`r02-g01.aurora-loom`), no app target; level fingerprints. |
| XII One purchase, no advertising | PASS — free tier; no store code. |
| XIII Code-driven visuals | PASS — nothing drawn here. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                  new  package, AuroraLoomCore + tests (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomError.swift          new  AuroraLoomError (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomLevel.swift          new  AuroraLoomRibbon, AuroraLoomGate, AuroraLoomLevel, stored form (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHarmony.swift        new  phase model, residuals, win test, worst mismatch (lead; the level's start check needs it)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomPlay.swift           new  stages, moves, records, undo, redo, fingerprints (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomRules.swift          new  PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/{AuroraLoomLevelTests (lead), AuroraLoomHarmonyTests (A), AuroraLoomPlayTests (B), AuroraLoomRulesTests (C)}.swift   new
.github/workflows/ci.yml (new host-test step), docs/automatedtesting.md, docs/architecture/aurora-loom.md (lead)
```

**Migration**: none. **Rollback**: revert the commits (the package is new; nothing links it yet).

## Parallel work

Lead writes the package, error, level and harmony evaluation with the level test; agents A, B and C then write the
harmony tests, the play file and the rules file in parallel against the contract. Lead: docs, CI step, runs, commits;
checks recorded only after every agent has reported.
